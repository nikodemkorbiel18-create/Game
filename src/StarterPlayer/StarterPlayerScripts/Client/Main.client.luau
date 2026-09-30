--!strict
-- Client entry point: loads controllers in order, then starts them.

local ORDER = {
	"State",
	"Sound",
	"Notifications",
	"Effects",
	"WorldLabels",
	"Billboards",
	"Prompts",
	"HUD",
	"Carry",
	"HatchReveal",
	"Input",
	"Theft",
	"Inventory",
	"Shop",
	"Index",
	"Rebirth",
	"Fusion",
	"Sell",
	"Codes",
	"DailyRewards",
	"Settings",
	"Incubator",
	"Gauntlet",
	"Ambience",
	"Tutorial",
	"Admin",
}

type Controller = { Init: (() -> ())?, Start: (() -> ())? }

local folder = script.Parent:WaitForChild("Controllers")
local controllers: { { Name: string, Module: Controller } } = {}

for _, name in ORDER do
	local module = folder:FindFirstChild(name)
	if module and module:IsA("ModuleScript") then
		local ok, result = pcall(require, module)
		if ok then
			table.insert(controllers, { Name = name, Module = result :: Controller })
		else
			warn(string.format("[Client] Failed to load %s: %s", name, tostring(result)))
		end
	end
end

for _, entry in controllers do
	local init = entry.Module.Init
	if init then
		local ok, err = pcall(function(): nil
			init()
			return nil
		end)
		if not ok then
			warn(string.format("[Client] %s.Init failed: %s", entry.Name, tostring(err)))
		end
	end
end

for _, entry in controllers do
	local start = entry.Module.Start
	if start then
		task.spawn(function()
			local ok, err = pcall(function(): nil
				start()
				return nil
			end)
			if not ok then
				warn(string.format("[Client] %s.Start failed: %s", entry.Name, tostring(err)))
			end
		end)
	end
end
