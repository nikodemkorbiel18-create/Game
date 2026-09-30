--!strict
-- Every RemoteEvent / RemoteFunction in the game. The server creates them under
-- ReplicatedStorage.Remotes; clients wait for them.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EVENTS = {
	-- server -> client
	"StateChanged",
	"Notify",
	"Announce",
	"HatchReveal",
	"TheftAlert",
	"Knockback",
	"OfflineEarnings",
	"Effect",
	"Tutorial",
	-- client -> server
	"Slap",
	"PlaceTrap",
	"UseSmoke",
	"StoreCarried",
	"SaveSettings",
	"TutorialAction",
	"ClientLog",
}

local FUNCTIONS = {
	"GetState",
	"Shop",
	"Inventory",
	"Sell",
	"Fusion",
	"Incubator",
	"Rebirth",
	"Index",
	"RedeemCode",
	"LoginReward",
	"Admin",
}

local Net = {
	EventNames = EVENTS,
	FunctionNames = FUNCTIONS,
}

local folder: Folder? = nil

local function getFolder(): Folder
	local cached = folder
	if cached then
		return cached
	end
	local result: Folder
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild("Remotes")
		if existing and existing:IsA("Folder") then
			result = existing
		else
			result = Instance.new("Folder")
			result.Name = "Remotes"
			result.Parent = ReplicatedStorage
		end
	else
		result = ReplicatedStorage:WaitForChild("Remotes") :: Folder
	end
	folder = result
	return result
end

-- Server only: create every remote up front.
function Net.Setup()
	assert(RunService:IsServer(), "Net.Setup is server-only")
	local root = getFolder()
	for _, name in EVENTS do
		if not root:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = root
		end
	end
	for _, name in FUNCTIONS do
		if not root:FindFirstChild(name) then
			local remote = Instance.new("RemoteFunction")
			remote.Name = name
			remote.Parent = root
		end
	end
end

function Net.Event(name: string): RemoteEvent
	assert(table.find(EVENTS, name), "Unknown remote event " .. name)
	return getFolder():WaitForChild(name) :: RemoteEvent
end

function Net.Function(name: string): RemoteFunction
	assert(table.find(FUNCTIONS, name), "Unknown remote function " .. name)
	return getFolder():WaitForChild(name) :: RemoteFunction
end

return Net
