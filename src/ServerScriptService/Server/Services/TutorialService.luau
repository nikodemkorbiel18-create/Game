--!strict
-- New-player tutorial with a guiding arrow:
--   1 grab an egg in Sakura Academy -> 2 bring it home -> 3 watch it hatch ->
--   4 collect your cash (+ $1,000 welcome gift) -> 5 unlock the treadmill -> 6 train.
-- Progress is driven by real server events, so it can't get out of sync. Skippable
-- (skipping still grants the welcome gift so the treadmill is affordable).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameSettings = require(Shared.Config.GameSettings)
local Tags = require(Shared.Config.Tags)
local NumberFormat = require(Shared.Util.NumberFormat)

local DataService = require(script.Parent.DataService)
local PassService = require(script.Parent.PassService)
local PlotService = require(script.Parent.PlotService)
local SpeedService = require(script.Parent.SpeedService)
local IncomeService = require(script.Parent.IncomeService)
local HatchService = require(script.Parent.HatchService)
local CarryService = require(script.Parent.CarryService)
local AnnouncementService = require(script.Parent.AnnouncementService)
local Remote = require(script.Parent.Parent.Lib.Remote)

local TutorialService = {}

local STEPS = {
	"Run to SAKURA ACADEMY and grab an egg from the nest! (hold the button)",
	"Now bring it home! Walk into your base before the Hall Monitor catches you.",
	"Your egg is incubating in your pen. Watch it hatch!",
	"Your chibi earns cash every second. Step on the COLLECT plate to bank it!",
	"Unlock your treadmill to start training your Speed.",
	"Stand on the treadmill to gain Speed. More Speed = faster runs to richer zones!",
}

local treadmillTime: { [Player]: number } = {}

local function target(player: Player, step: number): Vector3?
	local plot = PlotService.Get(player)
	if step == 1 then
		for _, part in CollectionService:GetTagged(Tags.Nest) do
			if part:IsA("BasePart") and part:GetAttribute("ZoneId") == 1 then
				return part.Position
			end
		end
	elseif step == 2 then
		return if plot then plot.Floor.Position else nil
	elseif step == 3 then
		local data = DataService.Get(player)
		if plot and data then
			for key in data.Pen do
				local slot = plot.Slots[tonumber(key) :: number]
				if slot then
					return slot.Position
				end
			end
		end
		return if plot then plot.Floor.Position else nil
	elseif step == 4 then
		return if plot and plot.CollectPlate then plot.CollectPlate.Position else nil
	elseif step == 5 or step == 6 then
		return if plot and plot.TreadmillBelt then plot.TreadmillBelt.Position else nil
	end
	return nil
end

local function send(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local tutorial = data.Tutorial
	if tutorial.Done then
		Remote.Fire("Tutorial", player, { Done = true })
		return
	end
	Remote.Fire("Tutorial", player, {
		Step = tutorial.Step,
		Total = #STEPS,
		Text = STEPS[tutorial.Step],
		Target = target(player, tutorial.Step),
	})
end

local function giveGift(player: Player)
	local data = DataService.Get(player)
	if data and not data.Tutorial.GiftGiven then
		data.Tutorial.GiftGiven = true
		IncomeService.AddCash(player, GameSettings.WelcomeGiftCash, false)
		AnnouncementService.Notify(player, "Welcome gift: " .. NumberFormat.Cash(GameSettings.WelcomeGiftCash) .. "! Use it to unlock your treadmill.", "Reward", 5)
	end
end

local function advance(player: Player, fromStep: number)
	local data = DataService.Get(player)
	if not data or data.Tutorial.Done or data.Tutorial.Step ~= fromStep then
		return
	end
	if fromStep == 4 then
		giveGift(player)
	end
	data.Tutorial.Step += 1
	if data.Tutorial.Step > #STEPS then
		data.Tutorial.Done = true
		AnnouncementService.Notify(player, "Tutorial complete! Train, steal, hatch - and watch your base.", "Success", 5)
	end
	DataService.Changed(player, "Tutorial")
	send(player)
	-- skip steps that are already satisfied
	if not data.Tutorial.Done then
		local step = data.Tutorial.Step
		if step == 3 then
			local hasCharacter = false
			for _, item in data.Pen do
				if item.Kind == "Character" then
					hasCharacter = true
				end
			end
			if hasCharacter then
				advance(player, 3)
			end
		elseif step == 4 and PassService.Owns(player, "AutoCollect") then
			advance(player, 4)
		elseif step == 5 and data.TreadmillTier >= 1 then
			advance(player, 5)
		end
	end
end

function TutorialService.Init()
	Remote.OnEvent("TutorialAction", function(player, action)
		local data = DataService.Get(player)
		if not data then
			return
		end
		if action == "Skip" and not data.Tutorial.Done then
			data.Tutorial.Done = true
			giveGift(player)
			DataService.Changed(player, "Tutorial")
			send(player)
		elseif action == "Sync" then
			send(player)
		end
	end, 4)
end

function TutorialService.Start()
	DataService.Loaded:Connect(function(player, data)
		if data.Tutorial.Done then
			return
		end
		-- returning players who already progressed skip ahead
		if data.Stats.EggsGrabbed > 0 and data.Tutorial.Step == 1 then
			data.Tutorial.Step = 3
		end
		task.delay(4, function()
			if player.Parent then
				send(player)
			end
		end)
	end)
	CarryService.Started:Connect(function(player, _item, info)
		if info.Origin == "Wild" then
			advance(player, 1)
		end
	end)
	CarryService.Delivered:Connect(function(player)
		advance(player, 2)
	end)
	HatchService.Hatched:Connect(function(player)
		advance(player, 3)
	end)
	IncomeService.Collected:Connect(function(player)
		advance(player, 4)
	end)
	SpeedService.TreadmillChanged:Connect(function(player)
		local data = DataService.Get(player)
		if data and data.TreadmillTier >= 1 then
			advance(player, 5)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in DataService.LoadedPlayers() do
				local data = DataService.Get(player)
				if data and not data.Tutorial.Done and data.Tutorial.Step == 6 then
					if SpeedService.IsOnTreadmill(player) then
						treadmillTime[player] = (treadmillTime[player] or 0) + 1
						if treadmillTime[player] >= 5 then
							treadmillTime[player] = nil
							advance(player, 6)
						end
					end
				end
			end
		end
	end)
end

return TutorialService
