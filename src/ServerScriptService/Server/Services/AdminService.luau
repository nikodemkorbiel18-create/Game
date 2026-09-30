--!strict
-- Admin panel commands. Admins: the place owner (or the owning group's owner), anyone in
-- GameSettings.AdminUserIds, and everyone while testing in Studio. Events can be started in
-- every server at once through MessagingService (see EventService.StartManual).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local GameSettings = require(Shared.Config.GameSettings)
local Characters = require(Shared.Config.Characters)
local Zones = require(Shared.Config.Zones)
local Sizes = require(Shared.Config.Sizes)
local Mutations = require(Shared.Config.Mutations)
local Rarities = require(Shared.Config.Rarities)
local Events = require(Shared.Config.Events)
local Monetization = require(Shared.Config.Monetization)
local Types = require(Shared.Types)

local DataService = require(script.Parent.DataService)
local PassService = require(script.Parent.PassService)
local IncomeService = require(script.Parent.IncomeService)
local SpeedService = require(script.Parent.SpeedService)
local EggSpawnService = require(script.Parent.EggSpawnService)
local EventService = require(script.Parent.EventService)
local CarryService = require(script.Parent.CarryService)
local HatchService = require(script.Parent.HatchService)
local BossService = require(script.Parent.BossService)
local MonetizationService = require(script.Parent.MonetizationService)
local AnnouncementService = require(script.Parent.AnnouncementService)
local Remote = require(script.Parent.Parent.Lib.Remote)
local Guard = require(script.Parent.Parent.Lib.Guard)
local World = require(script.Parent.Parent.Lib.World)

local AdminService = {}

local admins: { [Player]: boolean } = {}

local function checkAdmin(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	if table.find(GameSettings.AdminUserIds, player.UserId) then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then
		return true
	end
	if game.CreatorType == Enum.CreatorType.Group then
		local ok, rank = pcall(player.GetRankInGroupAsync, player, game.CreatorId)
		if ok and rank >= 255 then
			return true
		end
	end
	return false
end

function AdminService.IsAdmin(player: Player): boolean
	return admins[player] == true
end

local function giveCharacter(player: Player, characterId: string, sizeTier: number, mutation: string?, asEgg: boolean)
	local size = Sizes.Get(sizeTier)
	local item: Types.Item = {
		Uid = World.MakeUid(),
		Kind = if asEgg then "Egg" else "Character",
		CharacterId = characterId,
		SizeTier = sizeTier,
		Kg = math.floor((size.MinKg + size.MaxKg) / 2 * 10) / 10,
		Mutation = mutation,
		Color = 1,
		Source = "Admin",
	}
	CarryService.GiveToPlayer(player, item, nil, true)
end

local COMMANDS: { [string]: (Player, { any }) -> string } = {
	GiveCash = function(player, args)
		local amount = Guard.Number(args[1], 0, 1e30) or 1e6
		IncomeService.AddCash(player, amount, false)
		return "Gave cash"
	end,
	GiveSpeed = function(player, args)
		local amount = Guard.Number(args[1], 0, 1e30) or 1e4
		SpeedService.AddSpeed(player, amount)
		return "Gave Speed"
	end,
	SpawnEgg = function(_player, args)
		local zoneId = Guard.Integer(args[1], 1, Zones.Count) or 1
		local rarity = if type(args[2]) == "string" and Rarities.ById[args[2]] then args[2] else nil
		local mutation = if type(args[3]) == "string" and Mutations.ById[args[3]] then args[3] else nil
		return if EggSpawnService.AdminSpawn(zoneId, rarity, mutation) then "Spawned egg" else "No pedestal / no character of that rarity in that zone"
	end,
	ResetEggs = function()
		EggSpawnService.ResetAll()
		return "Eggs reset"
	end,
	GiveCharacter = function(player, args)
		local id = Guard.String(args[1], 64)
		if not id or not Characters.Find(id) then
			return "Unknown character"
		end
		local sizeTier = Guard.Integer(args[2], 1, #Sizes.List) or 3
		local mutation = if type(args[3]) == "string" and Mutations.ById[args[3]] then args[3] else nil
		giveCharacter(player, id, sizeTier, mutation, args[4] == true)
		return "Gave " .. id
	end,
	HatchAll = function(player)
		local data = DataService.Get(player)
		if not data then
			return "Not loaded"
		end
		local count = 0
		for key, item in data.Pen do
			if item.Kind == "Egg" and HatchService.FinishNow(player, key) then
				count += 1
			end
		end
		return "Hatched " .. count
	end,
	StartEvent = function(_player, args)
		local id = Guard.String(args[1], 32)
		local minutes = Guard.Number(args[2], 1, 24 * 60) or 10
		if not id or not Events.ById[id] then
			return "Unknown event"
		end
		EventService.StartManual(id, minutes * 60, args[3] == true)
		return "Started " .. id
	end,
	StopEvent = function(_player, args)
		local id = Guard.String(args[1], 32)
		if id then
			EventService.StopManual(id)
		end
		return "Stopped"
	end,
	ServerLuck = function(player)
		EventService.StartServerLuck(player)
		return "Server Luck started"
	end,
	GrantPass = function(player, args)
		local key = Guard.String(args[1], 32)
		if not key or not Monetization.PassByKey[key] then
			return "Unknown pass"
		end
		PassService.Grant(player, key)
		return "Granted pass " .. key .. " (this session)"
	end,
	GrantProduct = function(player, args)
		local key = Guard.String(args[1], 32)
		if not key or not MonetizationService.GrantProduct(player, key) then
			return "Unknown product"
		end
		return "Granted " .. key
	end,
	ClearBoss = function(player)
		local data = DataService.Get(player)
		if data then
			data.BossCleared = true
			DataService.Changed(player, "BossCleared")
			player:SetAttribute("BossCleared", true)
		end
		return "Gatekeeper cleared"
	end,
	EndShield = function(player)
		local data = DataService.Get(player)
		if data then
			data.Playtime = math.max(data.Playtime, GameSettings.NewPlayerProtection)
			DataService.Changed(player, "Playtime")
		end
		return "New-player shield removed (so your base can be raided)"
	end,
	ResetBoss = function(player)
		BossService.ResetClear(player)
		return "Gatekeeper reset"
	end,
	TeleportZone = function(player, args)
		local zoneId = Guard.Integer(args[1], 1, Zones.Count) or 1
		for _, part in World.TaggedParts("Nest") do
			if part:GetAttribute("ZoneId") == zoneId then
				World.Teleport(player, CFrame.new(part.Position + Vector3.new(0, 5, 30)))
				return "Teleported"
			end
		end
		return "Zone not found"
	end,
	Announce = function(_player, args)
		local text = Guard.String(args[1], 120)
		if text then
			AnnouncementService.AnnounceGlobal(text, "#FF9ECF")
		end
		return "Announced"
	end,
}

function AdminService.Init()
	-- Arguments arrive as separate values: an array with nil gaps would lose everything
	-- after the first gap when sent over a remote.
	Remote.OnInvoke("Admin", function(player, command, ...)
		if not admins[player] then
			return { Ok = false, Message = "Not an admin" }
		end
		local name = Guard.String(command, 32)
		local handler = name and COMMANDS[name]
		if not handler then
			return { Ok = false, Message = "Unknown command" }
		end
		local list = { ... }
		local message = handler(player, list)
		AnnouncementService.Notify(player, "[Admin] " .. message, "Info")
		return { Ok = true, Message = message }
	end, 10)
end

function AdminService.Start()
	local function onJoin(player: Player)
		task.spawn(function()
			local isAdmin = checkAdmin(player)
			admins[player] = isAdmin
			player:SetAttribute("IsAdmin", isAdmin)
		end)
	end
	Players.PlayerAdded:Connect(onJoin)
	for _, player in Players:GetPlayers() do
		onJoin(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		admins[player] = nil
	end)
end

return AdminService
