local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Shared.Constants)

local PersistenceService = {}
local playerStore = DataStoreService:GetDataStore(Constants.PlayerStoreName)
local weaponStore = DataStoreService:GetDataStore(Constants.WeaponStoreName)

local function retry(label, callback)
    local lastError
    for attempt = 1, Constants.DataStoreRetries do
        local ok, result = pcall(callback)
        if ok then return true, result end
        lastError = result
        if attempt < Constants.DataStoreRetries then
            task.wait(math.min(2 ^ (attempt - 1), 4) + math.random() * 0.25)
        end
    end
    warn("[TTG Persistence]", label, "failed:", lastError)
    return false, nil
end

local function playerKey(userId)
    return "P_" .. tostring(userId)
end

local function weaponKey(gunId)
    return "W_" .. gunId
end

function PersistenceService.LoadPlayer(userId)
    return retry("LoadPlayer " .. tostring(userId), function()
        return playerStore:GetAsync(playerKey(userId))
    end)
end

function PersistenceService.SavePlayer(userId, data)
    return retry("SavePlayer " .. tostring(userId), function()
        return playerStore:UpdateAsync(playerKey(userId), function()
            return data
        end)
    end)
end

function PersistenceService.UpdatePlayer(userId, transform)
    return retry("UpdatePlayer " .. tostring(userId), function()
        return playerStore:UpdateAsync(playerKey(userId), function(current)
            return transform(current)
        end)
    end)
end

function PersistenceService.LoadWeapon(gunId)
    return retry("LoadWeapon " .. gunId, function()
        return weaponStore:GetAsync(weaponKey(gunId))
    end)
end

function PersistenceService.SaveWeapon(gunId, data)
    return retry("SaveWeapon " .. gunId, function()
        return weaponStore:UpdateAsync(weaponKey(gunId), function()
            return data
        end)
    end)
end

return PersistenceService
