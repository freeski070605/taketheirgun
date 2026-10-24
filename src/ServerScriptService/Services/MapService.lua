local MapService = {}

local function block(parent, name, size, position, color)
    local part = Instance.new("Part")
    part.Name = name
    part.Anchored = true
    part.Size = size
    part.Position = position
    part.Color = color
    part.Material = Enum.Material.Concrete
    part.Parent = parent
    return part
end

function MapService.Build()
    local map = workspace:FindFirstChild("Map") or Instance.new("Folder")
    map.Name = "Map"
    map.Parent = workspace
    if map:FindFirstChild("Floor") then return map end

    local floorColor = Color3.fromRGB(79, 84, 90)
    local coverColor = Color3.fromRGB(120, 126, 133)
    block(map, "Floor", Vector3.new(120, 2, 120), Vector3.new(0, -1, 0), floorColor)
    block(map, "North Wall", Vector3.new(120, 16, 2), Vector3.new(0, 8, -60), coverColor)
    block(map, "South Wall", Vector3.new(120, 16, 2), Vector3.new(0, 8, 60), coverColor)
    block(map, "West Wall", Vector3.new(2, 16, 120), Vector3.new(-60, 8, 0), coverColor)
    block(map, "East Wall", Vector3.new(2, 16, 120), Vector3.new(60, 8, 0), coverColor)
    for _, data in ipairs({
        { Vector3.new(-20, 3, -17), Vector3.new(13, 6, 5) },
        { Vector3.new(22, 3, -12), Vector3.new(6, 6, 14) },
        { Vector3.new(-15, 3, 22), Vector3.new(7, 6, 12) },
        { Vector3.new(19, 3, 21), Vector3.new(15, 6, 5) },
        { Vector3.new(0, 2.5, 0), Vector3.new(9, 5, 9) },
    }) do
        block(map, "Cover", data[2], data[1], coverColor)
    end
    for index, position in ipairs({
        Vector3.new(-42, 1, -42), Vector3.new(42, 1, 42),
        Vector3.new(-42, 1, 42), Vector3.new(42, 1, -42),
        Vector3.new(0, 1, -43), Vector3.new(0, 1, 43),
        Vector3.new(-43, 1, 0), Vector3.new(43, 1, 0),
    }) do
        local spawn = Instance.new("SpawnLocation")
        spawn.Name = "Spawn " .. index
        spawn.Size = Vector3.new(8, 1, 8)
        spawn.Position = position
        spawn.Anchored = true
        spawn.Neutral = true
        spawn.Duration = 0
        spawn.Color = Color3.fromRGB(85, 150, 210)
        spawn.Parent = map
    end
    return map
end

return MapService
