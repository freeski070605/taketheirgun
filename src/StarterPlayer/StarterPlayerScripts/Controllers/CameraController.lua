local CameraController = {}

function CameraController.Init()
    -- Keep Roblox's default camera and mouse look for the prototype.
end

function CameraController.Recoil(weaponType)
    local camera = workspace.CurrentCamera
    if not camera then return end
    local amount = weaponType == "Shotgun" and 1.6 or 0.45
    camera.CFrame *= CFrame.Angles(math.rad(amount), 0, 0)
end

return CameraController
