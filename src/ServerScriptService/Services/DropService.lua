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

local function scheduleExpiry(record, part)
    local function expire()
        if record.Claiming then
            task.delay(1, expire)
            return
        end
        if drops[record.GunId] ~= part or record.Instance ~= part or part.Parent ~= folder then return end

        drops[record.GunId] = nil
        if record.Persistent then
            WeaponService.Stash(record)
            WeaponService.SaveNow(record)
        else
            WeaponService.Discard(record)
        end
    end
    task.delay(Constants.DropLifetime, expire)
end

local function rollbackPendingIndex(player, gunId, ownershipWillChange)
    if not ownershipWillChange then return end
    PlayerDataService.RemoveOwnedGun(player.UserId, gunId)
    PlayerDataService.SaveUserId(player.UserId, true)
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

    scheduleExpiry(record, part)
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
                rollbackPendingIndex(player, gunId, ownershipWillChange)
                record.Claiming = nil
                return false
            end
        end

        character = player.Character
        humanoid = character and character:FindFirstChildOfClass("Humanoid")
        root = character and character:FindFirstChild("HumanoidRootPart")
        backpack = player:FindFirstChildOfClass("Backpack")
        if not player.Parent or not humanoid or humanoid.Health <= 0 or not root or not backpack
            or part.Parent ~= folder or record.Instance ~= part or drops[gunId] ~= part
            or (root.Position - part.Position).Magnitude > Constants.PickupDistance then
            rollbackPendingIndex(player, gunId, ownershipWillChange)
            record.Claiming = nil
            return false
        end
    else
        record.Claiming = true
    end

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
            rollbackPendingIndex(player, gunId, ownershipWillChange)
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
        local persistenceAvailable = PlayerDataService.IsPersistenceAvailable(player.UserId)
        local weaponSaved = false
        if persistenceAvailable then
            weaponSaved = WeaponService.SaveNow(record)
        end

        if transferPreviousOwner then
            PlayerDataService.RemoveOwnedGun(transferPreviousOwner, gunId)
            if persistenceAvailable and weaponSaved then
                PlayerDataService.SaveUserId(transferPreviousOwner, true)
            end
        end

        if persistenceAvailable and not weaponSaved then
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

function DropService.StashOwnedDrops(userId)
    local toStash = {}
    for gunId, part in pairs(drops) do
        local record = WeaponService.Get(gunId)
        if record and record.Persistent and record.CurrentOwnerUserId == userId and not record.Claiming then
            table.insert(toStash, { record = record, part = part })
        end
    end

    for _, item in ipairs(toStash) do
        drops[item.record.GunId] = nil
        WeaponService.Stash(item.record)
        WeaponService.SaveNow(item.record)
    end
end

return DropService
