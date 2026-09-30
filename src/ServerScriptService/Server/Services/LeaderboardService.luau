--!strict
-- Global leaderboards (OrderedDataStore) shown on the boards in Station Plaza:
-- Top Earners, Most Rebirths, Highest $/s. Big numbers are stored log-scaled so they fit
-- in an integer and still sort correctly.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameSettings = require(Shared.Config.GameSettings)
local Tags = require(Shared.Config.Tags)
local NumberFormat = require(Shared.Util.NumberFormat)

local DataService = require(script.Parent.DataService)
local World = require(script.Parent.Parent.Lib.World)

local LeaderboardService = {}

type Board = { Key: string, Title: string, Part: BasePart, Rows: { TextLabel }, Status: TextLabel }

local boards: { Board } = {}
local nameCache: { [number]: string } = {}
local SCALE = 1e13

local function encode(key: string, value: number): number
	if key == "Rebirths" then
		return math.floor(value)
	end
	return math.floor(math.log10(math.max(0, value) + 1) * SCALE)
end

local function decode(key: string, value: number): number
	if key == "Rebirths" then
		return value
	end
	return 10 ^ (value / SCALE) - 1
end

local function statFor(key: string, player: Player): number?
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	if key == "TotalEarned" then
		return data.TotalEarned
	elseif key == "Rebirths" then
		return data.Rebirths
	elseif key == "HighestIncome" then
		return data.Stats.HighestIncome
	end
	return nil
end

local function nameOf(userId: number): string
	local cached = nameCache[userId]
	if cached then
		return cached
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	local result = if ok and name then name else ("Player " .. userId)
	nameCache[userId] = result
	return result
end

local function buildGui(board: Board)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 25
	gui.LightInfluence = 0
	gui.Parent = board.Part
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 0.14)
	title.Font = Enum.Font.Bangers
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 211, 77)
	title.Text = board.Title
	title.Parent = gui
	for index = 1, GameSettings.Leaderboard.Size do
		local row = Instance.new("TextLabel")
		row.BackgroundTransparency = 1
		row.Size = UDim2.fromScale(0.94, 0.075)
		row.Position = UDim2.fromScale(0.03, 0.15 + (index - 1) * 0.078)
		row.Font = Enum.Font.FredokaOne
		row.TextScaled = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = if index <= 3 then Color3.fromRGB(255, 236, 160) else Color3.fromRGB(240, 240, 255)
		row.Text = ""
		row.Parent = gui
		table.insert(board.Rows, row)
	end
	local status = Instance.new("TextLabel")
	status.BackgroundTransparency = 1
	status.Size = UDim2.fromScale(1, 0.06)
	status.Position = UDim2.fromScale(0, 0.93)
	status.Font = Enum.Font.FredokaOne
	status.TextScaled = true
	status.TextColor3 = Color3.fromRGB(170, 164, 196)
	status.Text = "Updating..."
	status.Parent = gui
	board.Status = status
end

local function refresh()
	for _, board in boards do
		local ok, err = pcall(function()
			local store = DataStoreService:GetOrderedDataStore("LB_" .. board.Key)
			for _, player in DataService.LoadedPlayers() do
				local value = statFor(board.Key, player)
				if value and value > 0 then
					store:SetAsync(tostring(player.UserId), encode(board.Key, value))
				end
			end
			local pages = store:GetSortedAsync(false, GameSettings.Leaderboard.Size)
			local entries = pages:GetCurrentPage()
			for index, row in board.Rows do
				local entry = entries[index]
				if entry then
					local userId = tonumber(entry.key) or 0
					local value = decode(board.Key, entry.value)
					local text = if board.Key == "Rebirths" then tostring(math.floor(value)) elseif board.Key == "HighestIncome" then NumberFormat.PerSecond(value) else NumberFormat.Cash(value)
					row.Text = string.format("%d. %s  -  %s", index, nameOf(userId), text)
				else
					row.Text = ""
				end
			end
		end)
		board.Status.Text = if ok then "Updates every " .. GameSettings.Leaderboard.RefreshInterval .. "s" else "Leaderboards need API access (publish the game)"
		if not ok then
			warn("[Leaderboard] " .. tostring(err))
		end
	end
end

function LeaderboardService.Init()
	for _, part in World.TaggedParts(Tags.Leaderboard) do
		local key = part:GetAttribute("Board")
		local title = part:GetAttribute("Title")
		if type(key) == "string" then
			local board: Board = { Key = key, Title = if type(title) == "string" then title else key, Part = part, Rows = {}, Status = Instance.new("TextLabel") }
			buildGui(board)
			table.insert(boards, board)
		end
	end
end

function LeaderboardService.Start()
	if #boards == 0 then
		return
	end
	task.spawn(function()
		task.wait(10)
		while true do
			refresh()
			task.wait(GameSettings.Leaderboard.RefreshInterval)
		end
	end)
end

return LeaderboardService
