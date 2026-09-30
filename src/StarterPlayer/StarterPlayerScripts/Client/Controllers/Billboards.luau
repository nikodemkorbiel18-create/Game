--!strict
-- Client-side billboards so each player sees their own knowledge:
--  * eggs on pedestals / on the ground: rarity, size + kg, mutation, and the character's name
--    only if it's in your Index (otherwise "???")
--  * pen slots: name, $/s or a hatch countdown
--  * other players' carried items: rarity + name/???

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Characters = require(Shared.Config.Characters)
local Rarities = require(Shared.Config.Rarities)
local Sizes = require(Shared.Config.Sizes)
local Mutations = require(Shared.Config.Mutations)
local NumberFormat = require(Shared.Util.NumberFormat)
local TimeFormat = require(Shared.Util.TimeFormat)
local UI = require(script.Parent.Parent.UI.UI)
local Theme = require(script.Parent.Parent.UI.Theme)
local State = require(script.Parent.State)

local Billboards = {}

type Entry = {
	Target: Instance,
	Gui: BillboardGui,
	Name: TextLabel,
	Rarity: TextLabel,
	Info: TextLabel,
	Extra: TextLabel,
	Kind: string,
}

local entries: { [Instance]: Entry } = {}

local function discovered(characterId: string): boolean
	local index = State.Get("Index")
	local entry = if type(index) == "table" then index[characterId] else nil
	return entry ~= nil and entry.Discovered == true
end

local function makeGui(adornee: Instance, height: number, maxDistance: number): (BillboardGui, TextLabel, TextLabel, TextLabel, TextLabel)
	local gui = Instance.new("BillboardGui")
	gui.Name = "InfoBillboard"
	gui.Size = UDim2.fromOffset(200, 92)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	gui.MaxDistance = maxDistance
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.ResetOnSpawn = false
	gui.Adornee = adornee
	local rarity = UI.Text({ Name = "Rarity", Font = Theme.Fonts.Heading, Size = UDim2.new(1, 0, 0, 24), TextMax = 24, Parent = gui })
	local name = UI.Text({ Name = "CharName", Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 22), TextMax = 22, Parent = gui })
	local info = UI.Text({ Name = "Info", Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 46), TextMax = 18, TextColor3 = Color3.fromRGB(230, 230, 240), Parent = gui })
	local extra = UI.Text({ Name = "Extra", Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 66), TextMax = 20, TextColor3 = Theme.Colors.Green, Parent = gui })
	gui.Parent = adornee
	return gui, name, rarity, info, extra
end

local function readAttr(target: Instance, key: string): any
	return target:GetAttribute(key)
end

local function updateEntry(entry: Entry)
	local target = entry.Target
	local characterId = readAttr(target, "CharacterId")
	if type(characterId) ~= "string" then
		entry.Gui.Enabled = false
		return
	end
	local character = Characters.Find(characterId)
	if not character then
		entry.Gui.Enabled = false
		return
	end
	entry.Gui.Enabled = true
	local rarityId = readAttr(target, "Rarity") or character.Rarity
	local rarity = Rarities.ById[rarityId] or Rarities.Get(character.Rarity)
	local sizeTier = readAttr(target, "SizeTier") or 3
	local kg = readAttr(target, "Kg") or 0
	local mutation = Mutations.Get(readAttr(target, "Mutation"))
	local awakened = readAttr(target, "Awakened") == true
	entry.Rarity.Text = string.upper(rarity.DisplayName) .. (if awakened then " ★" else "")
	entry.Rarity.TextColor3 = Theme.RarityText(rarity.Id)
	local known = discovered(characterId)
	local kind = readAttr(target, "Kind")
	local isHatched = kind == "Character"
	entry.Name.Text = if known or isHatched then character.DisplayName else "???"
	entry.Info.Text = string.format("%s · %s%s", Sizes.Get(sizeTier).DisplayName, NumberFormat.Kg(kg), if mutation then " · " .. mutation.DisplayName else "")
	if mutation then
		entry.Info.TextColor3 = Color3.fromHex(mutation.Color)
	else
		entry.Info.TextColor3 = Color3.fromRGB(230, 230, 240)
	end
	if entry.Kind == "Slot" then
		local hatchAt = readAttr(target, "HatchEndsAt")
		if kind == "Egg" and type(hatchAt) == "number" then
			local left = hatchAt - workspace:GetServerTimeNow()
			entry.Extra.Text = if left > 0 then "Hatching in " .. TimeFormat.Short(left) else "Hatching!"
			entry.Extra.TextColor3 = Theme.Colors.Gold
		else
			local income = readAttr(target, "Income")
			entry.Extra.Text = if type(income) == "number" then NumberFormat.PerSecond(income) else ""
			entry.Extra.TextColor3 = Theme.Colors.Green
		end
	elseif entry.Kind == "Dropped" then
		local expires = readAttr(target, "ExpiresAt")
		entry.Extra.Text = if type(expires) == "number" then "Returns in " .. TimeFormat.Short(expires - workspace:GetServerTimeNow()) else ""
		entry.Extra.TextColor3 = Theme.Colors.Red
	else
		entry.Extra.Text = ""
	end
end

local function add(target: Instance, kind: string)
	if entries[target] then
		return
	end
	local adornee: Instance = target
	local height = 4
	local maxDistance = 30
	if target:IsA("Model") then
		local primary = target.PrimaryPart
		if not primary then
			return
		end
		adornee = primary
		local _, size = target:GetBoundingBox()
		height = size.Y + 2.2
	elseif target:IsA("BasePart") then
		height = 7
		maxDistance = 40
	end
	if kind == "Dropped" or target:GetAttribute("Dropped") then
		kind = "Dropped"
	end
	local gui, name, rarity, info, extra = makeGui(adornee, height, maxDistance)
	local entry: Entry = { Target = target, Gui = gui, Name = name, Rarity = rarity, Info = info, Extra = extra, Kind = kind }
	entries[target] = entry
	updateEntry(entry)
	target.AttributeChanged:Connect(function()
		if entries[target] then
			updateEntry(entry)
		end
	end)
end

local function remove(target: Instance)
	local entry = entries[target]
	if entry then
		entry.Gui:Destroy()
		entries[target] = nil
	end
end

local function watch(tag: string, kind: string)
	for _, instance in CollectionService:GetTagged(tag) do
		task.spawn(add, instance, kind)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance)
		task.defer(add, instance, kind)
	end)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(remove)
end

function Billboards.Init() end

function Billboards.Start()
	State.WaitUntilLoaded()
	watch("WorldEgg", "Egg")
	watch("PenItem", "Slot")
	State.OnChange("Index", function()
		for _, entry in entries do
			updateEntry(entry)
		end
	end)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.5 then
			return
		end
		elapsed = 0
		for target, entry in entries do
			if target.Parent == nil then
				remove(target)
			elseif entry.Kind ~= "Egg" then
				updateEntry(entry)
			end
		end
	end)
end

return Billboards
