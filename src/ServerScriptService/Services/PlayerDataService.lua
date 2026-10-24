local Players = game:GetService("Players")

local PlayerDataService = {}
local names = {}

function PlayerDataService.Remember(player)
    names[player.UserId] = player.DisplayName
end

function PlayerDataService.NameFor(userId)
    if not userId then return "Nobody" end
    local player = Players:GetPlayerByUserId(userId)
    if player then return player.DisplayName end
    return names[userId] or ("User " .. tostring(userId))
end

-- Session-only by design. This API is the persistence boundary for a later milestone.
function PlayerDataService.Forget(_player)
end

return PlayerDataService
