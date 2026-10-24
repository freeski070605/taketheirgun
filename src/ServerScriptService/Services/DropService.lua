local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Definitions = require(ReplicatedStorage.Shared.WeaponDefinitions)
local Constants = require(ReplicatedStorage.Shared.Constants)
local WeaponService = require(script.Parent.WeaponService)
local OwnershipService = require(script.Parent.OwnershipService)
local PlayerDataService = require(script.Parent.PlayerDataService)

local DropService = {}
local folder
local remotes
local drops = {}

function DropService.Init(dropFolder, remoteFolder)
    folder = dropFolder
    remotes = remoteFolder
end

function DropService.Create(record, position)
    if not record or record.HolderUserId or record.Instance then return nil end
    local definition = Definitions[record.WeaponType]
    local part = Instance.new("Part")
    part.Name = "Dropped " .. definition.DisplayName
    part.Size = Vector3.new(1.5, 0.35, 2.5)
    part.Color = definition.Color
    part.Material = Enum.Material.Neon
    part.Anchored = true
    part.CanCollide = false
    part.CFrame = CFrame.new(position + Vector3.new(0, 1.3, 0))
    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = "TAKE"
    prompt.ObjectText = string.format("%s | %d KILLS | %d THEFTS", definition.DisplayName, record.TotalKills, record.TimesStolen)
    prompt.KeyboardKeyCode = Enum.KeyCode.E
    prompt.HoldDuration = 0
    prompt.MaxActivationDistance = Constants.PickupDistance
    prompt.RequiresLineOfSight = false
    prompt.Parent = part
    part.Parent = folder
    record.Instance = part
    drops[record.GunId] = part
    WeaponService.Update(record)
    prompt.Triggered:Connect(function(player)
        DropService.Claim(player, part)
    end)
    return part
end

function DropService.Claim(player, part)
    if typeof(part) ~= "Instance" or not part:IsA("BasePart") or part.Parent ~= folder then return false end
    local gunId = part:GetAttribute("GunId")
    local record = WeaponService.Get(gunId)
    if not record or drops[gunId] ~= part or record.Instance ~= part or record.HolderUserId then return false end
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not humanoid or humanoid.Health <= 0 or not root then return false end
    if (root.Position - part.Position).Magnitude > Constants.PickupDistance then return false end

    -- There is no yield between removing the drop and assigning the gun.
    drops[gunId] = nil
    record.Instance = nil
    part:Destroy()

    local previous = WeaponService.TakeFromPlayer(player)
    if previous then DropService.Create(previous, root.Position + root.CFrame.RightVector * 3) end
    local eventType, previousOwner = OwnershipService.Transfer(record, player)
    local equipped = WeaponService.Equip(player, record)
    assert(equipped, "Validated pickup could not be equipped")

    if eventType then
        local name = PlayerDataService.NameFor(player.UserId)
        local label = Definitions[record.WeaponType].DisplayName
        local message
        if eventType == "Recovered" then
            message = string.upper(name .. " RECOVERED THEIR " .. label)
        else
            message = string.upper(name .. " TOOK " .. PlayerDataService.NameFor(previousOwner) .. "'S " .. label)
        end
        remotes.KillFeedEvent:FireAllClients(message)
    end
    return true
end

function DropService.DropPlayerWeapon(player, position)
    local record = WeaponService.TakeFromPlayer(player)
    if record then DropService.Create(record, position) end
end

return DropService
