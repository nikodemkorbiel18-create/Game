--!strict
-- Helpers for built models.

local ModelUtil = {}

-- Converts an anchored model into a single welded, massless, non-colliding assembly
-- rooted at its PrimaryPart (used for items carried over a player's head).
function ModelUtil.Weld(model: Model): BasePart
	local root = model.PrimaryPart
	assert(root, "Model needs a PrimaryPart")
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.Massless = true
			if descendant ~= root then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = root
				weld.Part1 = descendant
				weld.Parent = descendant
			end
			descendant.Anchored = false
		end
	end
	return root
end

function ModelUtil.SetTransparency(model: Instance, transparency: number)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Name ~= "Root" then
			descendant.LocalTransparencyModifier = transparency
		end
	end
end

function ModelUtil.Height(model: Model): number
	local _, size = model:GetBoundingBox()
	return size.Y
end

return ModelUtil
