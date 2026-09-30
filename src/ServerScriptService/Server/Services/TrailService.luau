--!strict
-- Trails: owned trails are kept through rebirth; the equipped one multiplies treadmill
-- gain (see Formulas.TreadmillGain) and renders behind the character.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trails = require(ReplicatedStorage.Shared.Config.Trails)
local DataService = require(script.Parent.DataService)
local SpeedService = require(script.Parent.SpeedService)
local AnnouncementService = require(script.Parent.AnnouncementService)

local TrailService = {}

local PARTICLE_COLORS: { [string]: { string } } = {
	Petals = { "#FFB7C5", "#FFE5EC" },
	Charms = { "#FFFFFF", "#D00000" },
	Steam = { "#FFFFFF", "#FFE8D6" },
	Sparks = { "#FFD60A", "#00B4D8" },
	Foxfire = { "#7FDBFF", "#FF9E00" },
	Stars = { "#FFD86B", "#FFFFFF" },
	Thrust = { "#4361EE", "#FFBA08" },
	Halo = { "#FFF6D5", "#FFD86B" },
}

local function sequence(colors: { string }): ColorSequence
	if #colors == 1 then
		return ColorSequence.new(Color3.fromHex(colors[1]))
	end
	local keypoints = {}
	for index, hex in colors do
		table.insert(keypoints, ColorSequenceKeypoint.new((index - 1) / (#colors - 1), Color3.fromHex(hex)))
	end
	return ColorSequence.new(keypoints)
end

function TrailService.Render(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not root or not root:IsA("BasePart") then
		return
	end
	for _, child in root:GetChildren() do
		if child.Name == "TrailTop" or child.Name == "TrailBottom" or child.Name == "PlayerTrail" or child.Name == "TrailParticles" then
			child:Destroy()
		end
	end
	local data = DataService.Get(player)
	local trail = data and Trails.Get(data.EquippedTrail)
	if not trail then
		return
	end
	local top = Instance.new("Attachment")
	top.Name = "TrailTop"
	top.Position = Vector3.new(0, 0.8, 0.4)
	top.Parent = root
	local bottom = Instance.new("Attachment")
	bottom.Name = "TrailBottom"
	bottom.Position = Vector3.new(0, -1.6, 0.4)
	bottom.Parent = root
	local effect = Instance.new("Trail")
	effect.Name = "PlayerTrail"
	effect.Attachment0 = top
	effect.Attachment1 = bottom
	effect.Color = sequence(trail.Colors)
	effect.Lifetime = 0.5
	effect.LightEmission = 0.7
	effect.WidthScale = NumberSequence.new(trail.Width * 0.5, 0)
	effect.Transparency = NumberSequence.new(0.1, 1)
	effect.FaceCamera = true
	effect.Parent = root
	if trail.Particles then
		local particles = Instance.new("ParticleEmitter")
		particles.Name = "TrailParticles"
		particles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		particles.Color = sequence(PARTICLE_COLORS[trail.Particles] or trail.Colors)
		particles.Rate = 12
		particles.Lifetime = NumberRange.new(0.6, 1)
		particles.Speed = NumberRange.new(0.5, 2)
		particles.Size = NumberSequence.new(0.35, 0)
		particles.LightEmission = 0.8
		particles.SpreadAngle = Vector2.new(180, 180)
		particles.Parent = bottom
	end
end

function TrailService.Owns(player: Player, trailId: string): boolean
	local data = DataService.Get(player)
	return data ~= nil and data.OwnedTrails[trailId] == true
end

function TrailService.Grant(player: Player, trailId: string)
	local data = DataService.Get(player)
	if data and Trails.Get(trailId) then
		data.OwnedTrails[trailId] = true
		DataService.Changed(player, "OwnedTrails")
	end
end

function TrailService.Buy(player: Player, trailId: string, spend: (Player, number) -> boolean): (boolean, string?)
	local trail = Trails.Get(trailId)
	local data = DataService.Get(player)
	if not trail or not data then
		return false, "Unknown trail"
	end
	if data.OwnedTrails[trailId] then
		return false, "You already own this trail"
	end
	if trail.Price <= 0 then
		return false, "This trail can't be bought"
	end
	if not spend(player, trail.Price) then
		return false, "Not enough cash"
	end
	data.OwnedTrails[trailId] = true
	DataService.Changed(player, "OwnedTrails")
	TrailService.Equip(player, trailId)
	AnnouncementService.Notify(player, trail.DisplayName .. " trail unlocked!", "Success")
	return true, nil
end

function TrailService.Equip(player: Player, trailId: string): (boolean, string?)
	local data = DataService.Get(player)
	if not data then
		return false, "Not loaded"
	end
	if trailId ~= "" and not data.OwnedTrails[trailId] then
		return false, "You don't own that trail"
	end
	data.EquippedTrail = trailId
	DataService.Changed(player, "EquippedTrail")
	SpeedService.PublishDerived(player)
	TrailService.Render(player)
	return true, nil
end

function TrailService.Init() end

function TrailService.Start()
	local function hook(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("HumanoidRootPart", 10)
			TrailService.Render(player)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end
	DataService.Loaded:Connect(function(player)
		TrailService.Render(player)
	end)
end

return TrailService
