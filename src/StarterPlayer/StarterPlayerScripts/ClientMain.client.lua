local Controllers = script.Parent.Controllers
local HUD = require(Controllers.HUDController)
local Camera = require(Controllers.CameraController)
local Weapon = require(Controllers.WeaponController)
local Interaction = require(Controllers.InteractionController)
local Effects = require(Controllers.EffectsController)

HUD.Init()
Camera.Init()
Effects.Init()
Weapon.Init(HUD, Camera)
Interaction.Init(HUD)
