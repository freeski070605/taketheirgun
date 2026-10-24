local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Definitions = require(ReplicatedStorage.Shared.WeaponDefinitions)
local OwnershipService = require(script.Parent.OwnershipService)

local WeaponService = {}
local records = {}
local equipped = {}
local remotes

local function publicState(record)
    return {
        GunId = record.GunId,
        WeaponType = record.WeaponType,
        OriginalOwnerUserId = record.OriginalOwnerUserId,
        CurrentOwnerUserId = record.CurrentOwnerUserId,
        TotalKills = record.TotalKills,
        Headshots = record.Headshots,
        TimesStolen = record.TimesStolen,
        OwnerChanges = record.OwnerChanges,
        CurrentStreak = record.CurrentStreak,
        BestStreak = record.BestStreak,
        OwnerCount = OwnershipService.OwnerCount(record),
        Magazine = record.Magazine,
        Reserve = record.Reserve,
        ReloadEnd = record.ReloadEnd,
    }
end

function WeaponService.Init(remoteFolder)
    remotes = remoteFolder
end

function WeaponService.Get(gunId)
    return records[gunId]
end

function WeaponService.GetEquipped(player)
    return records[equipped[player.UserId]]
end

function WeaponService.IsEquipped(player, record)
    local character = player.Character
    return record ~= nil and equipped[player.UserId] == record.GunId
        and record.HolderUserId == player.UserId
        and record.Instance ~= nil and record.Instance:IsA("Tool")
        and record.Instance.Parent == character
        and character ~= nil and character:FindFirstChildOfClass("Humanoid") ~= nil
        and character:FindFirstChildOfClass("Humanoid").Health > 0
end

function WeaponService.Update(record)
    local instance = record.Instance
    if instance then
        for _, key in ipairs({ "GunId", "WeaponType", "TotalKills", "CurrentOwnerUserId", "TimesStolen", "CurrentStreak" }) do
            instance:SetAttribute(key, record[key])
        end
    end
    if remotes then
        remotes.WeaponStateChanged:FireAllClients(publicState(record))
    end
end

function WeaponService.Create(player, weaponType)
    assert(Definitions[weaponType], "Unknown weapon type")
    local definition = Definitions[weaponType]
    local record = {
        GunId = "G-" .. string.upper(HttpService:GenerateGUID(false)),
        WeaponType = weaponType,
        CreatedAt = os.time(),
        TotalKills = 0, Headshots = 0, CurrentStreak = 0, BestStreak = 0,
        History = {}, Magazine = definition.MagazineSize,
        Reserve = definition.ReserveAmmo, ReloadEnd = 0, LastShot = -math.huge,
    }
    OwnershipService.Created(record, player)
    records[record.GunId] = record
    return record
end

local function buildTool(record)
    local definition = Definitions[record.WeaponType]
    local tool = Instance.new("Tool")
    tool.Name = definition.DisplayName
    tool.CanBeDropped = false
    tool.RequiresHandle = true
    local handle = Instance.new("Part")
    handle.Name = "Handle"
    handle.Size = Vector3.new(0.55, 0.75, record.WeaponType == "Shotgun" and 3 or 2.2)
    handle.Color = definition.Color
    handle.Material = Enum.Material.Metal
    handle.CanCollide = false
    handle.Parent = tool
    return tool
end

function WeaponService.Equip(player, record)
    if equipped[player.UserId] then return false end
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local backpack = player:FindFirstChildOfClass("Backpack")
    if not humanoid or humanoid.Health <= 0 or not backpack then return false end
    if record.HolderUserId then return false end

    local tool = buildTool(record)
    record.HolderUserId = player.UserId
    record.Instance = tool
    equipped[player.UserId] = record.GunId
    WeaponService.Update(record)
    tool.Parent = backpack
    humanoid:EquipTool(tool)
    return true
end

function WeaponService.TakeFromPlayer(player)
    local record = WeaponService.GetEquipped(player)
    if not record then return nil end
    equipped[player.UserId] = nil
    record.HolderUserId = nil
    record.CurrentStreak = 0
    record.ReloadEnd = 0
    if record.Instance then record.Instance:Destroy() end
    record.Instance = nil
    WeaponService.Update(record)
    return record
end

function WeaponService.StartReload(player)
    local record = WeaponService.GetEquipped(player)
    if not WeaponService.IsEquipped(player, record) then return end
    local definition = Definitions[record.WeaponType]
    if record.ReloadEnd > os.clock() or record.Magazine >= definition.MagazineSize or record.Reserve <= 0 then return end
    record.ReloadEnd = os.clock() + definition.ReloadTime
    WeaponService.Update(record)
    task.delay(definition.ReloadTime, function()
        if record.HolderUserId == player.UserId then
            WeaponService.FinishReload(record)
        end
    end)
end

function WeaponService.FinishReload(record)
    if record.ReloadEnd == 0 or os.clock() < record.ReloadEnd then return end
    local definition = Definitions[record.WeaponType]
    local amount = math.min(definition.MagazineSize - record.Magazine, record.Reserve)
    record.Magazine += amount
    record.Reserve -= amount
    record.ReloadEnd = 0
    WeaponService.Update(record)
end

function WeaponService.TryConsumeShot(player)
    local record = WeaponService.GetEquipped(player)
    if not WeaponService.IsEquipped(player, record) then return nil end
    WeaponService.FinishReload(record)
    local now = os.clock()
    local definition = Definitions[record.WeaponType]
    if record.ReloadEnd > now or record.Magazine <= 0 then return nil end
    if now - record.LastShot < (1 / definition.FireRate) * 0.92 then return nil end
    record.LastShot = now
    record.Magazine -= 1
    WeaponService.Update(record)
    return record, definition
end

function WeaponService.CreditKill(record, headshot)
    record.TotalKills += 1
    if headshot then record.Headshots += 1 end
    record.CurrentStreak += 1
    record.BestStreak = math.max(record.BestStreak, record.CurrentStreak)
    WeaponService.Update(record)
end

return WeaponService
