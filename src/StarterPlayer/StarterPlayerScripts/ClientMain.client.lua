local Controllers = script.Parent.Controllers
local HUD = require(Controllers.HUDController)
local Camera = require(Controllers.CameraController)
local Weapon = require(Controllers.WeaponController)
local Interaction = require(Controllers.InteractionController)

HUD.Init()
Camera.Init()
Weapon.Init(HUD, Camera)
Interaction.Init(HUD)
