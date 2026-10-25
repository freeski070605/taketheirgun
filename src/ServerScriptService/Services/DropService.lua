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
    part.Material = record.Persistent and Enum.Material.Metal or Enum.Material.Neon
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.CFrame = CFrame.new(position + Vector3.new(0, 1.3, 0))

    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = record.Persistent and "TAKE OWNERSHIP" or "TAKE"
    local prefix = record.Persistent and "PERSISTENT | " or "ISSUE | "
    prompt.ObjectText = string.format("%s%s | %d KILLS | %d THEFTS", prefix, definition.DisplayName, record.TotalKills, record.TimesStolen)
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

    task.delay(Constants.DropLifetime, function()
        if record.Claiming then return end
        if drops[record.GunId] ~= part or record.Instance ~= part or part.Parent ~= folder then return end
        drops[record.GunId] = nil
        if record.Persistent then
            WeaponService.Stash(record)
            WeaponService.SaveNow(record)
        else
            WeaponService.Discard(record)
        end
    end)

    return part
end

function DropService.Claim(player, part)
    if typeof(part) ~= "Instance" or not part:IsA("BasePart") or part.Parent ~= folder then return false end

    local gunId = part:GetAttribute("GunId")
    local record = WeaponService.Get(gunId)
    if not record or record.Claiming or drops[gunId] ~= part or record.Instance ~= part or record.HolderUserId then return false end

    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local backpack = player:FindFirstChildOfClass("Backpack")
    if not humanoid or humanoid.Health <= 0 or not root or not backpack then return false end
    if (root.Position - part.Position).Magnitude > Constants.PickupDistance then return false end

    local previousOwner = record.CurrentOwnerUserId
    local ownershipWillChange = previousOwner ~= player.UserId
    if record.Persistent and ownershipWillChange then
        if not PlayerDataService.CanReceiveGun(player.UserId, gunId) then return false end
        record.Claiming = true

        PlayerDataService.AddOwnedGun(player.UserId, gunId)
        if PlayerDataService.IsPersistenceAvailable(player.UserId) then
            local saved = PlayerDataService.SaveUserId(player.UserId, true)
            if not saved then
                PlayerDataService.RemoveOwnedGun(player.UserId, gunId)
                record.Claiming = nil
                return false
            end
        end
    else
        record.Claiming = true
    end

    -- From here to equip there are no yields. The Claiming flag also prevents a
    -- second prompt callback from racing a persistent profile write above.
    drops[gunId] = nil
    record.Instance = nil
    part:Destroy()

    local previousWeapon = WeaponService.TakeFromPlayer(player)
    if previousWeapon then
        DropService.Create(previousWeapon, root.Position + root.CFrame.RightVector * 3)
    end

    local equipped = WeaponService.Equip(player, record)
    if not equipped then
        if record.Persistent and ownershipWillChange then
            PlayerDataService.RemoveOwnedGun(player.UserId, gunId)
            PlayerDataService.SaveUserId(player.UserId, true)
        end
        record.Claiming = nil
        DropService.Create(record, root.Position)
        warn("Validated pickup could not be equipped for", player.UserId, gunId)
        return false
    end

    local eventType, transferPreviousOwner = OwnershipService.Transfer(record, player)
    WeaponService.MarkDirty(record)
    WeaponService.Update(record)

    if record.Persistent and eventType then
        local weaponSaved = WeaponService.SaveNow(record)
        if weaponSaved or not PlayerDataService.IsPersistenceAvailable(player.UserId) then
            if transferPreviousOwner then
                PlayerDataService.RemoveOwnedGun(transferPreviousOwner, gunId)
                PlayerDataService.SaveUserId(transferPreviousOwner, true)
            end
        else
            warn("Persistent ownership changed in-session but could not be saved for", gunId)
        end
    end

    record.Claiming = nil

    if eventType then
        local name = PlayerDataService.NameFor(player.UserId)
        local label = Definitions[record.WeaponType].DisplayName
        local message
        if eventType == "Recovered" then
            message = string.upper(name .. " RECOVERED THEIR " .. label)
        else
            message = string.upper(name .. " TOOK " .. PlayerDataService.NameFor(transferPreviousOwner) .. "'S " .. label)
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
