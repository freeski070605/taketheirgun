local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Definitions = require(ReplicatedStorage.Shared.WeaponDefinitions)

local HUD = {}
local player = Players.LocalPlayer
local states = {}
local currentGunId
local weaponLabel
local ammoLabel
local inspectPanel
local feedLabel
local pickupLabel

local function label(parent, name, size, position, text, textSize)
    local element = Instance.new("TextLabel")
    element.Name = name
    element.Size = size
    element.Position = position
    element.BackgroundTransparency = 0.35
    element.BackgroundColor3 = Color3.fromRGB(13, 16, 22)
    element.TextColor3 = Color3.fromRGB(245, 246, 249)
    element.Font = Enum.Font.GothamBold
    element.TextSize = textSize
    element.Text = text
    element.TextWrapped = true
    element.Parent = parent
    return element
end

local function refresh()
    local state = currentGunId and states[currentGunId]
    if state then
        weaponLabel.Text = Definitions[state.WeaponType].DisplayName .. "  " .. state.GunId:sub(1, 14)
        ammoLabel.Text = string.format("%d / %d  •  %d KILLS", state.Magazine, state.Reserve, state.TotalKills)
    else
        weaponLabel.Text = "UNARMED"
        ammoLabel.Text = ""
    end
end

function HUD.Init()
    local gui = Instance.new("ScreenGui")
    gui.Name = "TakeTheirGunHUD"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.Parent = player:WaitForChild("PlayerGui")

    label(gui, "Crosshair", UDim2.fromOffset(20, 20), UDim2.new(0.5, -10, 0.5, -10), "+", 24).BackgroundTransparency = 1
    weaponLabel = label(gui, "Weapon", UDim2.fromOffset(350, 32), UDim2.new(1, -370, 1, -85), "UNARMED", 18)
    ammoLabel = label(gui, "Ammo", UDim2.fromOffset(350, 32), UDim2.new(1, -370, 1, -48), "", 16)
    feedLabel = label(gui, "Feed", UDim2.fromOffset(470, 44), UDim2.new(0.5, -235, 0, 22), "", 18)
    feedLabel.Visible = false
    pickupLabel = label(gui, "Pickup", UDim2.fromOffset(360, 52), UDim2.new(0.5, -180, 1, -115), "", 16)
    pickupLabel.Visible = false
    inspectPanel = label(gui, "Inspect", UDim2.fromOffset(380, 300), UDim2.new(0.5, -190, 0.5, -150), "", 17)
    inspectPanel.Visible = false
    inspectPanel.TextXAlignment = Enum.TextXAlignment.Left

    local remotes = ReplicatedStorage:WaitForChild("Remotes")
    remotes.WeaponStateChanged.OnClientEvent:Connect(function(state)
        if type(state) ~= "table" or type(state.GunId) ~= "string" then return end
        states[state.GunId] = state
        refresh()
        if inspectPanel.Visible then HUD.SetInspect(true) end
    end)
    remotes.KillFeedEvent.OnClientEvent:Connect(function(message)
        feedLabel.Text = tostring(message)
        feedLabel.Visible = true
        local shown = message
        task.delay(4, function()
            if feedLabel.Text == shown then feedLabel.Visible = false end
        end)
    end)
end

function HUD.SetGun(gunId)
    currentGunId = gunId
    inspectPanel.Visible = false
    refresh()
end

function HUD.SetPickup(text)
    pickupLabel.Text = text or ""
    pickupLabel.Visible = text ~= nil
end

function HUD.SetInspect(visible)
    local state = currentGunId and states[currentGunId]
    inspectPanel.Visible = visible and state ~= nil
    if not inspectPanel.Visible then return end
    inspectPanel.Text = string.format(
        "  %s\n\n  Gun ID: %s\n  Original owner: #%d\n  Current owner: #%d\n\n  Kills: %d   Headshots: %d\n  Times stolen: %d\n  Streak: %d   Best: %d\n  Unique owners: %d\n\n  [F] CLOSE",
        Definitions[state.WeaponType].DisplayName, state.GunId,
        state.OriginalOwnerUserId, state.CurrentOwnerUserId,
        state.TotalKills, state.Headshots, state.TimesStolen,
        state.CurrentStreak, state.BestStreak, state.OwnerCount
    )
end

function HUD.ToggleInspect()
    HUD.SetInspect(not inspectPanel.Visible)
end

return HUD
