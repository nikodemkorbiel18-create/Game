--!strict
-- Server entry point: creates remotes, then initializes and starts every service in
-- dependency order. Init() wires hooks and remotes; Start() connects events and loops.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
Net.Setup()

local ORDER = {
	"DataService",
	"AnnouncementService",
	"PassService",
	"PlotService",
	"EventService",
	"SpeedService",
	"IncomeService",
	"IndexService",
	"HatchService",
	"EggSpawnService",
	"CarryService",
	"TrailService",
	"GuardianService",
	"ItemService",
	"StealService",
	"AntiExploitService",
	"InventoryService",
	"ShopService",
	"FusionService",
	"IncubatorService",
	"BossService",
	"RebirthService",
	"CodesService",
	"LoginRewardService",
	"LeaderboardService",
	"TutorialService",
	"MonetizationService",
	"AdminService",
	"AmbienceService",
}

type Service = { Init: (() -> ())?, Start: (() -> ())? }

local folder = script.Parent.Services
local services: { { Name: string, Module: Service } } = {}

for _, name in ORDER do
	local module = folder:FindFirstChild(name)
	if module and module:IsA("ModuleScript") then
		local ok, result = pcall(require, module)
		if ok then
			table.insert(services, { Name = name, Module = result :: Service })
		else
			warn(string.format("[Main] Failed to load %s: %s", name, tostring(result)))
		end
	end
end

for _, entry in services do
	local init = entry.Module.Init
	if init then
		local ok, err = pcall(function(): nil
			init()
			return nil
		end)
		if not ok then
			warn(string.format("[Main] %s.Init failed: %s", entry.Name, tostring(err)))
		end
	end
end

for _, entry in services do
	local start = entry.Module.Start
	if start then
		local ok, err = pcall(function(): nil
			start()
			return nil
		end)
		if not ok then
			warn(string.format("[Main] %s.Start failed: %s", entry.Name, tostring(err)))
		end
	end
end

workspace:SetAttribute("ServerReady", true)
print(string.format("[Steal a Chibi] %d services running", #services))
