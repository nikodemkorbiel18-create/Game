--!strict
-- ProximityPrompt helpers with server-side hold validation. Clients may change prompt text
-- or hold time locally for display, but the server measures how long each player actually
-- held the button (PromptButtonHoldBegan -> Triggered) and rejects short holds.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")

local World = require(script.Parent.World)

local Prompts = {}

local holdStarts: { [Player]: { [ProximityPrompt]: number } } = {}
local LATENCY_TOLERANCE = 0.2

ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt, player)
	local starts = holdStarts[player]
	if not starts then
		starts = {}
		holdStarts[player] = starts
	end
	starts[prompt] = os.clock()
end)

Players.PlayerRemoving:Connect(function(player)
	holdStarts[player] = nil
end)

export type PromptProps = {
	Name: string?,
	ActionText: string,
	ObjectText: string?,
	HoldDuration: number?,
	Range: number?,
	KeyCode: Enum.KeyCode?,
	Style: Enum.ProximityPromptStyle?,
	RequiresLineOfSight: boolean?,
	Exclusivity: Enum.ProximityPromptExclusivity?,
}

function Prompts.Create(parent: Instance, props: PromptProps): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = props.Name or "Prompt"
	prompt.ActionText = props.ActionText
	prompt.ObjectText = props.ObjectText or ""
	prompt.HoldDuration = props.HoldDuration or 0
	prompt.MaxActivationDistance = props.Range or 10
	prompt.KeyboardKeyCode = props.KeyCode or Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.RequiresLineOfSight = props.RequiresLineOfSight == true
	prompt.Exclusivity = props.Exclusivity or Enum.ProximityPromptExclusivity.OnePerButton
	prompt.Style = props.Style or Enum.ProximityPromptStyle.Default
	prompt.Parent = parent
	return prompt
end

-- How long `player` has been holding `prompt` (0 if never started)
function Prompts.HeldFor(player: Player, prompt: ProximityPrompt): number
	local starts = holdStarts[player]
	local started = starts and starts[prompt]
	if not started then
		return 0
	end
	return os.clock() - started
end

-- Connect a Triggered handler that only runs if the player held for at least
-- requiredHold(player) seconds and is within range of the prompt's parent.
function Prompts.OnTriggered(
	prompt: ProximityPrompt,
	requiredHold: (Player) -> number,
	handler: (Player, number) -> (),
	range: number?
): RBXScriptConnection
	return prompt.Triggered:Connect(function(player)
		local required = requiredHold(player)
		local held = Prompts.HeldFor(player, prompt)
		local starts = holdStarts[player]
		if starts then
			starts[prompt] = nil
		end
		if required > 0 and held + LATENCY_TOLERANCE < required then
			return
		end
		local parent = prompt.Parent
		local position: Vector3? = nil
		if parent and parent:IsA("BasePart") then
			position = parent.Position
		elseif parent and parent:IsA("Attachment") then
			position = parent.WorldPosition
		elseif parent and parent:IsA("Model") then
			position = parent:GetPivot().Position
		end
		if position and not World.WithinReach(player, position, (range or prompt.MaxActivationDistance) + 6) then
			return
		end
		handler(player, held)
	end)
end

return Prompts
