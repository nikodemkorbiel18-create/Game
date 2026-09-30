--!strict
-- Player-vs-player: the Harisen slap and base raids. (Snatching a carried item lives in
-- CarryService.) Every action is validated on the server: cooldowns, ranges, facing,
-- hold time, new-player protection, Barrier Lock and "your own plot is your safe zone".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameSettings = require(Shared.Config.GameSettings)
local Characters = require(Shared.Config.Characters)

local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local SpeedService = require(script.Parent.SpeedService)
local CarryService = require(script.Parent.CarryService)
local AnnouncementService = require(script.Parent.AnnouncementService)
local Remote = require(script.Parent.Parent.Lib.Remote)
local World = require(script.Parent.Parent.Lib.World)

local StealService = {}

local lastSlap: { [Player]: number } = {}

local function slap(player: Player)
	local now = os.clock()
	if lastSlap[player] and now - lastSlap[player] < GameSettings.Slap.Cooldown - 0.15 then
		return
	end
	if SpeedService.IsStunned(player) or CarryService.IsCarrying(player) then
		return
	end
	local root = World.Root(player)
	if not root then
		return
	end
	lastSlap[player] = now
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	local best: Player? = nil
	local bestDistance = GameSettings.Slap.Range
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local otherRoot = World.Root(other)
			if otherRoot and World.Humanoid(other) then
				local offset = (otherRoot.Position - root.Position)
				local flat = offset * Vector3.new(1, 0, 1)
				local distance = offset.Magnitude
				if distance <= bestDistance and flat.Magnitude > 0.01 and look.Magnitude > 0.01 and flat.Unit:Dot(look.Unit) >= GameSettings.Slap.ConeDot then
					best, bestDistance = other, distance
				end
			end
		end
	end
	Remote.FireAll("Effect", { Type = "Slap", UserId = player.UserId })
	if not best then
		return
	end
	local target = best :: Player
	if PlotService.IsInOwnPlot(target) then
		AnnouncementService.Error(player, "They're safe inside their own base!")
		return
	end
	local targetRoot = World.Root(target) :: BasePart
	if CarryService.IsCarrying(target) then
		CarryService.Drop(target, "Slap")
		AnnouncementService.Notify(target, player.DisplayName .. " slapped the chibi out of your hands!", "Theft")
	end
	SpeedService.Stun(target, GameSettings.Slap.Stun)
	local direction = (targetRoot.Position - root.Position) * Vector3.new(1, 0, 1)
	Remote.Fire("Knockback", target, { Direction = if direction.Magnitude > 0.01 then direction.Unit else look, Force = 35, Duration = GameSettings.Slap.Stun })
	Remote.FireAll("Effect", { Type = "Hit", Position = targetRoot.Position })
end

-- A non-owner held a pen slot prompt in someone else's base
local function onSlotTriggered(thief: Player, plot: PlotService.Plot, slotIndex: number, held: number)
	local owner = plot.Owner
	if not owner or owner == thief then
		return
	end
	if held + 0.2 < GameSettings.RaidHoldTime then
		return
	end
	if CarryService.IsCarrying(thief) then
		AnnouncementService.Error(thief, "Your hands are full!")
		return
	end
	if SpeedService.IsStunned(thief) then
		return
	end
	if PlotService.IsProtected(owner) then
		AnnouncementService.Error(thief, "This base has new-player protection.")
		return
	end
	if PlotService.BarrierActive(plot) then
		AnnouncementService.Error(thief, "The Barrier Lock is up!")
		return
	end
	local position = World.Position(thief)
	if not position or not World.InsideFootprint(position, plot.Floor, 60, 2) then
		return
	end
	local ownerData = DataService.Get(owner)
	local item = ownerData and ownerData.Pen[tostring(slotIndex)]
	if not item then
		return
	end
	local name = Characters.Get(item.CharacterId).DisplayName
	if CarryService.TakeFromPen(owner, slotIndex, thief) then
		Remote.Fire("TheftAlert", owner, {
			ThiefUserId = thief.UserId,
			ThiefName = thief.DisplayName,
			CharacterId = item.CharacterId,
			Text = string.format("%s IS STEALING YOUR %s!", string.upper(thief.DisplayName), string.upper(name)),
		})
		AnnouncementService.Notify(thief, "Got it! Get back to your base before they catch you!", "Warning")
	end
end

function StealService.Init()
	Remote.OnEvent("Slap", slap, 2)
end

function StealService.Start()
	PlotService.SlotTriggered:Connect(onSlotTriggered)
	Players.PlayerRemoving:Connect(function(player)
		lastSlap[player] = nil
	end)
end

return StealService
