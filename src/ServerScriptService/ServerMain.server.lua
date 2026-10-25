local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Services = script.Parent.Services
local Constants = require(ReplicatedStorage.Shared.Constants)
local WeaponService = require(Services.WeaponService)
local DropService = require(Services.DropService)
local CombatService = require(Services.CombatService)
local PlayerDataService = require(Services.PlayerDataService)
local MapService = require(Services.MapService)

MapService.Build()
local dropFolder = workspace:FindFirstChild("DroppedWeapons") or Instance.new("Folder")
dropFolder.Name = "DroppedWeapons"
dropFolder.Parent = workspace

local remoteFolder = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
remoteFolder.Name = "Remotes"
remoteFolder.Parent = ReplicatedStorage
for _, name in ipairs({ "FireWeapon", "ReloadWeapon", "RequestPickup", "WeaponStateChanged", "KillFeedEvent", "ShotFired" }) do
    local remote = remoteFolder:FindFirstChild(name) or Instance.new("RemoteEvent")
    remote.Name = name
    remote.Parent = remoteFolder
end

local function ensureRemoteFunction(name)
    local remote = remoteFolder:FindFirstChild(name)
    if not remote then
        remote = Instance.new("RemoteFunction")
        remote.Name = name
        remote.Parent = remoteFolder
    end
    return remote
end

local debugSnapshot = ensureRemoteFunction("DebugWeaponSnapshot")
local inventorySnapshot = ensureRemoteFunction("InventorySnapshot")

WeaponService.Init(remoteFolder)
DropService.Init(dropFolder, remoteFolder)
CombatService.Init(remoteFolder)

local founderTypes = { "Pistol", "SMG", "AssaultRifle", "Shotgun" }
local founderIndex = 0

local function giveSpawnWeapon(player)
    if WeaponService.GetEquipped(player) then return end
    local profile = PlayerDataService.Get(player)
    if not profile then return end

    local persistent = WeaponService.FindStoredOwned(player.UserId, profile.SelectedGunId)
    if persistent and WeaponService.Equip(player, persistent) then return end

    local issue = WeaponService.CreateIssue(player, "Pistol")
    WeaponService.Equip(player, issue)
end

local function onCharacter(player, character)
    if character:GetAttribute("TTGServerBound") then return end
    character:SetAttribute("TTGServerBound", true)

    task.spawn(function()
        if not PlayerDataService.WaitLoaded(player, 15) then return end
        if player.Character ~= character then return end

        CombatService.MarkSpawn(player)
        local humanoid = character:WaitForChild("Humanoid")
        humanoid.Died:Connect(function()
            local root = character:FindFirstChild("HumanoidRootPart")
            DropService.DropPlayerWeapon(player, root and root.Position or character:GetPivot().Position)
        end)

        task.defer(function()
            if player.Character ~= character or humanoid.Health <= 0 then return end
            giveSpawnWeapon(player)
        end)
    end)
end

local function onPlayer(player)
    PlayerDataService.Remember(player)
    player.CharacterAdded:Connect(function(character)
        onCharacter(player, character)
    end)

    local profile = PlayerDataService.Load(player)
    local validGunIds, loadComplete = WeaponService.LoadOwnedForPlayer(player, profile.OwnedGunIds)
    if loadComplete and #validGunIds ~= #profile.OwnedGunIds then
        PlayerDataService.ReplaceOwnedGunIds(player.UserId, validGunIds)
        PlayerDataService.SaveUserId(player.UserId, true)
        profile = PlayerDataService.Get(player)
    end

    if not profile.HasReceivedFounderGun then
        founderIndex += 1
        local weaponType = founderTypes[((founderIndex - 1) % #founderTypes) + 1]
        local founder = WeaponService.Create(player, weaponType, true)
        PlayerDataService.AddOwnedGun(player.UserId, founder.GunId)
        PlayerDataService.MarkFounderReceived(player.UserId, founder.GunId)

        if PlayerDataService.IsPersistenceAvailable(player.UserId) then
            local weaponSaved = WeaponService.SaveNow(founder)
            if weaponSaved then
                PlayerDataService.SaveUserId(player.UserId, true)
            else
                warn("[TTG Persistence] Founder gun could not be saved; player profile was not committed.", founder.GunId)
            end
        end
    end

    if player.Character then onCharacter(player, player.Character) end
end

Players.PlayerAdded:Connect(onPlayer)
for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(onPlayer, player)
end

Players.PlayerRemoving:Connect(function(player)
    DropService.StashOwnedDrops(player.UserId)
    WeaponService.StashOwnedBy(player.UserId)
    PlayerDataService.Forget(player)
end)

remoteFolder.FireWeapon.OnServerEvent:Connect(CombatService.Fire)
remoteFolder.ReloadWeapon.OnServerEvent:Connect(WeaponService.StartReload)
remoteFolder.RequestPickup.OnServerEvent:Connect(function(player, drop)
    DropService.Claim(player, drop)
end)

debugSnapshot.OnServerInvoke = function(_player)
    if not Constants.DebugEnabled then return {} end
    return WeaponService.GetDebugSnapshot()
end

inventorySnapshot.OnServerInvoke = function(player)
    return WeaponService.GetInventorySnapshot(player)
end

task.spawn(function()
    while task.wait(Constants.AutosaveSeconds) do
        PlayerDataService.SaveDirty()
        WeaponService.FlushDirty()
    end
end)

game:BindToClose(function()
    for _, player in ipairs(Players:GetPlayers()) do
        DropService.StashOwnedDrops(player.UserId)
        WeaponService.StashOwnedBy(player.UserId)
        PlayerDataService.SaveUserId(player.UserId, true)
    end
    WeaponService.FlushDirty()
end)
