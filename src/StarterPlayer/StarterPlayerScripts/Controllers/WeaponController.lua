local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Definitions = require(ReplicatedStorage.Shared.WeaponDefinitions)

local WeaponController = {}
local player = Players.LocalPlayer
local currentTool
local held = false
local fireLoopRunning = false

local function localFlash(tool)
    local handle = tool:FindFirstChild("Handle")
    if not handle then return end
    local light = Instance.new("PointLight")
    light.Brightness = 4
    light.Range = 8
    light.Color = Color3.fromRGB(255, 216, 112)
    light.Parent = handle
    task.delay(0.06, function()
        if light.Parent then light:Destroy() end
    end)
end

function WeaponController.Init(hud, cameraController)
    local remotes = ReplicatedStorage:WaitForChild("Remotes")

    local function findTool(character)
        local tool = character and character:FindFirstChildOfClass("Tool")
        currentTool = tool and tool:GetAttribute("GunId") and tool or nil
        hud.SetGun(currentTool and currentTool:GetAttribute("GunId") or nil)
    end

    local function bindCharacter(character)
        findTool(character)
        character.ChildAdded:Connect(function() task.defer(findTool, character) end)
        character.ChildRemoved:Connect(function() task.defer(findTool, character) end)
    end

    player.CharacterAdded:Connect(bindCharacter)
    if player.Character then bindCharacter(player.Character) end

    local function fireOnce()
        local tool = currentTool
        if not tool or tool.Parent ~= player.Character then return end
        local camera = workspace.CurrentCamera
        if not camera then return end
        remotes.FireWeapon:FireServer(camera.CFrame.Position, camera.CFrame.LookVector)
        localFlash(tool)
        cameraController.Recoil(tool:GetAttribute("WeaponType"))
    end

    UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end

        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            held = true
            if fireLoopRunning then return end
            fireLoopRunning = true
            task.spawn(function()
                while held do
                    local tool = currentTool
                    if not tool then break end
                    local definition = Definitions[tool:GetAttribute("WeaponType")]
                    if not definition then break end
                    fireOnce()
                    if not definition.Automatic then break end
                    task.wait(1 / definition.FireRate)
                end
                fireLoopRunning = false
            end)
        elseif input.KeyCode == Enum.KeyCode.R then
            remotes.ReloadWeapon:FireServer()
        elseif input.KeyCode == Enum.KeyCode.F then
            hud.ToggleInspect()
        elseif input.KeyCode == Enum.KeyCode.G then
            hud.ToggleDebug()
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then held = false end
    end)
end

return WeaponController
