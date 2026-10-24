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

local debugSnapshot = remoteFolder:FindFirstChild("DebugWeaponSnapshot")
if not debugSnapshot then
    debugSnapshot = Instance.new("RemoteFunction")
    debugSnapshot.Name = "DebugWeaponSnapshot"
    debugSnapshot.Parent = remoteFolder
end

WeaponService.Init(remoteFolder)
DropService.Init(dropFolder, remoteFolder)
CombatService.Init(remoteFolder)

local starterTypes = { "Pistol", "SMG", "AssaultRifle", "Shotgun" }
local starterIndex = 0

local function onCharacter(player, character)
    CombatService.MarkSpawn(player)
    local humanoid = character:WaitForChild("Humanoid")
    humanoid.Died:Connect(function()
        local root = character:FindFirstChild("HumanoidRootPart")
        DropService.DropPlayerWeapon(player, root and root.Position or character:GetPivot().Position)
    end)
    task.defer(function()
        if player.Character ~= character or humanoid.Health <= 0 or WeaponService.GetEquipped(player) then return end
        starterIndex += 1
        local record = WeaponService.Create(player, starterTypes[((starterIndex - 1) % #starterTypes) + 1])
        WeaponService.Equip(player, record)
    end)
end

local function onPlayer(player)
    PlayerDataService.Remember(player)
    player.CharacterAdded:Connect(function(character) onCharacter(player, character) end)
    if player.Character then onCharacter(player, player.Character) end
end

Players.PlayerAdded:Connect(onPlayer)
for _, player in ipairs(Players:GetPlayers()) do onPlayer(player) end

Players.PlayerRemoving:Connect(function(player)
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local position = root and root.Position or (player.Character and player.Character:GetPivot().Position)
    if position then
        DropService.DropPlayerWeapon(player, position)
    else
        WeaponService.TakeFromPlayer(player)
    end
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
