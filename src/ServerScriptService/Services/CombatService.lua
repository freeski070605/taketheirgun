local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Shared.Constants)
local WeaponService = require(script.Parent.WeaponService)
local PlayerDataService = require(script.Parent.PlayerDataService)

local CombatService = {}
local remotes
local spawnTimes = {}

function CombatService.Init(remoteFolder)
    remotes = remoteFolder
end

function CombatService.MarkSpawn(player)
    spawnTimes[player.UserId] = os.clock()
end

local function spreadDirection(direction, degrees)
    local angle = math.rad(degrees)
    local right = direction:Cross(Vector3.yAxis)
    if right.Magnitude < 0.01 then right = Vector3.xAxis end
    right = right.Unit
    local up = right:Cross(direction).Unit
    local x = (math.random() * 2 - 1) * math.tan(angle)
    local y = (math.random() * 2 - 1) * math.tan(angle)
    return (direction + right * x + up * y).Unit
end

function CombatService.Fire(player, clientOrigin, clientDirection)
    if typeof(clientOrigin) ~= "Vector3" or typeof(clientDirection) ~= "Vector3" then return end
    for _, component in ipairs({ clientOrigin.X, clientOrigin.Y, clientOrigin.Z,
        clientDirection.X, clientDirection.Y, clientDirection.Z }) do
        if component ~= component or math.abs(component) == math.huge then return end
    end
    if clientDirection.Magnitude < 0.95 or clientDirection.Magnitude > 1.05 then return end

    local character = player.Character
    local head = character and character:FindFirstChild("Head")
    if not head then return end
    if (clientOrigin - head.Position).Magnitude > Constants.MaxAimOriginOffset then return end

    local record, definition = WeaponService.TryConsumeShot(player)
    if not record then return end

    local rayOrigin = head.Position
    local aimPoint = clientOrigin + clientDirection.Unit * definition.Range
    local offset = aimPoint - rayOrigin
    if offset.Magnitude < 0.01 then return end
    local baseDirection = offset.Unit

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { character, workspace.DroppedWeapons }
    params.IgnoreWater = true

    local endpoints = {}
    for _ = 1, definition.PelletCount do
        local direction = spreadDirection(baseDirection, definition.Spread)
        local hit = workspace:Raycast(rayOrigin, direction * definition.Range, params)
        table.insert(endpoints, hit and hit.Position or (rayOrigin + direction * definition.Range))

        if hit then
            local model = hit.Instance:FindFirstAncestorOfClass("Model")
            local humanoid = model and model:FindFirstChildOfClass("Humanoid")
            local victim = model and Players:GetPlayerFromCharacter(model)
            if humanoid and victim and victim ~= player and humanoid.Health > 0 then
                if os.clock() - (spawnTimes[victim.UserId] or 0) >= Constants.SpawnProtectionSeconds then
                    local headshot = hit.Instance.Name == "Head"
                    local damage = definition.Damage * (headshot and definition.HeadshotMultiplier or 1)
                    local lethal = humanoid.Health <= damage
                    humanoid:TakeDamage(damage)
                    if lethal and humanoid.Health <= 0 then
                        WeaponService.CreditKill(record, headshot)
                        remotes.KillFeedEvent:FireAllClients(string.upper(
                            PlayerDataService.NameFor(player.UserId) .. " ELIMINATED "
                            .. PlayerDataService.NameFor(victim.UserId) .. " WITH " .. definition.DisplayName
                        ))
                    end
                end
            end
        end
    end

    remotes.ShotFired:FireAllClients(player.UserId, rayOrigin, endpoints)
end

return CombatService
