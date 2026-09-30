--!strict
-- World queries shared by services.

local CollectionService = game:GetService("CollectionService")

local World = {}

function World.Root(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

function World.Humanoid(player: Player): Humanoid?
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return humanoid
	end
	return nil
end

function World.Position(player: Player): Vector3?
	local root = World.Root(player)
	return if root then root.Position else nil
end

-- Is a point inside a part's footprint (XZ, respecting rotation) and within `height`
-- studs above its top surface?
function World.InsideFootprint(point: Vector3, part: BasePart, height: number?, margin: number?): boolean
	local localPoint = part.CFrame:PointToObjectSpace(point)
	local half = part.Size / 2
	local pad = margin or 0
	if math.abs(localPoint.X) > half.X + pad or math.abs(localPoint.Z) > half.Z + pad then
		return false
	end
	local above = localPoint.Y - half.Y
	return above >= -4 and above <= (height or 60)
end

-- Is a point inside a part's box?
function World.InsideBox(point: Vector3, part: BasePart, margin: number?): boolean
	local localPoint = part.CFrame:PointToObjectSpace(point)
	local half = part.Size / 2 + Vector3.one * (margin or 0)
	return math.abs(localPoint.X) <= half.X and math.abs(localPoint.Y) <= half.Y and math.abs(localPoint.Z) <= half.Z
end

-- Distance from a point to a part's box (0 when inside)
function World.DistanceToBox(point: Vector3, part: BasePart): number
	local localPoint = part.CFrame:PointToObjectSpace(point)
	local half = part.Size / 2
	local dx = math.max(math.abs(localPoint.X) - half.X, 0)
	local dy = math.max(math.abs(localPoint.Y) - half.Y, 0)
	local dz = math.max(math.abs(localPoint.Z) - half.Z, 0)
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function World.Tagged(tag: string): { Instance }
	return CollectionService:GetTagged(tag)
end

function World.TaggedParts(tag: string): { BasePart }
	local result = {}
	for _, instance in CollectionService:GetTagged(tag) do
		if instance:IsA("BasePart") then
			table.insert(result, instance)
		end
	end
	return result
end

function World.FlatDistance(a: Vector3, b: Vector3): number
	return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude
end

-- Server-side check that a player is close enough to a position to interact with it.
function World.WithinReach(player: Player, position: Vector3, range: number): boolean
	local playerPosition = World.Position(player)
	if not playerPosition then
		return false
	end
	return (playerPosition - position).Magnitude <= range
end

-- Server-initiated teleport. Marks the player so the anti-exploit position check
-- doesn't rubber-band them.
function World.Teleport(player: Player, cframe: CFrame)
	local character = player.Character
	if not character then
		return
	end
	player:SetAttribute("ServerMovedAt", os.clock())
	character:PivotTo(cframe)
	local root = World.Root(player)
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
	end
end

function World.MakeUid(): string
	return game:GetService("HttpService"):GenerateGUID(false)
end

return World
