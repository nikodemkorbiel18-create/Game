--!nocheck
-- Shared helpers for the Lune map builder (Roblox datatypes come from @lune/roblox).

local roblox = require("@lune/roblox")

local Instance = roblox.Instance
local CFrame = roblox.CFrame
local Vector3 = roblox.Vector3
local Color3 = roblox.Color3
local Enum = roblox.Enum

local Common = {
	Instance = Instance,
	CFrame = CFrame,
	Vector3 = Vector3,
	Color3 = Color3,
	Enum = Enum,
}

function Common.hex(hex)
	hex = string.gsub(hex, "#", "")
	local r = tonumber(string.sub(hex, 1, 2), 16)
	local g = tonumber(string.sub(hex, 3, 4), 16)
	local b = tonumber(string.sub(hex, 5, 6), 16)
	return Color3.fromRGB(r, g, b)
end

-- Creates an anchored part. opts: Name, Size, CFrame, Color, Material, Shape, Transparency,
-- CanCollide, CanQuery, CanTouch, Tags, Attributes, Parent, Class
function Common.part(opts)
	local part = Instance.new(opts.Class or "Part")
	part.Name = opts.Name or "Part"
	part.Anchored = true
	part.Size = opts.Size or Vector3.new(4, 1, 4)
	part.CFrame = opts.CFrame or CFrame.new()
	part.Color = if type(opts.Color) == "string" then Common.hex(opts.Color) else (opts.Color or Color3.fromRGB(200, 200, 200))
	part.Material = opts.Material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if opts.Shape then
		part.Shape = opts.Shape
	end
	if opts.Transparency then
		part.Transparency = opts.Transparency
	end
	if opts.CanCollide ~= nil then
		part.CanCollide = opts.CanCollide
	end
	if opts.CanQuery ~= nil then
		part.CanQuery = opts.CanQuery
	end
	if opts.CanTouch ~= nil then
		part.CanTouch = opts.CanTouch
	end
	if opts.CastShadow ~= nil then
		part.CastShadow = opts.CastShadow
	end
	for _, tag in opts.Tags or {} do
		part:AddTag(tag)
	end
	for key, value in opts.Attributes or {} do
		part:SetAttribute(key, value)
	end
	part.Parent = opts.Parent
	return part
end

function Common.folder(name, parent)
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

function Common.model(name, parent)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	return model
end

-- World label rendered by the client (see Client/Controllers/WorldLabelController)
function Common.label(part, text, opts)
	opts = opts or {}
	part:AddTag("WorldLabel")
	part:SetAttribute("LabelText", text)
	part:SetAttribute("LabelColor", opts.Color or "#FFFFFF")
	part:SetAttribute("LabelFace", opts.Face or "Front")
	if opts.Subtext then
		part:SetAttribute("LabelSubtext", opts.Subtext)
	end
	if opts.Billboard then
		part:SetAttribute("LabelBillboard", true)
	end
end

-- Axis-aligned bounds of all BaseParts under an instance
function Common.bounds(root)
	local lo = Vector3.new(math.huge, math.huge, math.huge)
	local hi = Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			local p = d.CFrame.Position
			local s = d.Size
			local _, ry = d.CFrame:ToOrientation()
			local sx, sz = s.X, s.Z
			local deg = math.abs(math.deg(ry))
			if deg > 45 and deg < 135 then
				sx, sz = s.Z, s.X
			end
			lo = Vector3.new(math.min(lo.X, p.X - sx / 2), math.min(lo.Y, p.Y - s.Y / 2), math.min(lo.Z, p.Z - sz / 2))
			hi = Vector3.new(math.max(hi.X, p.X + sx / 2), math.max(hi.Y, p.Y + s.Y / 2), math.max(hi.Z, p.Z + sz / 2))
		end
	end
	return lo, hi
end

function Common.center(root)
	local lo, hi = Common.bounds(root)
	return (lo + hi) / 2
end

return Common
