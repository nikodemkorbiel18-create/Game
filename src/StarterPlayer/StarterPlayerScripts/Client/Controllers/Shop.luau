--!strict
-- Shop window: Upgrades (treadmill, pen, barrier), Trails, Items, and Robux (gamepasses,
-- developer products; the Gacha Capsule shows exact odds before purchase).
-- Also opens from the Trail Shop and Item Shop kiosks in Station Plaza.

local CollectionService = game:GetService("CollectionService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Treadmills = require(Shared.Config.Treadmills)
local Trails = require(Shared.Config.Trails)
local Shop = require(Shared.Config.Shop)
local Items = require(Shared.Config.Items)
local Monetization = require(Shared.Config.Monetization)
local Characters = require(Shared.Config.Characters)
local Rarities = require(Shared.Config.Rarities)
local Net = require(Shared.Net)
local NumberFormat = require(Shared.Util.NumberFormat)
local UI = require(script.Parent.Parent.UI.UI)
local Theme = require(script.Parent.Parent.UI.Theme)
local State = require(script.Parent.State)
local HUD = require(script.Parent.HUD)

local player = Players.LocalPlayer

local ShopController = {}

local pages: { [string]: Frame } = {}
local selectTab: (string) -> () = function() end
local currentTab = "Upgrades"

local function request(category: string, id: any?, amount: number?): any
	local ok, result = pcall(function()
		return Net.Function("Shop"):InvokeServer(category, id, amount)
	end)
	return if ok then result else { Ok = false }
end

local function clear(page: Frame): ScrollingFrame
	for _, child in page:GetChildren() do
		child:Destroy()
	end
	return UI.Scroller({
		Size = UDim2.fromScale(1, 1),
		Grid = { Cell = UDim2.fromOffset(222, 236), Gap = UDim2.fromOffset(10, 10) },
		Padding = 6,
		Parent = page,
	})
end

local function renderUpgrades()
	local list = clear(pages.Upgrades)
	local tier = State.Get("TreadmillTier") or 0
	local current = Treadmills.Get(tier)
	local nextTier = Treadmills.Get(tier + 1)
	local gain = State.GetDerived("SpeedGain") or 0
	UI.Card({
		Title = "TREADMILL",
		Body = string.format(
			"%s\n+%s Speed/s\n\nNext: %s\n%s",
			if current then current.DisplayName else "Locked",
			NumberFormat.Short(gain),
			if nextTier then nextTier.DisplayName .. " (" .. NumberFormat.Short(nextTier.Gain) .. "/s base)" else "MAXED",
			if nextTier then NumberFormat.Cash(nextTier.Price) else ""
		),
		ButtonText = if nextTier then (if tier == 0 then "UNLOCK" else "UPGRADE") else "MAX",
		ButtonColor = if nextTier then Theme.Colors.Green else Theme.Colors.Muted,
		LayoutOrder = 1,
		OnActivated = function()
			request("Treadmill")
			task.wait(0.2)
			renderUpgrades()
		end,
		Parent = list,
	})
	local penLevel = State.Get("PenLevel") or 1
	local nextPen = Shop.PenLevels[penLevel + 1]
	UI.Card({
		Title = "PEN SLOTS",
		Body = string.format(
			"Level %d: %d slots (%d total with bonuses)\n\n%s",
			penLevel,
			Shop.PenSlots(penLevel),
			State.GetDerived("PenSlots") or Shop.PenSlots(penLevel),
			if nextPen then string.format("Next: %d slots\n%s", nextPen.Slots, NumberFormat.Cash(nextPen.Price)) else "MAXED"
		),
		ButtonText = if nextPen then "UPGRADE" else "MAX",
		ButtonColor = if nextPen then Theme.Colors.Green else Theme.Colors.Muted,
		LayoutOrder = 2,
		OnActivated = function()
			request("Pen")
			task.wait(0.2)
			renderUpgrades()
		end,
		Parent = list,
	})
	local barrierLevel = State.Get("BarrierLevel") or 1
	local nextBarrier = Shop.BarrierLevels[barrierLevel + 1]
	UI.Card({
		Title = "BARRIER LOCK",
		Body = string.format(
			"Pushes intruders out of your base.\nNow: %ds\n\n%s",
			Shop.BarrierDuration(barrierLevel),
			if nextBarrier then string.format("Next: %ds\n%s", nextBarrier.Duration, NumberFormat.Cash(nextBarrier.Price)) else "MAXED"
		),
		ButtonText = if nextBarrier then "UPGRADE" else "MAX",
		ButtonColor = if nextBarrier then Theme.Colors.Green else Theme.Colors.Muted,
		LayoutOrder = 3,
		OnActivated = function()
			request("Barrier")
			task.wait(0.2)
			renderUpgrades()
		end,
		Parent = list,
	})
end

local function renderTrails()
	local list = clear(pages.Trails)
	local owned = State.Get("OwnedTrails") or {}
	local equipped = State.Get("EquippedTrail") or ""
	for _, trail in Trails.List do
		local isOwned = owned[trail.Id] == true
		local isEquipped = equipped == trail.Id
		local card, button = UI.Card({
			Title = string.upper(trail.DisplayName),
			TitleColor = Theme.RarityText(trail.Rarity),
			Body = string.format("%s\nTreadmill gain x%.2f\n\n%s", trail.Rarity, trail.Multiplier, if isOwned then "Owned" elseif trail.Price > 0 then NumberFormat.Cash(trail.Price) else "Index reward"),
			ButtonText = if isEquipped then "EQUIPPED" elseif isOwned then "EQUIP" elseif trail.Price > 0 then "BUY" else "LOCKED",
			ButtonColor = if isEquipped then Theme.Colors.Muted elseif isOwned then Theme.Colors.Sky else Theme.Colors.Green,
			LayoutOrder = trail.Order,
			OnActivated = function()
				if isEquipped then
					request("EquipTrail", "")
				elseif isOwned then
					request("EquipTrail", trail.Id)
				elseif trail.Price > 0 then
					request("Trail", trail.Id)
				end
				task.wait(0.2)
				renderTrails()
			end,
			Parent = list,
		})
		local keypoints = {}
		for index, hex in trail.Colors do
			table.insert(keypoints, ColorSequenceKeypoint.new((index - 1) / math.max(1, #trail.Colors - 1), Color3.fromHex(hex)))
		end
		if #keypoints == 1 then
			table.insert(keypoints, ColorSequenceKeypoint.new(1, Color3.fromHex(trail.Colors[1])))
		end
		UI.new("Frame", {
			Size = UDim2.new(1, -16, 0, 10),
			Position = UDim2.new(0, 8, 1, -64),
			BackgroundColor3 = Theme.Colors.White,
			Corner = UDim.new(1, 0),
			Gradient = ColorSequence.new(keypoints),
			GradientRotation = 0,
			Parent = card,
		})
		local _ = button
	end
end

local function renderItems()
	local list = clear(pages.Items)
	local prices = request("ItemPrices")
	for index, itemId in { "OfudaTrap", "SmokeBomb" } do
		local item = (Items :: any)[itemId]
		local count = if itemId == "OfudaTrap" then State.Get("Traps") or 0 else State.Get("SmokeBombs") or 0
		local capacity = if itemId == "OfudaTrap" then (prices.TrapCapacity or item.Capacity) else (prices.SmokeCapacity or item.Capacity)
		local price = prices[itemId] or item.BasePrice
		UI.Card({
			Title = string.upper(item.DisplayName),
			Body = string.format("%s\n\nYou have %d / %d\n%s each", item.Description, count, capacity, NumberFormat.Cash(price)),
			ButtonText = "BUY 1",
			LayoutOrder = index,
			OnActivated = function()
				request("Item", itemId, 1)
				task.wait(0.2)
				renderItems()
			end,
			Parent = list,
		})
	end
end

local function productPrice(id: number, isPass: boolean, suggested: number): string
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(id, if isPass then Enum.InfoType.GamePass else Enum.InfoType.Product)
	end)
	if ok and info and info.PriceInRobux then
		return "R$" .. tostring(info.PriceInRobux)
	end
	return "R$" .. tostring(suggested)
end

local function gachaOddsText(): string
	local lines = { "Exact odds:" }
	local total = 0
	local pool = Characters.ForPool("Gacha")
	for _, character in pool do
		total += character.SpawnWeight
	end
	table.sort(pool, function(a, b)
		return Rarities.Rank(a.Rarity) < Rarities.Rank(b.Rarity)
	end)
	for _, character in pool do
		table.insert(lines, string.format("%s (%s) %.1f%%", character.DisplayName, character.Rarity, character.SpawnWeight / total * 100))
	end
	return table.concat(lines, "\n")
end

local function renderRobux()
	local page = pages.Robux
	for _, child in page:GetChildren() do
		child:Destroy()
	end
	local list = UI.Scroller({
		Size = UDim2.fromScale(1, 1),
		Grid = { Cell = UDim2.fromOffset(222, 250), Gap = UDim2.fromOffset(10, 10) },
		Padding = 6,
		Parent = page,
	})
	local any = false
	local passes = State.GetDerived("Passes") or {}
	for index, pass in Monetization.Passes do
		if pass.Id ~= 0 then
			any = true
			local owned = passes[pass.Key] == true
			UI.Card({
				Title = string.upper(pass.DisplayName),
				TitleColor = Theme.Colors.Gold,
				Body = pass.Description,
				ButtonText = if owned then "OWNED" else productPrice(pass.Id, true, pass.SuggestedRobux),
				ButtonColor = if owned then Theme.Colors.Muted else Theme.Colors.Gold,
				LayoutOrder = index,
				OnActivated = function()
					if not owned then
						MarketplaceService:PromptGamePassPurchase(player, pass.Id)
					end
				end,
				Parent = list,
			})
		end
	end
	for index, product in Monetization.Products do
		if product.Id ~= 0 then
			any = true
			local isGacha = product.Key == "GachaCapsule"
			local card = UI.Card({
				Title = string.upper(product.DisplayName),
				TitleColor = Theme.Colors.Sky,
				Body = if isGacha then product.Description .. "\n\n" .. gachaOddsText() else product.Description,
				ButtonText = productPrice(product.Id, false, product.SuggestedRobux),
				ButtonColor = Theme.Colors.Sky,
				LayoutOrder = 100 + index,
				OnActivated = function()
					if isGacha then
						UI.Confirm("Gacha Capsule Egg", gachaOddsText(), "Buy", function(confirmed)
							if confirmed then
								MarketplaceService:PromptProductPurchase(player, product.Id)
							end
						end)
					else
						MarketplaceService:PromptProductPurchase(player, product.Id)
					end
				end,
				Parent = list,
			})
			if isGacha then
				card.Size = UDim2.fromOffset(222, 360)
			end
		end
	end
	if not any then
		UI.Text({
			Text = "The Robux shop opens once gamepasses and products are set up.\n(Add their IDs in Config/Monetization.)",
			Size = UDim2.new(1, -20, 0, 120),
			TextWrapped = true,
			TextMax = 22,
			Parent = page,
		})
	end
end

local function render(tab: string)
	currentTab = tab
	if tab == "Upgrades" then
		renderUpgrades()
	elseif tab == "Trails" then
		renderTrails()
	elseif tab == "Items" then
		task.spawn(renderItems)
	elseif tab == "Robux" then
		task.spawn(renderRobux)
	end
end

function ShopController.OpenTab(tab: string)
	UI.Open("Shop")
	selectTab(tab)
end

local function kioskPrompt(tag: string, text: string, tab: string)
	local function add(part: Instance)
		if not part:IsA("BasePart") or part:FindFirstChild("KioskPrompt") then
			return
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "KioskPrompt"
		prompt.ActionText = text
		prompt.ObjectText = ""
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Triggered:Connect(function()
			ShopController.OpenTab(tab)
		end)
		prompt.Parent = part
	end
	for _, part in CollectionService:GetTagged(tag) do
		add(part)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(add)
end

function ShopController.Init()
	local window = UI.Window("Shop", "SHOP", UDim2.fromOffset(980, 600), Theme.Colors.Green)
	pages, selectTab = UI.Tabs(window.Content, {
		{ Key = "Upgrades", Text = "UPGRADES", Color = Theme.Colors.Green },
		{ Key = "Trails", Text = "TRAILS", Color = Theme.Colors.Pink },
		{ Key = "Items", Text = "ITEMS", Color = Theme.Colors.Gold },
		{ Key = "Robux", Text = "ROBUX", Color = Theme.Colors.Sky },
	}, render)
	window.OnOpen = function()
		render(currentTab)
	end
end

function ShopController.Start()
	HUD.AddSidebarButton("Shop", "SHOP", Theme.Colors.Green, function()
		ShopController.OpenTab("Upgrades")
	end, 1)
	HUD.AddSidebarButton("Trails", "TRAILS", Theme.Colors.Pink, function()
		ShopController.OpenTab("Trails")
	end, 2)
	kioskPrompt("TrailShop", "Trail Shop", "Trails")
	kioskPrompt("ItemShop", "Item Shop", "Items")
	for _, key in { "Cash", "TreadmillTier", "PenLevel", "BarrierLevel", "OwnedTrails", "EquippedTrail", "Traps", "SmokeBombs" } do
		State.OnChange(key, function()
			if UI.IsOpen("Shop") and (currentTab == "Upgrades" or currentTab == "Trails") then
				render(currentTab)
			end
		end)
	end
end

return ShopController
