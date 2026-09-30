--!strict
-- Localizes ProximityPrompts per viewer. The server owns every prompt and re-checks hold
-- time and rules; this only changes what each player sees (text, hold time, visibility).
--   Pen slots: owner -> "Pick Up" / "Place Here"; others -> "Steal" (1.5s hold)
--   Carried items: hidden for the carrier, "Snatch" for everyone else
--   Treadmill / Barrier: owner only
--   Egg pedestals: "Grab Egg" with the egg's name (or ???)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local GameSettings = require(Shared.Config.GameSettings)
local Characters = require(Shared.Config.Characters)
local State = require(script.Parent.State)

local player = Players.LocalPlayer

local Prompts = {}

local tracked: { [ProximityPrompt]: boolean } = {}

local function plotModelOf(instance: Instance): Model?
	local node: Instance? = instance
	while node and node ~= workspace do
		if node:IsA("Model") and CollectionService:HasTag(node, "Plot") then
			return node
		end
		node = node.Parent
	end
	return nil
end

local function discovered(characterId: string): boolean
	local index = State.Get("Index")
	local entry = if type(index) == "table" then index[characterId] else nil
	return entry ~= nil and entry.Discovered == true
end

local function update(prompt: ProximityPrompt)
	local parent = prompt.Parent
	if not parent then
		return
	end
	local name = prompt.Name
	local carrying = player:GetAttribute("Carrying") == true
	if name == "SlotPrompt" then
		local plot = plotModelOf(parent)
		local ownerId = if plot then plot:GetAttribute("OwnerUserId") else nil
		local occupied = parent:GetAttribute("Occupied") == true
		local active = parent:GetAttribute("Active") == true
		if ownerId == player.UserId then
			if carrying and not occupied and active then
				prompt.Enabled = true
				prompt.ActionText = "Place Here"
				prompt.HoldDuration = GameSettings.OwnerPickupHoldTime
			elseif not carrying and occupied then
				prompt.Enabled = true
				prompt.ActionText = "Pick Up"
				prompt.HoldDuration = GameSettings.OwnerPickupHoldTime
			else
				prompt.Enabled = false
			end
		else
			local protected = plot ~= nil and plot:GetAttribute("Protected") == true
			local barrier = plot and plot:GetAttribute("BarrierUntil")
			local locked = type(barrier) == "number" and barrier > workspace:GetServerTimeNow()
			if ownerId ~= nil and occupied and not carrying and not protected and not locked then
				prompt.Enabled = true
				prompt.ActionText = "Steal"
				prompt.HoldDuration = GameSettings.RaidHoldTime
				local characterId = parent:GetAttribute("CharacterId")
				prompt.ObjectText = if type(characterId) == "string" and Characters.Find(characterId) then Characters.Get(characterId).DisplayName else ""
			else
				prompt.Enabled = false
			end
		end
	elseif name == "SnatchPrompt" then
		local carrierId = prompt:GetAttribute("CarrierUserId")
		prompt.Enabled = carrierId ~= player.UserId and not carrying
	elseif name == "TreadmillPrompt" or name == "BarrierPrompt" then
		local plot = plotModelOf(parent)
		prompt.Enabled = plot ~= nil and plot:GetAttribute("OwnerUserId") == player.UserId
	elseif name == "GrabPrompt" then
		local model = parent:FindFirstAncestorWhichIsA("Model")
		local egg = parent:FindFirstChildWhichIsA("Model")
		local source = egg or model
		local characterId = source and source:GetAttribute("CharacterId")
		if type(characterId) == "string" and Characters.Find(characterId) then
			prompt.ObjectText = if discovered(characterId) then Characters.Get(characterId).DisplayName else "???"
		end
	end
end

local function track(instance: Instance)
	if instance:IsA("ProximityPrompt") and not tracked[instance] then
		tracked[instance] = true
		update(instance)
		instance.Destroying:Connect(function()
			tracked[instance] = nil
		end)
	end
end

function Prompts.Init() end

function Prompts.Start()
	for _, descendant in workspace:GetDescendants() do
		track(descendant)
	end
	workspace.DescendantAdded:Connect(track)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.2 then
			return
		end
		elapsed = 0
		for prompt in tracked do
			if prompt.Parent then
				update(prompt)
			else
				tracked[prompt] = nil
			end
		end
	end)
end

return Prompts
