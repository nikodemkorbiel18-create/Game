--!strict
-- Rebirth window: requirement checklist, before/after preview of every bonus, exactly
-- what resets and what's kept, and which Protected chibis to keep.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Characters = require(Shared.Config.Characters)
local NumberFormat = require(Shared.Util.NumberFormat)
local Net = require(Shared.Net)
local UI = require(script.Parent.Parent.UI.UI)
local Theme = require(script.Parent.Parent.UI.Theme)
local State = require(script.Parent.State)
local HUD = require(script.Parent.HUD)

local Rebirth = {}

local content: Frame
local keep: { [string]: boolean } = {}

local function pct(value: number): string
	return string.format("+%d%%", math.floor(value * 100 + 0.5))
end

local function render()
	for _, child in content:GetChildren() do
		child:Destroy()
	end
	local ok, preview = pcall(function()
		return Net.Function("Rebirth"):InvokeServer("Preview")
	end)
	if not ok or type(preview) ~= "table" or not preview.Ok then
		UI.Text({ Text = "Couldn't load rebirth info.", Size = UDim2.fromScale(1, 0.2), Parent = content })
		return
	end
	local requirement = preview.Requirement
	local left = UI.new("Frame", { Size = UDim2.new(0.5, -8, 1, -60), BackgroundTransparency = 1, List = { Gap = 6, HAlign = Enum.HorizontalAlignment.Left }, Parent = content })
	local function line(text: string, color: Color3?, order: number)
		UI.Text({ Text = text, Size = UDim2.new(1, 0, 0, 28), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = color or Theme.Colors.White, TextMax = 20, LayoutOrder = order, Parent = left })
	end
	line("REBIRTH " .. preview.Next .. (if preview.Title then "  ·  " .. preview.Title else ""), Theme.Colors.Pink, 1)
	line((if preview.HasCash then "[OK] " else "[  ] ") .. "Have " .. NumberFormat.Cash(requirement.Cash), if preview.HasCash then Theme.Colors.Green else Theme.Colors.Red, 2)
	line((if preview.HasRarity then "[OK] " else "[  ] ") .. "Own any " .. requirement.Rarity .. " or better", if preview.HasRarity then Theme.Colors.Green else Theme.Colors.Red, 3)
	line("BONUSES (before -> after)", Theme.Colors.Gold, 4)
	line("Cash " .. pct(preview.Before.CashBonus) .. " -> " .. pct(preview.After.CashBonus), nil, 5)
	line("Lucky Hatch " .. pct(preview.Before.Luck) .. " -> " .. pct(preview.After.Luck), nil, 6)
	line("Treadmill " .. pct(preview.Before.TreadmillBonus) .. " -> " .. pct(preview.After.TreadmillBonus), nil, 7)
	line("Pen slots +" .. preview.Before.PenSlots .. " -> +" .. preview.After.PenSlots, nil, 8)
	line("Trap capacity +" .. preview.Before.TrapCapacity .. " -> +" .. preview.After.TrapCapacity, nil, 9)

	local right = UI.new("Frame", { Size = UDim2.new(0.5, -8, 1, -60), Position = UDim2.new(0.5, 8, 0, 0), BackgroundTransparency = 1, Parent = content })
	UI.Text({
		Text = "RESETS: cash, Speed, treadmill, pen level, pen, inventory, fusion & incubator queues, Gatekeeper clear.\nKEEPS: index, trails, gamepasses, Robux purchases, titles, codes.",
		Size = UDim2.new(1, 0, 0, 110),
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextMax = 18,
		Parent = right,
	})
	UI.Text({ Text = string.format("Keep %d Protected chibi%s:", preview.KeepCount, if preview.KeepCount == 1 then "" else "s"), Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 114), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Theme.Colors.Gold, TextMax = 20, Parent = right })
	local list = UI.Scroller({ Size = UDim2.new(1, 0, 1, -146), Position = UDim2.fromOffset(0, 146), List = { Gap = 6 }, Parent = right })
	local selectedCount = 0
	for _, value in keep do
		if value then
			selectedCount += 1
		end
	end
	for order, item in preview.Protected do
		local chosen = keep[item.Uid] == true
		UI.Button({
			Text = (if chosen then "[KEEP] " else "") .. Characters.Get(item.CharacterId).DisplayName .. (if item.Awakened then " ★" else ""),
			Size = UDim2.new(1, -10, 0, 38),
			BackgroundColor3 = if chosen then Theme.Colors.Gold else Theme.Colors.PanelLight,
			LayoutOrder = order,
			TextMax = 18,
			OnActivated = function()
				if chosen then
					keep[item.Uid] = nil
				elseif selectedCount < preview.KeepCount then
					keep[item.Uid] = true
				end
				render()
			end,
			Parent = list,
		})
	end
	if #preview.Protected == 0 then
		UI.Text({ Text = if preview.KeepCount > 0 then "Protect chibis in your inventory to keep them." else "You can keep chibis from your 2nd rebirth on.", Size = UDim2.new(1, -10, 0, 50), TextWrapped = true, TextMax = 16, TextColor3 = Theme.Colors.Muted, Parent = list })
	end
	UI.Button({
		Text = if preview.Eligible then "REBIRTH!" else "NOT YET",
		Size = UDim2.new(0.5, 0, 0, 50),
		Position = UDim2.new(0.25, 0, 1, -52),
		BackgroundColor3 = if preview.Eligible then Theme.Colors.Pink else Theme.Colors.Muted,
		OnActivated = function()
			if not preview.Eligible then
				return
			end
			UI.Confirm("Rebirth?", "Everything listed under RESETS goes back to the start. Ready?", "Rebirth", function(confirmed)
				if confirmed then
					local uids = {}
					for uid, value in keep do
						if value then
							table.insert(uids, uid)
						end
					end
					pcall(function()
						Net.Function("Rebirth"):InvokeServer("Confirm", uids)
					end)
					table.clear(keep)
				else
					UI.Open("Rebirth")
				end
			end)
		end,
		Parent = content,
	})
end

function Rebirth.Init()
	local window = UI.Window("Rebirth", "REBIRTH", UDim2.fromOffset(920, 580), Theme.Colors.Pink)
	content = window.Content
	window.OnOpen = render
end

function Rebirth.Start()
	HUD.AddSidebarButton("Rebirth", "REBIRTH", Theme.Colors.Red, function()
		UI.Open("Rebirth")
	end, 4)
	local _ = State
end

return Rebirth
