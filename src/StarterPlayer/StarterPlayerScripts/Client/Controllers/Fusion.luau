--!strict
-- Fusion Pod window: Awaken (3 of the same chibi -> 1 Awakened), recipe fusions (shown as
-- silhouettes until discovered) and the pod queue with claim buttons.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Characters = require(Shared.Config.Characters)
local Fusion = require(Shared.Config.Fusion)
local Mutations = require(Shared.Config.Mutations)
local NumberFormat = require(Shared.Util.NumberFormat)
local TimeFormat = require(Shared.Util.TimeFormat)
local Net = require(Shared.Net)
local UI = require(script.Parent.Parent.UI.UI)
local Theme = require(script.Parent.Parent.UI.Theme)
local ItemCard = require(script.Parent.Parent.UI.ItemCard)
local State = require(script.Parent.State)

local FusionController = {}

local pages: { [string]: Frame } = {}
local selectTab: (string) -> () = function() end
local currentTab = "Awaken"

local function request(action: string, a: any?, b: any?)
	pcall(function()
		Net.Function("Fusion"):InvokeServer(action, a, b)
	end)
end

local function owned(): { any }
	local list = {}
	for _, item in State.Get("Pen") or {} do
		if item.Kind == "Character" and not item.Protected then
			table.insert(list, item)
		end
	end
	for _, item in State.Get("Inventory") or {} do
		if item.Kind == "Character" and not item.Protected then
			table.insert(list, item)
		end
	end
	return list
end

local function bySize(a: any, b: any): boolean
	if a.SizeTier ~= b.SizeTier then
		return a.SizeTier > b.SizeTier
	end
	return a.Kg > b.Kg
end

local function scroller(page: Frame, cell: UDim2): ScrollingFrame
	for _, child in page:GetChildren() do
		child:Destroy()
	end
	return UI.Scroller({ Size = UDim2.fromScale(1, 1), Grid = { Cell = cell, Gap = UDim2.fromOffset(8, 8) }, Padding = 6, Parent = page })
end

local function renderAwaken()
	local list = scroller(pages.Awaken, UDim2.fromOffset(170, 240))
	local groups: { [string]: { any } } = {}
	for _, item in owned() do
		if not item.Awakened then
			groups[item.CharacterId] = groups[item.CharacterId] or {}
			table.insert(groups[item.CharacterId], item)
		end
	end
	local any = false
	for characterId, items in groups do
		if #items >= Fusion.Copies then
			any = true
			table.sort(items, bySize)
			local picks = { items[1], items[2], items[3] }
			local mutationsDiffer = picks[1].Mutation ~= picks[2].Mutation or picks[1].Mutation ~= picks[3].Mutation
			ItemCard.Build({ CharacterId = characterId, Kind = "Character", SizeTier = picks[1].SizeTier, Kg = picks[1].Kg, Awakened = true, Mutation = if mutationsDiffer then nil else picks[1].Mutation }, {
				Parent = list,
				Subtitle = string.format("You own %d", #items),
				Buttons = {
					{
						Text = "AWAKEN",
						Color = Theme.Colors.Purple,
						OnActivated = function()
							local uids = { picks[1].Uid, picks[2].Uid, picks[3].Uid }
							if mutationsDiffer then
								local names = {}
								for _, pick in picks do
									table.insert(names, Mutations.DisplayName(pick.Mutation))
								end
								UI.Confirm(
									"Mutations differ",
									"These three have different mutations (" .. table.concat(names, ", ") .. "). The Awakened chibi only has a 10% chance to keep the best one.",
									"Fuse anyway",
									function(confirmed)
										if confirmed then
											request("Awaken", uids)
										end
										UI.Open("Fusion")
									end
								)
							else
								request("Awaken", uids)
							end
						end,
					},
				},
			})
		end
	end
	if not any then
		UI.Text({ Text = "Collect 3 copies of the same chibi to awaken it: one rarity higher and x4 income!", Size = UDim2.new(1, -20, 0, 60), TextWrapped = true, TextMax = 20, Parent = list })
	end
end

local function renderRecipes()
	local list = scroller(pages.Recipes, UDim2.fromOffset(290, 320))
	local mine = owned()
	for order, recipe in Fusion.Recipes do
		local card = UI.new("Frame", { Size = UDim2.fromOffset(290, 320), BackgroundColor3 = Theme.Colors.PanelLight, LayoutOrder = order, Corner = true, Stroke = { Thickness = 3, Border = true }, Parent = list })
		local resultKnown = State.IsDiscovered(recipe.Result)
		UI.Text({ Text = string.upper(recipe.DisplayName), Font = Theme.Fonts.Heading, Size = UDim2.new(1, -12, 0, 30), Position = UDim2.fromOffset(6, 6), TextColor3 = Theme.Colors.Gold, TextMax = 26, Parent = card })
		UI.Viewport(ItemCard.Preview({ CharacterId = recipe.Result, Kind = "Character" }, not resultKnown), { Size = UDim2.new(1, -12, 0, 120), Position = UDim2.fromOffset(6, 38), Parent = card })
		local inputs = {}
		local picks = {}
		for _, id in recipe.Inputs do
			table.insert(inputs, if State.IsDiscovered(id) then Characters.Get(id).DisplayName else "???")
			local best = nil
			for _, item in mine do
				if item.CharacterId == id and not table.find(picks, item) and (best == nil or bySize(item, best)) then
					best = item
				end
			end
			if best then
				table.insert(picks, best)
			end
		end
		UI.Text({ Text = table.concat(inputs, " + "), Size = UDim2.new(1, -12, 0, 40), Position = UDim2.fromOffset(6, 162), TextWrapped = true, TextMax = 18, Parent = card })
		UI.Text({ Text = "Hatches into: " .. (if resultKnown then Characters.Get(recipe.Result).DisplayName else "???") .. " (" .. Characters.Get(recipe.Result).Rarity .. ")", Size = UDim2.new(1, -12, 0, 22), Position = UDim2.fromOffset(6, 204), TextColor3 = Theme.Colors.Pink, TextMax = 16, Parent = card })
		UI.Text({ Text = "Cost " .. NumberFormat.Cash(recipe.Price), Size = UDim2.new(1, -12, 0, 22), Position = UDim2.fromOffset(6, 228), TextColor3 = Theme.Colors.Green, TextMax = 18, Parent = card })
		local ready = #picks == #recipe.Inputs
		UI.Button({
			Text = if ready then "FUSE" else "MISSING INGREDIENTS",
			Size = UDim2.new(1, -12, 0, 44),
			Position = UDim2.new(0, 6, 1, -52),
			BackgroundColor3 = if ready then Theme.Colors.Purple else Theme.Colors.Muted,
			TextMax = 20,
			OnActivated = function()
				if ready then
					local uids = {}
					for _, pick in picks do
						table.insert(uids, pick.Uid)
					end
					request("Recipe", recipe.Id, uids)
				end
			end,
			Parent = card,
		})
	end
end

local function renderPod()
	local list = scroller(pages.Pod, UDim2.fromOffset(170, 240))
	local jobs = State.Get("Fusion") or {}
	for index, job in jobs do
		local remaining = job.EndsAt - workspace:GetServerTimeNow()
		ItemCard.Build(job.Result, {
			Parent = list,
			LayoutOrder = index,
			Subtitle = if remaining > 0 then "Ready in " .. TimeFormat.Short(remaining) else "READY!",
			Buttons = { {
				Text = if remaining > 0 then "FUSING..." else "CLAIM",
				Color = if remaining > 0 then Theme.Colors.Muted else Theme.Colors.Gold,
				OnActivated = function()
					if remaining <= 0 then
						request("Claim", index)
					end
				end,
			} },
		})
	end
	if #jobs == 0 then
		UI.Text({ Text = "The pod is empty.", Size = UDim2.new(1, -20, 0, 40), TextMax = 20, Parent = list })
	end
end

local function render(tab: string)
	currentTab = tab
	if tab == "Awaken" then
		renderAwaken()
	elseif tab == "Recipes" then
		renderRecipes()
	else
		renderPod()
	end
end

function FusionController.Init()
	local window = UI.Window("Fusion", "FUSION POD", UDim2.fromOffset(960, 620), Theme.Colors.Purple)
	pages, selectTab = UI.Tabs(window.Content, {
		{ Key = "Awaken", Text = "AWAKEN", Color = Theme.Colors.Purple },
		{ Key = "Recipes", Text = "RECIPES", Color = Theme.Colors.Pink },
		{ Key = "Pod", Text = "POD", Color = Theme.Colors.Gold },
	}, render)
	window.OnOpen = function()
		render(currentTab)
	end
end

function FusionController.Start()
	local function add(part: Instance)
		if not part:IsA("BasePart") or part:FindFirstChild("KioskPrompt") then
			return
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "KioskPrompt"
		prompt.ActionText = "Fusion Pod"
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Triggered:Connect(function()
			UI.Open("Fusion")
			selectTab(currentTab)
		end)
		prompt.Parent = part
	end
	for _, part in CollectionService:GetTagged("FusionPod") do
		add(part)
	end
	CollectionService:GetInstanceAddedSignal("FusionPod"):Connect(add)
	State.OnChange("Fusion", function()
		if UI.IsOpen("Fusion") then
			render(currentTab)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			if UI.IsOpen("Fusion") and currentTab == "Pod" then
				renderPod()
			end
		end
	end)
end

return FusionController
