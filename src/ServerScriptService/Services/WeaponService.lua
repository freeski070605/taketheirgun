local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Definitions = require(ReplicatedStorage.Shared.WeaponDefinitions)
local OwnershipService = require(script.Parent.OwnershipService)
local PersistenceService = require(script.Parent.PersistenceService)

local WeaponService = {}
local records = {}
local equipped = {}
local dirty = {}
local remotes

local function presentationFor(record)
    local instance = record.Instance
    if not instance then return record.Persistent and "STORED" or "NONE" end
    if instance:IsA("Tool") then return "HELD" end
    if instance:IsA("BasePart") then return "DROPPED" end
    return "OTHER"
end

local function publicState(record)
    return {
        GunId = record.GunId,
        WeaponType = record.WeaponType,
        OriginalOwnerUserId = record.OriginalOwnerUserId,
        CurrentOwnerUserId = record.CurrentOwnerUserId,
        HolderUserId = record.HolderUserId,
        Presentation = presentationFor(record),
        Persistent = record.Persistent == true,
        IssueWeapon = record.IssueWeapon == true,
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

local function serialize(record)
    local owners = {}
    for userId in pairs(record.UniqueOwners or {}) do
        table.insert(owners, userId)
    end
    table.sort(owners)
    return {
        Version = 1,
        GunId = record.GunId,
        WeaponType = record.WeaponType,
        CreatedAt = record.CreatedAt,
        OriginalOwnerUserId = record.OriginalOwnerUserId,
        CurrentOwnerUserId = record.CurrentOwnerUserId,
        TotalKills = record.TotalKills,
        Headshots = record.Headshots,
        TimesStolen = record.TimesStolen,
        OwnerChanges = record.OwnerChanges,
        BestStreak = record.BestStreak,
        History = table.clone(record.History),
        UniqueOwners = owners,
        Magazine = record.Magazine,
        Reserve = record.Reserve,
        Persistent = true,
    }
end

local function hydrate(data)
    if type(data) ~= "table" or type(data.GunId) ~= "string" or not Definitions[data.WeaponType] then
        return nil
    end
    local definition = Definitions[data.WeaponType]
    local owners = {}
    if type(data.UniqueOwners) == "table" then
        for _, userId in ipairs(data.UniqueOwners) do
            if type(userId) == "number" then owners[userId] = true end
        end
    end
    if type(data.OriginalOwnerUserId) == "number" then owners[data.OriginalOwnerUserId] = true end
    if type(data.CurrentOwnerUserId) == "number" then owners[data.CurrentOwnerUserId] = true end

    return {
        GunId = data.GunId,
        WeaponType = data.WeaponType,
        CreatedAt = tonumber(data.CreatedAt) or os.time(),
        OriginalOwnerUserId = data.OriginalOwnerUserId,
        CurrentOwnerUserId = data.CurrentOwnerUserId,
        TotalKills = tonumber(data.TotalKills) or 0,
        Headshots = tonumber(data.Headshots) or 0,
        TimesStolen = tonumber(data.TimesStolen) or 0,
        OwnerChanges = tonumber(data.OwnerChanges) or 0,
        CurrentStreak = 0,
        BestStreak = tonumber(data.BestStreak) or 0,
        History = type(data.History) == "table" and data.History or {},
        UniqueOwners = owners,
        Magazine = math.clamp(tonumber(data.Magazine) or definition.MagazineSize, 0, definition.MagazineSize),
        Reserve = math.max(0, tonumber(data.Reserve) or definition.ReserveAmmo),
        ReloadEnd = 0,
        LastShot = -math.huge,
        Persistent = true,
        IssueWeapon = false,
        HolderUserId = nil,
        Instance = nil,
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

function WeaponService.GetDebugSnapshot()
    local snapshot = {}
    for _, record in pairs(records) do table.insert(snapshot, publicState(record)) end
    table.sort(snapshot, function(a, b)
        if a.TotalKills ~= b.TotalKills then return a.TotalKills > b.TotalKills end
        return a.GunId < b.GunId
    end)
    return snapshot
end

function WeaponService.GetInventorySnapshot(player)
    local snapshot = {}
    for _, record in pairs(records) do
        if record.Persistent and record.CurrentOwnerUserId == player.UserId then
            table.insert(snapshot, publicState(record))
        end
    end
    table.sort(snapshot, function(a, b)
        if a.TotalKills ~= b.TotalKills then return a.TotalKills > b.TotalKills end
        return a.GunId < b.GunId
    end)
    return snapshot
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
        for _, key in ipairs({ "GunId", "WeaponType", "TotalKills", "CurrentOwnerUserId", "TimesStolen", "CurrentStreak", "Persistent", "IssueWeapon" }) do
            instance:SetAttribute(key, record[key])
        end
    end
    if remotes then remotes.WeaponStateChanged:FireAllClients(publicState(record)) end
end

function WeaponService.MarkDirty(record)
    if record and record.Persistent then dirty[record.GunId] = true end
end

function WeaponService.SaveNow(record)
    if not record or not record.Persistent then return true end
    local ok = PersistenceService.SaveWeapon(record.GunId, serialize(record))
    if ok then dirty[record.GunId] = nil end
    return ok
end

function WeaponService.FlushDirty()
    for gunId in pairs(dirty) do
        local record = records[gunId]
        if record then WeaponService.SaveNow(record) else dirty[gunId] = nil end
    end
end

function WeaponService.Create(player, weaponType, persistent)
    assert(Definitions[weaponType], "Unknown weapon type")
    local definition = Definitions[weaponType]
    local isPersistent = persistent == true
    local record = {
        GunId = (isPersistent and "G-" or "I-") .. string.upper(HttpService:GenerateGUID(false)),
        WeaponType = weaponType,
        CreatedAt = os.time(),
        TotalKills = 0, Headshots = 0, CurrentStreak = 0, BestStreak = 0,
        History = {}, Magazine = definition.MagazineSize,
        Reserve = definition.ReserveAmmo, ReloadEnd = 0, LastShot = -math.huge,
        Persistent = isPersistent,
        IssueWeapon = not isPersistent,
    }
    OwnershipService.Created(record, player)
    records[record.GunId] = record
    if isPersistent then
        WeaponService.MarkDirty(record)
        WeaponService.SaveNow(record)
    end
    return record
end

function WeaponService.CreateIssue(player, weaponType)
    return WeaponService.Create(player, weaponType or "Pistol", false)
end

function WeaponService.LoadPersistent(gunId)
    if records[gunId] then return records[gunId], true end
    local ok, data = PersistenceService.LoadWeapon(gunId)
    if not ok then return nil, false end
    local record = hydrate(data)
    if record then records[record.GunId] = record end
    return record, true
end

function WeaponService.LoadOwnedForPlayer(player, gunIds)
    local valid = {}
    local complete = true
    for _, gunId in ipairs(gunIds) do
        local record, ok = WeaponService.LoadPersistent(gunId)
        if not ok then
            complete = false
        elseif record and record.CurrentOwnerUserId == player.UserId then
            table.insert(valid, gunId)
        end
    end
    return valid, complete
end

function WeaponService.FindStoredOwned(userId, preferredGunId)
    if preferredGunId then
        local preferred = records[preferredGunId]
        if preferred and preferred.Persistent and preferred.CurrentOwnerUserId == userId
            and not preferred.HolderUserId and not preferred.Instance then
            return preferred
        end
    end
    for _, record in pairs(records) do
        if record.Persistent and record.CurrentOwnerUserId == userId
            and not record.HolderUserId and not record.Instance then
            return record
        end
    end
    return nil
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
    if record.HolderUserId or record.Instance then return false end

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
    WeaponService.MarkDirty(record)
    WeaponService.Update(record)
    return record
end

function WeaponService.Stash(record)
    if not record then return end
    if record.HolderUserId then equipped[record.HolderUserId] = nil end
    record.HolderUserId = nil
    record.CurrentStreak = 0
    record.ReloadEnd = 0
    if record.Instance then record.Instance:Destroy() end
    record.Instance = nil
    WeaponService.MarkDirty(record)
    WeaponService.Update(record)
end

function WeaponService.StashOwnedBy(userId)
    for _, record in pairs(records) do
        if record.CurrentOwnerUserId == userId then
            if record.Persistent then
                WeaponService.Stash(record)
                WeaponService.SaveNow(record)
            elseif record.IssueWeapon then
                WeaponService.Discard(record)
            end
        end
    end
end

function WeaponService.Discard(record)
    if not record then return end
    if record.HolderUserId then equipped[record.HolderUserId] = nil end
    if record.Instance then record.Instance:Destroy() end
    dirty[record.GunId] = nil
    records[record.GunId] = nil
end

function WeaponService.StartReload(player)
    local record = WeaponService.GetEquipped(player)
    if not WeaponService.IsEquipped(player, record) then return end
    local definition = Definitions[record.WeaponType]
    if record.ReloadEnd > os.clock() or record.Magazine >= definition.MagazineSize or record.Reserve <= 0 then return end
    record.ReloadEnd = os.clock() + definition.ReloadTime
    WeaponService.Update(record)
    task.delay(definition.ReloadTime, function()
        if record.HolderUserId == player.UserId then WeaponService.FinishReload(record) end
    end)
end

function WeaponService.FinishReload(record)
    if record.ReloadEnd == 0 or os.clock() < record.ReloadEnd then return end
    local definition = Definitions[record.WeaponType]
    local amount = math.min(definition.MagazineSize - record.Magazine, record.Reserve)
    record.Magazine += amount
    record.Reserve -= amount
    record.ReloadEnd = 0
    WeaponService.MarkDirty(record)
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
    WeaponService.MarkDirty(record)
    WeaponService.Update(record)
    return record, definition
end

function WeaponService.CreditKill(record, headshot)
    record.TotalKills += 1
    if headshot then record.Headshots += 1 end
    record.CurrentStreak += 1
    record.BestStreak = math.max(record.BestStreak, record.CurrentStreak)
    WeaponService.MarkDirty(record)
    WeaponService.Update(record)
end

return WeaponService
