--!strict
-- Player bases: assignment, pen slot rendering, slot prompts, owner sign, register display,
-- Barrier Lock and new-player protection. Plots are Models tagged "Plot" (see
-- docs/STUDIO_SETUP.md for the parts each plot needs).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Tags = require(Shared.Config.Tags)
local GameSettings = require(Shared.Config.GameSettings)
local Shop = require(Shared.Config.Shop)
local Rebirths = require(Shared.Config.Rebirths)
local Characters = require(Shared.Config.Characters)
local Sizes = require(Shared.Config.Sizes)
local Formulas = require(Shared.Util.Formulas)
local NumberFormat = require(Shared.Util.NumberFormat)
local TimeFormat = require(Shared.Util.TimeFormat)
local Signal = require(Shared.Util.Signal)
local Types = require(Shared.Types)
local EggBuilder = require(Shared.Visual.EggBuilder)
local CharacterBuilder = require(Shared.Visual.CharacterBuilder)

local DataService = require(script.Parent.DataService)
local PassService = require(script.Parent.PassService)
local AnnouncementService = require(script.Parent.AnnouncementService)
local Prompts = require(script.Parent.Parent.Lib.Prompts)
local World = require(script.Parent.Parent.Lib.World)

type Item = Types.Item

export type Plot = {
	Id: number,
	Model: Model,
	Floor: BasePart,
	Slots: { [number]: BasePart },
	SlotPrompts: { [number]: ProximityPrompt },
	SlotModels: { [number]: Model },
	Register: BasePart?,
	CollectPlate: BasePart?,
	Treadmill: Model?,
	TreadmillBelt: BasePart?,
	BarrierButton: BasePart?,
	BarrierField: BasePart?,
	Sign: BasePart?,
	Spawn: BasePart?,
	ItemsFolder: Folder,
	Owner: Player?,
	BarrierUntil: number,
	BarrierCooldownUntil: number,
	RegisterLabel: TextLabel?,
	SignLabels: { Title: TextLabel, Income: TextLabel, Status: TextLabel }?,
}

local PlotService = {}

local plots: { Plot } = {}
local plotByPlayer: { [Player]: Plot } = {}

-- (player, plot, slotIndex, heldSeconds)
PlotService.SlotTriggered = Signal.new() :: Signal.Signal<Player, Plot, number, number>
PlotService.PlotAssigned = Signal.new() :: Signal.Signal<Player, Plot>
-- Set by IncomeService so slots can show effective $/s
PlotService.IncomeResolver = nil :: ((Player, Item) -> number)?

local function taggedIn(model: Instance, tag: string): { Instance }
	local result = {}
	for _, descendant in model:GetDescendants() do
		if CollectionService:HasTag(descendant, tag) then
			table.insert(result, descendant)
		end
	end
	return result
end

local function firstPart(model: Instance, tag: string): BasePart?
	for _, instance in taggedIn(model, tag) do
		if instance:IsA("BasePart") then
			return instance
		end
	end
	return nil
end

local function setSlotVisible(slot: BasePart, visible: boolean)
	slot.Transparency = if visible then 0 else 1
	slot.CanCollide = visible
	for _, child in slot:GetChildren() do
		if child:IsA("BasePart") then
			child.Transparency = if visible then 0 else 1
		elseif child:IsA("SurfaceGui") or child:IsA("Decal") then
			(child :: any).Enabled = visible
		end
	end
end

local function makeSign(plot: Plot)
	local sign = plot.Sign
	if not sign then
		return
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "OwnerSign"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = sign
	local function label(name: string, y: number, height: number, size: number, color: Color3): TextLabel
		local text = Instance.new("TextLabel")
		text.Name = name
		text.BackgroundTransparency = 1
		text.Size = UDim2.new(1, -20, height, 0)
		text.Position = UDim2.new(0, 10, y, 0)
		text.Font = Enum.Font.FredokaOne
		text.TextScaled = true
		text.TextColor3 = color
		text.Text = ""
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 3
		stroke.Color = Color3.fromRGB(30, 20, 40)
		stroke.Parent = text
		local constraint = Instance.new("UITextSizeConstraint")
		constraint.MaxTextSize = size
		constraint.Parent = text
		text.Parent = gui
		return text
	end
	plot.SignLabels = {
		Title = label("Title", 0.05, 0.4, 120, Color3.fromRGB(255, 255, 255)),
		Income = label("Income", 0.45, 0.28, 90, Color3.fromRGB(120, 255, 140)),
		Status = label("Status", 0.73, 0.22, 70, Color3.fromRGB(255, 220, 120)),
	}
end

local function makeRegisterLabel(plot: Plot)
	local register = plot.Register
	if not register then
		return
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "RegisterDisplay"
	billboard.Size = UDim2.fromScale(6, 2)
	billboard.StudsOffset = Vector3.new(0, register.Size.Y / 2 + 1.6, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 80
	billboard.Parent = register
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(120, 255, 140)
	text.Text = "$0"
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Parent = text
	text.Parent = billboard
	plot.RegisterLabel = text
end

local function discover()
	for _, instance in CollectionService:GetTagged(Tags.Plot) do
		if not instance:IsA("Model") then
			continue
		end
		local id = instance:GetAttribute("PlotId")
		local floor = firstPart(instance, Tags.PlotFloor)
		if type(id) ~= "number" or not floor then
			warn("[PlotService] Plot " .. instance:GetFullName() .. " is missing PlotId or a PlotFloor part")
			continue
		end
		local itemsFolder = Instance.new("Folder")
		itemsFolder.Name = "PenItems"
		itemsFolder.Parent = instance
		local treadmill: Model? = nil
		for _, found in taggedIn(instance, Tags.Treadmill) do
			if found:IsA("Model") then
				treadmill = found
			end
		end
		local belt = if treadmill then treadmill:FindFirstChild("Belt") else nil
		local plot: Plot = {
			Id = id,
			Model = instance,
			Floor = floor,
			Slots = {},
			SlotPrompts = {},
			SlotModels = {},
			Register = firstPart(instance, Tags.CashRegister),
			CollectPlate = firstPart(instance, Tags.CollectPlate),
			Treadmill = treadmill,
			TreadmillBelt = if belt and belt:IsA("BasePart") then belt else nil,
			BarrierButton = firstPart(instance, Tags.BarrierButton),
			BarrierField = firstPart(instance, Tags.BarrierField),
			Sign = firstPart(instance, Tags.PlotSign),
			Spawn = firstPart(instance, Tags.PlotSpawn),
			ItemsFolder = itemsFolder,
			Owner = nil,
			BarrierUntil = 0,
			BarrierCooldownUntil = 0,
		}
		for _, slot in taggedIn(instance, Tags.PenSlot) do
			local index = slot:GetAttribute("SlotIndex")
			if slot:IsA("BasePart") and type(index) == "number" then
				plot.Slots[index] = slot
				slot:SetAttribute("PlotId", id)
				local prompt = Prompts.Create(slot, {
					Name = "SlotPrompt",
					ActionText = "Interact",
					ObjectText = "Pen Slot",
					HoldDuration = GameSettings.OwnerPickupHoldTime,
					Range = GameSettings.InteractRange,
				})
				prompt.Enabled = false
				plot.SlotPrompts[index] = prompt
				Prompts.OnTriggered(prompt, function()
					return GameSettings.OwnerPickupHoldTime
				end, function(player, held)
					PlotService.SlotTriggered:Fire(player, plot, index, held)
				end)
			end
		end
		if plot.BarrierField then
			local field = plot.BarrierField
			field.Transparency = 1
			field.CanCollide = false
			field.CanQuery = false
			field.CanTouch = false
		end
		if plot.BarrierButton then
			local prompt = Prompts.Create(plot.BarrierButton, {
				Name = "BarrierPrompt",
				ActionText = "Barrier Lock",
				ObjectText = "Base Defense",
				HoldDuration = 0,
				Range = 10,
			})
			Prompts.OnTriggered(prompt, function()
				return 0
			end, function(player)
				PlotService.ActivateBarrier(player, plot)
			end)
		end
		makeSign(plot)
		makeRegisterLabel(plot)
		table.insert(plots, plot)
	end
	table.sort(plots, function(a, b)
		return a.Id < b.Id
	end)
	if #plots == 0 then
		warn("[PlotService] No plots found. Tag each base Model with 'Plot' (see docs/STUDIO_SETUP.md).")
	end
end

function PlotService.All(): { Plot }
	return plots
end

function PlotService.Get(player: Player): Plot?
	return plotByPlayer[player]
end

function PlotService.OwnerOf(plot: Plot): Player?
	return plot.Owner
end

function PlotService.PlotAt(position: Vector3, margin: number?): Plot?
	for _, plot in plots do
		if World.InsideFootprint(position, plot.Floor, 60, margin) then
			return plot
		end
	end
	return nil
end

function PlotService.IsInOwnPlot(player: Player): boolean
	local plot = plotByPlayer[player]
	local position = World.Position(player)
	return plot ~= nil and position ~= nil and World.InsideFootprint(position, plot.Floor, 60)
end

function PlotService.IsProtected(player: Player): boolean
	local data = DataService.Get(player)
	return data ~= nil and data.Playtime < GameSettings.NewPlayerProtection
end

function PlotService.ActiveSlots(player: Player): number
	local data = DataService.Get(player)
	if not data then
		return 0
	end
	local count = Shop.PenSlots(data.PenLevel)
		+ PassService.ExtraPenSlots(player)
		+ math.min(data.Rebirths * Rebirths.Rewards.PenSlots, Rebirths.MaxBonusPenSlots)
	local plot = plotByPlayer[player]
	local physical = if plot then #plot.Slots else GameSettings.PhysicalPenSlots
	return math.min(count, physical)
end

function PlotService.FirstFreeSlot(player: Player): number?
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	for index = 1, PlotService.ActiveSlots(player) do
		if data.Pen[tostring(index)] == nil then
			return index
		end
	end
	return nil
end

local function displayScale(item: Item): number
	local scale = Sizes.Get(item.SizeTier).Scale
	if item.Kind == "Character" then
		return math.clamp(scale, 0.7, 1.5)
	end
	return math.min(scale, 1.8)
end

function PlotService.BuildItemModel(item: Item): Model
	if item.Kind == "Egg" then
		return EggBuilder.Build({
			CharacterId = item.CharacterId,
			SizeTier = item.SizeTier,
			Mutation = item.Mutation,
			Color = item.Color,
			EggModel = item.EggModel,
			Awakened = item.Awakened,
		}, displayScale(item))
	end
	return CharacterBuilder.Build(item.CharacterId, {
		Scale = displayScale(item),
		Mutation = item.Mutation,
		Awakened = item.Awakened,
	})
end

local SLOT_ATTRIBUTES = { "Kind", "CharacterId", "SizeTier", "Kg", "Mutation", "Awakened", "HatchEndsAt", "Income", "Rarity", "Lucky", "Uid" }

function PlotService.RenderSlot(player: Player, index: number)
	local plot = plotByPlayer[player]
	local data = DataService.Get(player)
	if not plot or not data then
		return
	end
	local slot = plot.Slots[index]
	if not slot then
		return
	end
	local existing = plot.SlotModels[index]
	if existing then
		existing:Destroy()
		plot.SlotModels[index] = nil
	end
	for _, attribute in SLOT_ATTRIBUTES do
		slot:SetAttribute(attribute, nil)
	end
	CollectionService:RemoveTag(slot, Tags.PenItem)
	local item = data.Pen[tostring(index)]
	slot:SetAttribute("Occupied", item ~= nil)
	if item then
		local model = PlotService.BuildItemModel(item)
		model.Name = "Slot" .. index
		model:PivotTo(slot.CFrame * CFrame.new(0, slot.Size.Y / 2, 0))
		model.Parent = plot.ItemsFolder
		model:SetAttribute("Kind", item.Kind)
		model:SetAttribute("HatchEndsAt", item.HatchEndsAt)
		CollectionService:AddTag(model, "PenModel")
		plot.SlotModels[index] = model
		slot:SetAttribute("Kind", item.Kind)
		slot:SetAttribute("CharacterId", item.CharacterId)
		slot:SetAttribute("SizeTier", item.SizeTier)
		slot:SetAttribute("Kg", item.Kg)
		slot:SetAttribute("Mutation", item.Mutation)
		slot:SetAttribute("Awakened", item.Awakened == true)
		slot:SetAttribute("Lucky", item.Lucky == true)
		slot:SetAttribute("Uid", item.Uid)
		slot:SetAttribute("HatchEndsAt", item.HatchEndsAt)
		slot:SetAttribute("Rarity", Formulas.DisplayRarity(item))
		local resolver = PlotService.IncomeResolver
		if resolver then
			slot:SetAttribute("Income", resolver(player, item))
		end
		CollectionService:AddTag(slot, Tags.PenItem)
	end
end

function PlotService.RefreshSlots(player: Player)
	local plot = plotByPlayer[player]
	local data = DataService.Get(player)
	if not plot or not data then
		return
	end
	local active = PlotService.ActiveSlots(player)
	for index, slot in plot.Slots do
		local occupied = data.Pen[tostring(index)] ~= nil
		local visible = index <= active or occupied
		setSlotVisible(slot, visible)
		slot:SetAttribute("Active", visible)
		local prompt = plot.SlotPrompts[index]
		if prompt then
			prompt.Enabled = visible
			prompt.ObjectText = if occupied then "" else "Empty Slot"
		end
	end
end

function PlotService.RenderAll(player: Player)
	local plot = plotByPlayer[player]
	if not plot then
		return
	end
	for index in plot.Slots do
		PlotService.RenderSlot(player, index)
	end
	PlotService.RefreshSlots(player)
end

-- Refresh only the income attribute (after multipliers change)
function PlotService.RefreshIncomeLabels(player: Player)
	local plot = plotByPlayer[player]
	local data = DataService.Get(player)
	local resolver = PlotService.IncomeResolver
	if not plot or not data or not resolver then
		return
	end
	for index, slot in plot.Slots do
		local item = data.Pen[tostring(index)]
		if item then
			slot:SetAttribute("Income", resolver(player, item))
		end
	end
end

function PlotService.SetRegister(player: Player, amount: number)
	local plot = plotByPlayer[player]
	if plot and plot.RegisterLabel then
		plot.RegisterLabel.Text = NumberFormat.Cash(amount)
	end
	if plot then
		plot.Model:SetAttribute("Register", amount)
	end
end

function PlotService.UpdateSign(player: Player, incomePerSecond: number)
	local plot = plotByPlayer[player]
	if not plot then
		return
	end
	plot.Model:SetAttribute("IncomePerSecond", incomePerSecond)
end

local function renderSign(plot: Plot)
	local labels = plot.SignLabels
	if not labels then
		return
	end
	local owner = plot.Owner
	if not owner then
		labels.Title.Text = "Empty Base"
		labels.Income.Text = ""
		labels.Status.Text = ""
		return
	end
	labels.Title.Text = owner.DisplayName .. "'s Base"
	local income = plot.Model:GetAttribute("IncomePerSecond")
	labels.Income.Text = NumberFormat.PerSecond(if type(income) == "number" then income else 0)
	local now = os.time()
	local data = DataService.Get(owner)
	if plot.BarrierUntil > now then
		labels.Status.Text = "LOCKED " .. TimeFormat.Short(plot.BarrierUntil - now)
		labels.Status.TextColor3 = Color3.fromRGB(120, 200, 255)
	elseif data and data.Playtime < GameSettings.NewPlayerProtection then
		labels.Status.Text = "NEW PLAYER SHIELD " .. TimeFormat.Short(GameSettings.NewPlayerProtection - data.Playtime)
		labels.Status.TextColor3 = Color3.fromRGB(255, 220, 120)
	else
		local title = owner:GetAttribute("Title")
		labels.Status.Text = if type(title) == "string" then title else ""
		labels.Status.TextColor3 = Color3.fromRGB(255, 160, 220)
	end
end

function PlotService.BarrierActive(plot: Plot): boolean
	return plot.BarrierUntil > os.time()
end

function PlotService.ActivateBarrier(player: Player, plot: Plot)
	if plot.Owner ~= player then
		AnnouncementService.Error(player, "That's not your base!")
		return
	end
	local now = os.time()
	if plot.BarrierUntil > now then
		AnnouncementService.Notify(player, "Barrier already active!", "Info")
		return
	end
	if plot.BarrierCooldownUntil > now then
		AnnouncementService.Error(player, "Barrier recharging: " .. TimeFormat.Short(plot.BarrierCooldownUntil - now))
		return
	end
	local data = DataService.Get(player)
	if not data then
		return
	end
	local duration = Shop.BarrierDuration(data.BarrierLevel) + PassService.BarrierBonus(player)
	plot.BarrierUntil = now + duration
	plot.BarrierCooldownUntil = plot.BarrierUntil + GameSettings.Barrier.Cooldown
	plot.Model:SetAttribute("BarrierUntil", plot.BarrierUntil)
	plot.Model:SetAttribute("BarrierCooldownUntil", plot.BarrierCooldownUntil)
	local field = plot.BarrierField
	if field then
		field.Transparency = 0.55
	end
	AnnouncementService.Notify(player, "Barrier Lock active for " .. duration .. "s!", "Success")
	task.delay(duration, function()
		if plot.BarrierUntil <= os.time() and field then
			field.Transparency = 1
		end
	end)
end

-- Pushes non-owners out of locked plots
local function pushIntruders()
	local now = os.time()
	for _, plot in plots do
		if plot.Owner and plot.BarrierUntil > now then
			for _, other in Players:GetPlayers() do
				if other ~= plot.Owner then
					local root = World.Root(other)
					if root and World.InsideFootprint(root.Position, plot.Floor, 40, 1) then
						-- push straight out past the nearest edge of the (rotated, rectangular) floor
						local floorCFrame = plot.Floor.CFrame
						local localOffset = floorCFrame:VectorToObjectSpace(root.Position - floorCFrame.Position) * Vector3.new(1, 0, 1)
						if localOffset.Magnitude < 1 then
							localOffset = Vector3.new(1, 0, 0)
						end
						local halfX, halfZ = plot.Floor.Size.X / 2, plot.Floor.Size.Z / 2
						local ratio = math.max(math.abs(localOffset.X) / halfX, math.abs(localOffset.Z) / halfZ)
						local edge = localOffset / ratio + localOffset.Unit * 6
						local direction = floorCFrame:VectorToWorldSpace(localOffset.Unit)
						local target = floorCFrame.Position + floorCFrame:VectorToWorldSpace(edge) + Vector3.new(0, 4, 0)
						World.Teleport(other, CFrame.new(target, target + direction))
					end
				end
			end
		end
	end
end

local function assign(player: Player)
	if plotByPlayer[player] then
		return
	end
	for _, plot in plots do
		if plot.Owner == nil then
			plot.Owner = player
			plot.BarrierUntil = 0
			plot.BarrierCooldownUntil = 0
			plot.Model:SetAttribute("OwnerUserId", player.UserId)
			plot.Model:SetAttribute("OwnerName", player.DisplayName)
			plotByPlayer[player] = plot
			player:SetAttribute("PlotId", plot.Id)
			PlotService.RenderAll(player)
			renderSign(plot)
			PlotService.PlotAssigned:Fire(player, plot)
			return
		end
	end
	AnnouncementService.Error(player, "This server is full of bases. You can explore, but you have no pen.")
end

local function release(player: Player)
	local plot = plotByPlayer[player]
	if not plot then
		return
	end
	for index, model in plot.SlotModels do
		model:Destroy()
		plot.SlotModels[index] = nil
	end
	for index, slot in plot.Slots do
		for _, attribute in SLOT_ATTRIBUTES do
			slot:SetAttribute(attribute, nil)
		end
		slot:SetAttribute("Occupied", false)
		CollectionService:RemoveTag(slot, Tags.PenItem)
		local prompt = plot.SlotPrompts[index]
		if prompt then
			prompt.Enabled = false
		end
		setSlotVisible(slot, index <= Shop.PenSlots(1))
		slot:SetAttribute("Active", false)
	end
	plot.Owner = nil
	plot.BarrierUntil = 0
	plot.Model:SetAttribute("OwnerUserId", nil)
	plot.Model:SetAttribute("OwnerName", nil)
	plot.Model:SetAttribute("IncomePerSecond", 0)
	plot.Model:SetAttribute("BarrierUntil", nil)
	if plot.BarrierField then
		plot.BarrierField.Transparency = 1
	end
	PlotService.SetRegister(player, 0)
	plotByPlayer[player] = nil
	renderSign(plot)
end

function PlotService.SpawnCFrame(player: Player): CFrame?
	local plot = plotByPlayer[player]
	if not plot then
		return nil
	end
	local spawn = plot.Spawn or plot.Floor
	return spawn.CFrame * CFrame.new(0, spawn.Size.Y / 2 + 3.5, 0)
end

local function onCharacterAdded(player: Player, character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root then
		return
	end
	task.wait(0.1)
	local cframe = PlotService.SpawnCFrame(player)
	if cframe and character.Parent then
		World.Teleport(player, cframe)
	end
end

function PlotService.Init()
	discover()
end

function PlotService.Start()
	DataService.Loaded:Connect(function(player)
		assign(player)
		if player.Character then
			task.spawn(onCharacterAdded, player, player.Character)
		end
	end)
	DataService.Releasing:Connect(function(player)
		release(player)
	end)
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
	end)
	for _, player in Players:GetPlayers() do
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
	end
	PassService.Changed:Connect(function(player, key)
		if key == "ExtraPenSlots" then
			PlotService.RefreshSlots(player)
		end
	end)
	for _, plot in plots do
		renderSign(plot)
		if not plot.Owner then
			for index, slot in plot.Slots do
				setSlotVisible(slot, index <= Shop.PenSlots(1))
			end
		end
	end
	task.spawn(function()
		local signTimer = 0
		while true do
			local dt = task.wait(GameSettings.Barrier.PushInterval)
			pushIntruders()
			signTimer += dt
			if signTimer >= 1 then
				signTimer = 0
				local now = os.time()
				for _, plot in plots do
					renderSign(plot)
					if plot.Owner then
						local protected = PlotService.IsProtected(plot.Owner)
						plot.Model:SetAttribute("Protected", protected)
					end
					if plot.BarrierField and plot.BarrierUntil <= now then
						plot.BarrierField.Transparency = 1
					end
				end
			end
		end
	end)
end

-- Character lookup helper for other services
function PlotService.CharacterName(item: Item): string
	return Characters.Get(item.CharacterId).DisplayName
end

return PlotService
