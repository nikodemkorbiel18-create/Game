--!strict
-- Sacred Tree Incubator window: quote for the egg you're carrying (fee, mutation warning),
-- start the 60s ritual, and claim finished rituals.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Characters = require(Shared.Config.Characters)
local NumberFormat = require(Shared.Util.NumberFormat)
local TimeFormat = require(Shared.Util.TimeFormat)
local Net = require(Shared.Net)
local UI = require(script.Parent.Parent.UI.UI)
local Theme = require(script.Parent.Parent.UI.Theme)
local ItemCard = require(script.Parent.Parent.UI.ItemCard)
local State = require(script.Parent.State)

local Incubator = {}

local content: Frame

local function invoke(action: string, arg: any?): any
	local ok, result = pcall(function()
		return Net.Function("Incubator"):InvokeServer(action, arg)
	end)
	return if ok and type(result) == "table" then result else { Ok = false }
end

local function render()
	for _, child in content:GetChildren() do
		child:Destroy()
	end
	local quote = invoke("Quote")
	local top = UI.new("Frame", { Size = UDim2.new(1, 0, 0.5, 0), BackgroundTransparency = 1, Parent = content })
	if quote.Ok then
		local name = if State.IsDiscovered(quote.CharacterId) then Characters.Get(quote.CharacterId).DisplayName else "???"
		UI.Text({
			Text = string.format("Incubate %s?\nFee: %s  ·  Ritual: %s\n97.5%% Petal Bloom (x1.5)  ·  2.5%% Kami Bloom (x3)", name, NumberFormat.Cash(quote.Fee), TimeFormat.Short(quote.Duration)),
			Size = UDim2.new(1, 0, 0.6, 0),
			TextWrapped = true,
			TextMax = 22,
			Parent = top,
		})
		if quote.Warning then
			UI.Text({ Text = "Warning: this replaces its " .. tostring(quote.CurrentMutation) .. " mutation, which is stronger than Petal Bloom!", Size = UDim2.new(1, 0, 0.18, 0), Position = UDim2.fromScale(0, 0.6), TextColor3 = Theme.Colors.Red, TextWrapped = true, TextMax = 18, Parent = top })
		end
		UI.Button({
			Text = "BEGIN RITUAL",
			Size = UDim2.fromOffset(260, 44),
			Position = UDim2.new(0.5, -130, 0.8, 0),
			BackgroundColor3 = Theme.Colors.Pink,
			OnActivated = function()
				local function go(confirmed: boolean)
					invoke("Start", confirmed)
					UI.Open("Incubator")
					render()
				end
				if quote.Warning then
					UI.Confirm("Replace mutation?", "The stronger " .. tostring(quote.CurrentMutation) .. " mutation will be lost.", "Replace", function(ok)
						if ok then
							go(true)
						else
							UI.Open("Incubator")
						end
					end)
				else
					go(false)
				end
			end,
			Parent = top,
		})
	else
		UI.Text({ Text = tostring(quote.Error or "Carry one of your unhatched eggs here."), Size = UDim2.new(1, 0, 0.5, 0), TextWrapped = true, TextMax = 22, Parent = top })
	end
	local list = UI.Scroller({ Size = UDim2.new(1, 0, 0.5, 0), Position = UDim2.fromScale(0, 0.5), Grid = { Cell = UDim2.fromOffset(170, 240), Gap = UDim2.fromOffset(8, 8) }, Parent = content })
	for index, job in State.Get("Incubator") or {} do
		local remaining = job.EndsAt - workspace:GetServerTimeNow()
		ItemCard.Build(job.Item, {
			Parent = list,
			LayoutOrder = index,
			Subtitle = if remaining > 0 then "Blooming in " .. TimeFormat.Short(remaining) else "READY!",
			Buttons = { {
				Text = if remaining > 0 then "RITUAL..." else "CLAIM",
				Color = if remaining > 0 then Theme.Colors.Muted else Theme.Colors.Gold,
				OnActivated = function()
					if remaining <= 0 then
						invoke("Claim", index)
						render()
					end
				end,
			} },
		})
	end
end

function Incubator.Init()
	local window = UI.Window("Incubator", "SACRED TREE INCUBATOR", UDim2.fromOffset(820, 600), Theme.Colors.Pink)
	content = window.Content
	window.OnOpen = render
end

function Incubator.Start()
	local function add(part: Instance)
		if not part:IsA("BasePart") or part:FindFirstChild("KioskPrompt") then
			return
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "KioskPrompt"
		prompt.ActionText = "Sacred Tree"
		prompt.MaxActivationDistance = 14
		prompt.RequiresLineOfSight = false
		prompt.Triggered:Connect(function()
			UI.Open("Incubator")
		end)
		prompt.Parent = part
	end
	for _, part in CollectionService:GetTagged("SacredIncubator") do
		add(part)
	end
	CollectionService:GetInstanceAddedSignal("SacredIncubator"):Connect(add)
	task.spawn(function()
		while true do
			task.wait(1)
			if UI.IsOpen("Incubator") then
				render()
			end
		end
	end)
end

return Incubator
