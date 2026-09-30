--!strict
-- The Heavenly Gatekeeper gauntlet guarding Celestial Sakura Heights (zone 11).
--   Phase 1: shockwave rings expand from the stomp mark - jump them
--   Phase 2: golden petals fall on telegraphed target zones - step out of the circles
--   Phase 3: a sweeping staff circles the terrace low to the ground - jump over it
-- Reach the gate with fewer than 3 hits to clear it (saved; resets on rebirth).
-- Hazards are deterministic (Util/Gauntlet) so clients draw exactly what the server scores.
-- Players who haven't cleared it are sent back if they get past the gate.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Endgame = require(Shared.Config.Endgame)
local Tags = require(Shared.Config.Tags)
local GauntletMath = require(Shared.Util.Gauntlet)

local DataService = require(script.Parent.DataService)
local SpeedService = require(script.Parent.SpeedService)
local AnnouncementService = require(script.Parent.AnnouncementService)
local Remote = require(script.Parent.Parent.Lib.Remote)
local World = require(script.Parent.Parent.Lib.World)

local BossService = {}

type Area = { Part: BasePart, Phase: number, Origin: Vector3, FloorY: number }
type Run = { Hits: number, LastHit: number }
type Petal = { Position: Vector3, ImpactAt: number, Resolved: boolean }

local areas: { [number]: Area } = {}
local startPart: BasePart? = nil
local finishPart: BasePart? = nil
local zone11: BasePart? = nil
local gate: BasePart? = nil
local runs: { [Player]: Run } = {}
local petals: { Petal } = {}
local nextPetalAt = 0
local rng = Random.new()

local boss = Endgame.Boss

function BossService.IsCleared(player: Player): boolean
	local data = DataService.Get(player)
	return data ~= nil and data.BossCleared
end

local function publish(player: Player)
	local data = DataService.Get(player)
	player:SetAttribute("BossCleared", data ~= nil and data.BossCleared)
end

local function feetHeight(root: BasePart, floorY: number): number
	return (root.Position.Y - 3) - floorY
end

local function hit(player: Player, run: Run, root: BasePart)
	local now = os.clock()
	if now - run.LastHit < boss.HitInvulnerability then
		return
	end
	run.LastHit = now
	run.Hits += 1
	player:SetAttribute("GauntletHits", run.Hits)
	Remote.FireAll("Effect", { Type = "Hit", Position = root.Position })
	if run.Hits > boss.MaxHits then
		runs[player] = nil
		player:SetAttribute("InGauntlet", false)
		player:SetAttribute("GauntletHits", 0)
		AnnouncementService.Notify(player, "The Gatekeeper knocked you back! Try again.", "Error")
		local start = startPart
		if start then
			World.Teleport(player, start.CFrame * CFrame.new(0, 0, 12) + Vector3.new(0, 3, 0))
		end
	else
		SpeedService.ApplySlow(player, "GauntletHit", 0.6, 0.6)
		AnnouncementService.Notify(player, string.format("Hit! %d / %d", run.Hits, boss.MaxHits + 1), "Warning", 1.5)
	end
end

local function spawnPetals(now: number)
	local area = areas[2]
	if not area or now < nextPetalAt then
		return
	end
	nextPetalAt = now + boss.Petals.Interval
	local half = area.Part.Size / 2
	local positions = {}
	for _ = 1, boss.Petals.Count do
		local x = rng:NextNumber(-half.X + 6, half.X - 6)
		local z = rng:NextNumber(-half.Z + 6, half.Z - 6)
		local position = Vector3.new(area.Part.Position.X + x, area.FloorY, area.Part.Position.Z + z)
		table.insert(petals, { Position = position, ImpactAt = now + boss.Petals.Warning, Resolved = false })
		table.insert(positions, position)
	end
	Remote.FireAll("Effect", { Type = "Petals", Positions = positions, ImpactAt = now + boss.Petals.Warning, Radius = boss.Petals.Radius })
end

local function inArea(area: Area?, position: Vector3): boolean
	return area ~= nil and World.InsideBox(position, area.Part, 2)
end

local function tick()
	local now = workspace:GetServerTimeNow()
	spawnPetals(now)
	local radii = GauntletMath.ShockwaveRadii(now)
	for _, player in Players:GetPlayers() do
		local root = World.Root(player)
		if not root then
			continue
		end
		local position = root.Position
		local cleared = BossService.IsCleared(player)
		-- hard gate
		if not cleared and zone11 and World.InsideBox(position, zone11 :: BasePart, 4) then
			local start = startPart
			if start then
				World.Teleport(player, start.CFrame * CFrame.new(0, 0, 12) + Vector3.new(0, 3, 0))
				AnnouncementService.Notify(player, "The golden gate is sealed. Clear the Gatekeeper's gauntlet first!", "Error")
			end
			continue
		end
		local run = runs[player]
		if not run and not cleared and startPart and World.InsideBox(position, startPart :: BasePart, 2) then
			run = { Hits = 0, LastHit = 0 }
			runs[player] = run
			player:SetAttribute("InGauntlet", true)
			player:SetAttribute("GauntletHits", 0)
			AnnouncementService.Notify(player, "The Heavenly Gatekeeper is watching... reach the gate with fewer than 3 hits!", "Warning", 4)
		end
		if not run then
			continue
		end
		local area1, area2, area3 = areas[1], areas[2], areas[3]
		if inArea(area1, position) and area1 then
			local distance = World.FlatDistance(position, area1.Origin)
			if feetHeight(root, area1.FloorY) < boss.Shockwave.JumpClearance then
				for _, radius in radii do
					if math.abs(distance - radius) < boss.Shockwave.Thickness / 2 then
						hit(player, run, root)
						break
					end
				end
			end
		elseif inArea(area2, position) and area2 then
			for _, petal in petals do
				if not petal.Resolved and now >= petal.ImpactAt and now - petal.ImpactAt < 0.25 then
					if World.FlatDistance(position, petal.Position) < boss.Petals.Radius and feetHeight(root, area2.FloorY) < 4 then
						hit(player, run, root)
					end
				end
			end
		elseif inArea(area3, position) and area3 then
			local distance = GauntletMath.StaffDistance(now, area3.Origin, position)
			if distance < boss.Staff.Thickness / 2 + 1 and feetHeight(root, area3.FloorY) < boss.Staff.Height then
				hit(player, run, root)
			end
		end
		if runs[player] and finishPart and World.InsideBox(position, finishPart :: BasePart, 2) then
			runs[player] = nil
			player:SetAttribute("InGauntlet", false)
			local data = DataService.Get(player)
			if data then
				data.BossCleared = true
				DataService.Changed(player, "BossCleared")
				publish(player)
				AnnouncementService.Announce(string.upper(player.DisplayName) .. " CLEARED THE HEAVENLY GATEKEEPER!", "#FFD86B")
			end
		end
	end
	for index = #petals, 1, -1 do
		if now - petals[index].ImpactAt > 0.3 then
			table.remove(petals, index)
		end
	end
end

function BossService.ResetClear(player: Player)
	local data = DataService.Get(player)
	if data then
		data.BossCleared = false
		DataService.Changed(player, "BossCleared")
		publish(player)
	end
end

function BossService.Init()
	for _, part in World.TaggedParts(Tags.GauntletArea) do
		local phase = part:GetAttribute("Phase")
		if type(phase) == "number" then
			areas[phase] = {
				Part = part,
				Phase = phase,
				Origin = Vector3.new(part:GetAttribute("OriginX") :: number, part:GetAttribute("OriginY") :: number, part:GetAttribute("OriginZ") :: number),
				FloorY = part:GetAttribute("FloorY") :: number,
			}
		end
	end
	startPart = World.TaggedParts(Tags.GauntletStart)[1]
	finishPart = World.TaggedParts(Tags.GauntletFinish)[1]
	gate = World.TaggedParts(Tags.HeavenGate)[1]
	for _, part in World.TaggedParts(Tags.Zone) do
		if part:GetAttribute("ZoneId") == 11 then
			zone11 = part
		end
	end
end

function BossService.Start()
	DataService.Loaded:Connect(function(player)
		publish(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		runs[player] = nil
	end)
	if not startPart then
		return
	end
	local _ = gate
	task.spawn(function()
		while true do
			task.wait(0.05)
			local ok, err = pcall(function(): nil
				tick()
				return nil
			end)
			if not ok then
				warn("[BossService] " .. tostring(err))
			end
		end
	end)
end

return BossService
