local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EffectsController = {}

local function makeTracer(origin, endpoint)
    if typeof(origin) ~= "Vector3" or typeof(endpoint) ~= "Vector3" then return end
    local delta = endpoint - origin
    local distance = delta.Magnitude
    if distance < 0.05 or distance > 600 then return end

    local tracer = Instance.new("Part")
    tracer.Name = "ShotTracer"
    tracer.Anchored = true
    tracer.CanCollide = false
    tracer.CanQuery = false
    tracer.CanTouch = false
    tracer.Material = Enum.Material.Neon
    tracer.Color = Color3.fromRGB(255, 226, 133)
    tracer.Transparency = 0.2
    tracer.Size = Vector3.new(0.045, 0.045, distance)
    tracer.CFrame = CFrame.lookAt(origin:Lerp(endpoint, 0.5), endpoint)
    tracer.Parent = workspace
    Debris:AddItem(tracer, 0.07)
end

function EffectsController.Init()
    local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ShotFired")
    remote.OnClientEvent:Connect(function(_shooterUserId, origin, endpoints)
        if typeof(origin) ~= "Vector3" or type(endpoints) ~= "table" then return end
        for index, endpoint in ipairs(endpoints) do
            if index > 12 then break end
            makeTracer(origin, endpoint)
        end
    end)
end

return EffectsController
