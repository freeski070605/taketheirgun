local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Definitions = require(ReplicatedStorage.Shared.WeaponDefinitions)
local Constants = require(ReplicatedStorage.Shared.Constants)

local InteractionController = {}

function InteractionController.Init(hud)
    local player = Players.LocalPlayer
    local drops = workspace:WaitForChild("DroppedWeapons")
    local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RequestPickup")
    local nearest
    local elapsed = 0

    RunService.RenderStepped:Connect(function(dt)
        elapsed += dt
        if elapsed < 0.1 then return end
        elapsed = 0
        nearest = nil
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if not root or not humanoid or humanoid.Health <= 0 then hud.SetPickup(nil) return end
        local best = Constants.PickupDistance
        for _, part in ipairs(drops:GetChildren()) do
            if part:IsA("BasePart") then
                local distance = (part.Position - root.Position).Magnitude
                if distance <= best then nearest, best = part, distance end
            end
        end
        if nearest then
            local weaponType = nearest:GetAttribute("WeaponType")
            local label = Definitions[weaponType] and Definitions[weaponType].DisplayName or "Gun"
            hud.SetPickup(string.format("%s  |  %d KILLS  |  %d THEFTS\n[E] TAKE", label,
                nearest:GetAttribute("TotalKills") or 0, nearest:GetAttribute("TimesStolen") or 0))
        else
            hud.SetPickup(nil)
        end
    end)

    UserInputService.InputBegan:Connect(function(input, processed)
        if processed or input.KeyCode ~= Enum.KeyCode.E or not nearest then return end
        remote:FireServer(nearest)
    end)
end

return InteractionController
