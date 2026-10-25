local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Shared.Constants)
local PersistenceService = require(script.Parent.PersistenceService)

local PlayerDataService = {}
local names = {}
local profiles = {}
local loaded = {}
local dirty = {}
local persistenceAvailable = {}

local function defaultProfile()
    return {
        Version = 1,
        HasReceivedFounderGun = false,
        OwnedGunIds = {},
        SelectedGunId = nil,
    }
end

local function normalize(data)
    local profile = type(data) == "table" and data or defaultProfile()
    profile.Version = 1
    profile.HasReceivedFounderGun = profile.HasReceivedFounderGun == true
    profile.OwnedGunIds = type(profile.OwnedGunIds) == "table" and profile.OwnedGunIds or {}

    local clean = {}
    local seen = {}
    for _, gunId in ipairs(profile.OwnedGunIds) do
        if type(gunId) == "string" and not seen[gunId] and #clean < Constants.MaxOwnedWeapons then
            seen[gunId] = true
            table.insert(clean, gunId)
        end
    end
    profile.OwnedGunIds = clean
    if type(profile.SelectedGunId) ~= "string" or not seen[profile.SelectedGunId] then
        profile.SelectedGunId = clean[1]
    end
    return profile
end

local function serializable(profile)
    return {
        Version = 1,
        HasReceivedFounderGun = profile.HasReceivedFounderGun == true,
        OwnedGunIds = table.clone(profile.OwnedGunIds),
        SelectedGunId = profile.SelectedGunId,
    }
end

local function contains(profile, gunId)
    return table.find(profile.OwnedGunIds, gunId) ~= nil
end

function PlayerDataService.Remember(player)
    names[player.UserId] = player.DisplayName
end

function PlayerDataService.NameFor(userId)
    if not userId then return "Nobody" end
    local player = Players:GetPlayerByUserId(userId)
    if player then return player.DisplayName end
    return names[userId] or ("User " .. tostring(userId))
end

function PlayerDataService.Load(player)
    PlayerDataService.Remember(player)
    local ok, data = PersistenceService.LoadPlayer(player.UserId)
    profiles[player.UserId] = normalize(ok and data or nil)
    loaded[player.UserId] = true
    persistenceAvailable[player.UserId] = ok
    dirty[player.UserId] = false
    return profiles[player.UserId], ok
end

function PlayerDataService.IsLoaded(player)
    return loaded[player.UserId] == true
end

function PlayerDataService.WaitLoaded(player, timeoutSeconds)
    local started = os.clock()
    while player.Parent and not loaded[player.UserId] do
        if timeoutSeconds and os.clock() - started >= timeoutSeconds then return false end
        task.wait(0.05)
    end
    return loaded[player.UserId] == true
end

function PlayerDataService.Get(playerOrUserId)
    local userId = typeof(playerOrUserId) == "Instance" and playerOrUserId.UserId or playerOrUserId
    return profiles[userId]
end

function PlayerDataService.AddOwnedGun(userId, gunId)
    local profile = profiles[userId]
    if not profile or contains(profile, gunId) then return false end
    if #profile.OwnedGunIds >= Constants.MaxOwnedWeapons then return false end
    table.insert(profile.OwnedGunIds, gunId)
    profile.SelectedGunId = profile.SelectedGunId or gunId
    dirty[userId] = true
    return true
end

function PlayerDataService.RemoveOwnedGun(userId, gunId)
    local profile = profiles[userId]
    if not profile then return false end
    local index = table.find(profile.OwnedGunIds, gunId)
    if not index then return false end
    table.remove(profile.OwnedGunIds, index)
    if profile.SelectedGunId == gunId then
        profile.SelectedGunId = profile.OwnedGunIds[1]
    end
    dirty[userId] = true
    return true
end

function PlayerDataService.ReplaceOwnedGunIds(userId, gunIds)
    local profile = profiles[userId]
    if not profile then return end
    profile.OwnedGunIds = table.clone(gunIds)
    if not profile.SelectedGunId or not table.find(profile.OwnedGunIds, profile.SelectedGunId) then
        profile.SelectedGunId = profile.OwnedGunIds[1]
    end
    dirty[userId] = true
end

function PlayerDataService.MarkFounderReceived(userId, gunId)
    local profile = profiles[userId]
    if not profile then return end
    profile.HasReceivedFounderGun = true
    profile.SelectedGunId = gunId
    dirty[userId] = true
end

function PlayerDataService.SaveUserId(userId, force)
    local profile = profiles[userId]
    if not profile then return false end
    if not persistenceAvailable[userId] then return false end
    if not force and not dirty[userId] then return true end
    local ok = PersistenceService.SavePlayer(userId, serializable(profile))
    if ok then dirty[userId] = false end
    return ok
end

function PlayerDataService.TransferGun(previousUserId, newUserId, gunId)
    if previousUserId == newUserId then return true end

    PlayerDataService.AddOwnedGun(newUserId, gunId)
    PlayerDataService.SaveUserId(newUserId, true)

    if profiles[previousUserId] then
        PlayerDataService.RemoveOwnedGun(previousUserId, gunId)
        PlayerDataService.SaveUserId(previousUserId, true)
    elseif previousUserId then
        PersistenceService.UpdatePlayer(previousUserId, function(current)
            local profile = normalize(current)
            local index = table.find(profile.OwnedGunIds, gunId)
            if index then table.remove(profile.OwnedGunIds, index) end
            if profile.SelectedGunId == gunId then profile.SelectedGunId = profile.OwnedGunIds[1] end
            return serializable(profile)
        end)
    end
    return true
end

function PlayerDataService.SaveDirty()
    for userId in pairs(profiles) do
        PlayerDataService.SaveUserId(userId, false)
    end
end

function PlayerDataService.Forget(player)
    PlayerDataService.SaveUserId(player.UserId, true)
    profiles[player.UserId] = nil
    loaded[player.UserId] = nil
    dirty[player.UserId] = nil
    persistenceAvailable[player.UserId] = nil
end

return PlayerDataService
