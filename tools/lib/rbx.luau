--!nocheck
-- Loads the Rojo-built place (build/code.rbxl) into Lune and runs ModuleScripts with an
-- instance-based `require`, so pure game modules (config, formulas, simulator) can be
-- tested and reused by the build tools without Roblox Studio.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local M = {}

local function build()
	local result = process.exec("rojo", { "build", "default.project.json", "-o", "build/code.rbxl" })
	if not result.ok then
		error("rojo build failed:\n" .. result.stderr)
	end
end

-- Deterministic stand-in for Roblox's Random (xorshift-style on doubles)
local RandomShim = {}
RandomShim.__index = RandomShim
function RandomShim.new(seed)
	local s = math.floor(math.abs(seed or os.clock() * 1e6)) % 2147483647
	if s == 0 then
		s = 1
	end
	return setmetatable({ _state = s }, RandomShim)
end
function RandomShim:_next()
	self._state = (self._state * 48271) % 2147483647
	return self._state / 2147483647
end
function RandomShim:NextNumber(min, max)
	local r = self:_next()
	if min and max then
		return min + (max - min) * r
	end
	return r
end
function RandomShim:NextInteger(min, max)
	return math.floor(min + (max - min + 1) * self:_next())
end

M.Random = RandomShim

function M.load(opts)
	opts = opts or {}
	if not opts.skipBuild then
		fs.writeDir("build")
		build()
	end
	local game = roblox.deserializePlace(fs.readFile("build/code.rbxl"))
	local cache = {}
	local loading = {}
	local baseEnv = {
		game = game,
		Random = RandomShim,
		Vector3 = roblox.Vector3,
		Vector2 = roblox.Vector2,
		CFrame = roblox.CFrame,
		Color3 = roblox.Color3,
		Enum = roblox.Enum,
		Instance = roblox.Instance,
		UDim2 = roblox.UDim2,
		NumberSequence = roblox.NumberSequence,
		ColorSequence = roblox.ColorSequence,
	}
	local rbxRequire
	rbxRequire = function(module)
		if type(module) == "string" then
			return require(module)
		end
		if cache[module] ~= nil then
			return cache[module]
		end
		assert(not loading[module], "cyclic require: " .. module:GetFullName())
		loading[module] = true
		local env = table.clone(baseEnv)
		env.script = module
		env.require = rbxRequire
		local chunk = luau.load(module.Source, { debugName = module:GetFullName(), environment = env })
		local value = chunk()
		cache[module] = value
		loading[module] = nil
		return value
	end
	local function find(path)
		local node = game
		for segment in string.gmatch(path, "[^/]+") do
			local nextNode = node:FindFirstChild(segment)
			if not nextNode then
				if node == game then
					nextNode = game:GetService(segment)
				end
			end
			assert(nextNode, "path not found: " .. path)
			node = nextNode
		end
		return node
	end
	return {
		game = game,
		find = find,
		require = function(path)
			return rbxRequire(find(path))
		end,
	}
end

return M
