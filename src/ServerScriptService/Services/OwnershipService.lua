local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Shared.Constants)

local OwnershipService = {}

local function append(record, event)
    table.insert(record.History, event)
    if #record.History > Constants.MaxHistory then
        table.remove(record.History, 1)
    end
end

function OwnershipService.Created(record, player)
    record.OriginalOwnerUserId = player.UserId
    record.CurrentOwnerUserId = player.UserId
    record.UniqueOwners = { [player.UserId] = true }
    record.OwnerChanges = 0
    record.TimesStolen = 0
    append(record, { Type = "Created", UserId = player.UserId, Timestamp = os.time() })
end

function OwnershipService.Transfer(record, player)
    local previous = record.CurrentOwnerUserId
    if previous == player.UserId then return nil end

    local recovered = player.UserId == record.OriginalOwnerUserId
        and previous ~= record.OriginalOwnerUserId
    local eventType = recovered and "Recovered" or "Stolen"
    record.CurrentOwnerUserId = player.UserId
    record.OwnerChanges += 1
    if not recovered then record.TimesStolen += 1 end
    record.CurrentStreak = 0
    record.UniqueOwners[player.UserId] = true
    append(record, {
        Type = eventType, FromUserId = previous,
        ToUserId = player.UserId, Timestamp = os.time(),
    })
    return eventType, previous
end

function OwnershipService.OwnerCount(record)
    local count = 0
    for _ in pairs(record.UniqueOwners) do count += 1 end
    return count
end

return OwnershipService
