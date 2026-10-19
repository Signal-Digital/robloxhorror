--[[
	AnimatronicBuilder — builds the 4 original mascots out of parts.
	Each model = invisible HumanoidRootPart + Humanoid (HipHeight rig, no joints)
	+ welded body parts. Legs/arms use Welds so the server can swing them.
	Front of the model is -Z (LookVector).
]]

local AnimatronicBuilder = {}

local M = Enum.Material
local C = Color3.fromRGB

local HIP = 3 -- distance between ground and the bottom of the root part
local ROOT_SIZE = Vector3.new(3, 4, 2)

local function newPart(model, name, size, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or M.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.CanCollide = false
	p.CanTouch = false
	p.Massless = true
	p.Anchored = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

-- weld `p` to `base` at local offset
local function attach(base: BasePart, p: BasePart, offset: CFrame)
	p.CFrame = base.CFrame * offset
	local w = Instance.new("Weld")
	w.Name = "Weld"
	w.Part0 = base
	w.Part1 = p
	w.C0 = offset
	w.Parent = p
	return w
end

local function add(model, base, name, size, offset, color, material, shape)
	local p = newPart(model, name, size, color, material, shape)
	local w = attach(base, p, offset)
	return p, w
end

local VERT = CFrame.Angles(0, 0, math.rad(90)) -- cylinders standing up

-- A limb hangs from a pivot: C0 = pivot * swing * down(len/2)
local function limb(model, root, name, size, pivot: CFrame, color, material)
	local p, w = add(model, root, name, size, pivot * CFrame.new(0, -size.Y / 2, 0), color, material)
	w:SetAttribute("Pivot", pivot :: any)
	w:SetAttribute("Length", size.Y)
	return p, w
end

local function eye(model, head, x, y, z, iris: Color3, size: number?)
	local s = size or 0.8
	add(model, head, "EyeWhite", Vector3.new(s, s, s), CFrame.new(x, y, z), C(245, 245, 235), M.SmoothPlastic, Enum.PartType.Ball)
	local pupil = add(model, head, "Pupil", Vector3.new(s * 0.45, s * 0.45, s * 0.45), CFrame.new(x, y, z - s * 0.38), iris, M.Neon, Enum.PartType.Ball)
	local light = Instance.new("PointLight")
	light.Color = iris
	light.Range = 6
	light.Brightness = 1.5
	light.Parent = pupil
	return pupil
end

local function base(name: string)
	local model = Instance.new("Model")
	model.Name = name
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = ROOT_SIZE
	root.Transparency = 1
	root.CanCollide = true
	root.Anchored = false
	root.TopSurface = Enum.SurfaceType.Smooth
	root.BottomSurface = Enum.SurfaceType.Smooth
	root.Parent = model
	model.PrimaryPart = root

	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R15
	hum.HipHeight = HIP
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.MaxHealth = math.huge
	hum.Health = math.huge
	hum.BreakJointsOnDeath = false
	hum.RequiresNeck = false
	hum.Parent = model
	return model, root, hum
end

-- root center sits 5 studs above the ground: ground = -5 in root space
local function legsAndFeet(model, root, legColor, footColor, legSize)
	local ls = legSize or Vector3.new(1.5, 3.2, 1.5)
	local legs = {}
	for _, sx in { -0.9, 0.9 } do
		local leg, w = limb(model, root, "Leg", ls, CFrame.new(sx, -1.8, 0), legColor, M.Fabric)
		table.insert(legs, w)
		-- the foot is welded to the leg so it swings with it
		add(model, leg, "Foot", Vector3.new(ls.X + 0.3, 0.6, ls.Z + 0.9), CFrame.new(0, -ls.Y / 2 + 0.2, -0.4), footColor, M.Fabric)
	end
	return legs
end

local function arms(model, root, color, size, shoulderY, shoulderX)
	local out = {}
	for _, sx in { -shoulderX, shoulderX } do
		local _, w = limb(model, root, "Arm", size, CFrame.new(sx, shoulderY, 0), color, M.Fabric)
		table.insert(out, w)
		add(model, w.Part1 :: BasePart, "Hand", Vector3.new(size.X + 0.2, 0.9, size.Z + 0.2), CFrame.new(0, -size.Y / 2, 0), color, M.Fabric)
	end
	return out
end

local function bowTie(model, torso, y, z, color)
	add(model, torso, "Bow", Vector3.new(0.8, 0.8, 0.3), CFrame.new(-0.5, y, z) * CFrame.Angles(0, 0, math.rad(45)), color)
	add(model, torso, "Bow", Vector3.new(0.8, 0.8, 0.3), CFrame.new(0.5, y, z) * CFrame.Angles(0, 0, math.rad(45)), color)
	add(model, torso, "Bow", Vector3.new(0.4, 0.4, 0.35), CFrame.new(0, y, z), color)
end

------------------------------------------------------------------------------
local Builders = {}

function Builders.Bruno()
	local model, root, hum = base("Bruno")
	local fur, belly = C(140, 85, 45), C(205, 160, 110)
	local torso = add(model, root, "Torso", Vector3.new(3.8, 4.6, 2.6), CFrame.new(0, 0.3, 0), fur, M.Fabric)
	add(model, torso, "Belly", Vector3.new(2.6, 3, 0.2), CFrame.new(0, -0.3, -1.3), belly, M.Fabric)
	bowTie(model, torso, 2, -1.35, C(30, 30, 30))
	local legs = legsAndFeet(model, root, fur, C(110, 65, 35))
	local armWelds = arms(model, root, fur, Vector3.new(1.3, 3.8, 1.3), 2.1, 2.6)
	local head, headWeld = add(model, root, "Head", Vector3.new(3.2, 2.8, 2.8), CFrame.new(0, 4, 0), fur, M.Fabric)
	add(model, head, "Snout", Vector3.new(1.8, 1.1, 1), CFrame.new(0, -0.4, -1.6), belly, M.Fabric)
	add(model, head, "Nose", Vector3.new(0.7, 0.45, 0.3), CFrame.new(0, -0.1, -2.15), C(20, 20, 20))
	add(model, head, "Jaw", Vector3.new(1.7, 0.5, 1.1), CFrame.new(0, -1.25, -1.4), C(90, 50, 30), M.Fabric)
	for _, sx in { -1.25, 1.25 } do
		add(model, head, "Ear", Vector3.new(1.1, 1.1, 0.6), CFrame.new(sx, 1.5, 0), fur, M.Fabric, Enum.PartType.Ball)
		add(model, head, "EarIn", Vector3.new(0.6, 0.6, 0.3), CFrame.new(sx, 1.5, -0.25), belly, M.Fabric, Enum.PartType.Ball)
	end
	eye(model, head, -0.7, 0.45, -1.35, C(255, 60, 40))
	eye(model, head, 0.7, 0.45, -1.35, C(255, 60, 40))
	-- top hat
	add(model, head, "HatBrim", Vector3.new(0.2, 2.4, 2.4), CFrame.new(0, 1.5, 0) * VERT, C(20, 20, 20), M.SmoothPlastic, Enum.PartType.Cylinder)
	add(model, head, "Hat", Vector3.new(1.6, 1.6, 1.6), CFrame.new(0, 2.4, 0) * VERT, C(20, 20, 20), M.SmoothPlastic, Enum.PartType.Cylinder)
	add(model, head, "HatBand", Vector3.new(0.3, 1.65, 1.65), CFrame.new(0, 1.8, 0) * VERT, C(150, 20, 35), M.SmoothPlastic, Enum.PartType.Cylinder)
	-- microphone in hand
	add(model, armWelds[2].Part1 :: BasePart, "Mic", Vector3.new(0.35, 1.4, 0.35), CFrame.new(0, -1.9, -0.5) * CFrame.Angles(math.rad(70), 0, 0), C(40, 40, 40), M.Metal)
	return model, { Legs = legs, Arms = armWelds, Head = headWeld }, hum
end

function Builders.Maple()
	local model, root, hum = base("Maple")
	local fur, light = C(170, 120, 70), C(225, 195, 150)
	local torso = add(model, root, "Torso", Vector3.new(4, 4.8, 2.8), CFrame.new(0, 0.4, 0), fur, M.Fabric)
	add(model, torso, "Belly", Vector3.new(2.6, 3.2, 0.2), CFrame.new(0, -0.3, -1.4), light, M.Fabric)
	-- plaid scarf
	add(model, torso, "Scarf", Vector3.new(4.2, 0.8, 3), CFrame.new(0, 2.2, 0), C(180, 30, 40), M.Fabric)
	add(model, torso, "ScarfTail", Vector3.new(0.8, 2, 0.3), CFrame.new(1, 1.2, -1.55), C(180, 30, 40), M.Fabric)
	-- bell (she jingles!)
	add(model, torso, "Bell", Vector3.new(0.9, 0.9, 0.9), CFrame.new(0, 1.4, -1.6), C(255, 200, 50), M.Metal, Enum.PartType.Ball)
	local legs = legsAndFeet(model, root, fur, C(60, 40, 25), Vector3.new(1.4, 3.2, 1.4))
	local armWelds = arms(model, root, fur, Vector3.new(1.2, 4, 1.2), 2.2, 2.7)
	local head, headWeld = add(model, root, "Head", Vector3.new(2.8, 2.6, 2.6), CFrame.new(0, 4.2, 0), fur, M.Fabric)
	add(model, head, "Muzzle", Vector3.new(2.2, 1.6, 2), CFrame.new(0, -0.5, -1.8), light, M.Fabric)
	add(model, head, "Nose", Vector3.new(0.9, 0.5, 0.3), CFrame.new(0, -0.1, -2.85), C(60, 30, 25))
	add(model, head, "Jaw", Vector3.new(2, 0.5, 1.6), CFrame.new(0, -1.4, -1.8), C(120, 80, 50), M.Fabric)
	-- blindfold instead of eyes
	add(model, head, "Blindfold", Vector3.new(3, 0.7, 2.8), CFrame.new(0, 0.5, 0), C(235, 235, 225), M.Fabric)
	for _, sx in { -0.65, 0.65 } do
		add(model, head, "Stitch", Vector3.new(0.6, 0.12, 0.1), CFrame.new(sx, 0.5, -1.42) * CFrame.Angles(0, 0, math.rad(45)), C(150, 20, 30))
		add(model, head, "Stitch", Vector3.new(0.6, 0.12, 0.1), CFrame.new(sx, 0.5, -1.42) * CFrame.Angles(0, 0, math.rad(-45)), C(150, 20, 30))
	end
	-- antlers
	for _, side in { -1, 1 } do
		local antler = C(235, 215, 170)
		add(model, head, "Antler", Vector3.new(0.4, 2.2, 0.4), CFrame.new(side * 1.1, 2, 0) * CFrame.Angles(0, 0, math.rad(-side * 25)), antler)
		add(model, head, "Antler", Vector3.new(2.6, 0.5, 1.4), CFrame.new(side * 2.1, 3, 0), antler)
		for k = 0, 2 do
			add(model, head, "Antler", Vector3.new(0.35, 1.2, 0.35), CFrame.new(side * (1.3 + k * 0.6), 3.7, 0), antler)
		end
		add(model, head, "Ear", Vector3.new(0.5, 1.2, 0.5), CFrame.new(side * 1.5, 0.9, 0.3) * CFrame.Angles(0, 0, math.rad(side * 60)), fur, M.Fabric)
	end
	return model, { Legs = legs, Arms = armWelds, Head = headWeld }, hum
end

function Builders.Pip()
	local model, root, hum = base("Pip")
	local black, white, orange = C(30, 35, 55), C(240, 240, 245), C(255, 150, 30)
	local torso = add(model, root, "Torso", Vector3.new(4.2, 5, 3.2), CFrame.new(0, 0.2, 0), black, M.Fabric)
	add(model, torso, "Belly", Vector3.new(3.2, 4.2, 0.2), CFrame.new(0, -0.2, -1.6), white, M.Fabric)
	bowTie(model, torso, 2.1, -1.7, C(0, 150, 255))
	local legs = legsAndFeet(model, root, black, orange, Vector3.new(1.3, 3.2, 1.3))
	local armWelds = arms(model, root, black, Vector3.new(0.8, 3.6, 1.8), 2.2, 2.5)
	local head, headWeld = add(model, root, "Head", Vector3.new(3.4, 3, 3), CFrame.new(0, 4.2, 0), black, M.Fabric)
	add(model, head, "Face", Vector3.new(2.8, 2.2, 0.2), CFrame.new(0, -0.1, -1.5), white, M.Fabric)
	add(model, head, "Beak", Vector3.new(1.4, 0.6, 1.6), CFrame.new(0, -0.4, -2.2), orange)
	add(model, head, "Jaw", Vector3.new(1.2, 0.35, 1.3), CFrame.new(0, -0.85, -2.05), C(220, 110, 20))
	-- huge staring eyes
	eye(model, head, -0.75, 0.4, -1.6, C(0, 200, 255), 1.1)
	eye(model, head, 0.75, 0.4, -1.6, C(0, 200, 255), 1.1)
	-- party hat (stacked cylinders)
	local hatColors = { C(255, 80, 160), C(255, 220, 60), C(255, 80, 160) }
	for i = 0, 2 do
		add(model, head, "PartyHat", Vector3.new(0.7, 1.5 - i * 0.45, 1.5 - i * 0.45), CFrame.new(0.3, 1.85 + i * 0.65, 0) * VERT * CFrame.Angles(0, 0, 0),
			hatColors[i + 1], M.SmoothPlastic, Enum.PartType.Cylinder)
	end
	add(model, head, "Pompom", Vector3.new(0.5, 0.5, 0.5), CFrame.new(0.3, 3.65, 0), C(255, 255, 255), M.Fabric, Enum.PartType.Ball)
	return model, { Legs = legs, Arms = armWelds, Head = headWeld }, hum
end

function Builders.Jinx()
	local model, root, hum = base("Jinx")
	local purple, yellow, mask = C(110, 50, 160), C(250, 200, 40), C(245, 240, 235)
	local torso = add(model, root, "Torso", Vector3.new(2.8, 5.2, 2), CFrame.new(0, 0.6, 0), purple, M.Fabric)
	add(model, torso, "Half", Vector3.new(1.4, 5.21, 2.01), CFrame.new(0.7, 0, 0), yellow, M.Fabric)
	for i = 0, 2 do
		add(model, torso, "Button", Vector3.new(0.45, 0.45, 0.45), CFrame.new(0, 1.2 - i * 1.2, -1), C(20, 20, 20), M.SmoothPlastic, Enum.PartType.Ball)
	end
	-- ruffled collar
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		add(model, torso, "Ruffle", Vector3.new(1.2, 0.5, 1.2), CFrame.new(math.cos(a) * 1.4, 2.7, math.sin(a) * 1.1) * CFrame.Angles(0, -a, math.rad(20)),
			(i % 2 == 0) and purple or yellow, M.Fabric)
	end
	local legs = legsAndFeet(model, root, purple, yellow, Vector3.new(1, 3.2, 1))
	-- extra-long arms
	local armWelds = arms(model, root, yellow, Vector3.new(0.8, 5.5, 0.8), 2.6, 1.9)
	local head, headWeld = add(model, root, "Head", Vector3.new(2.6, 3, 2.4), CFrame.new(0, 5.2, 0), mask, M.SmoothPlastic)
	add(model, head, "Socket", Vector3.new(0.8, 1, 0.2), CFrame.new(-0.6, 0.4, -1.15), C(5, 5, 5))
	add(model, head, "Socket", Vector3.new(0.8, 1, 0.2), CFrame.new(0.6, 0.4, -1.15), C(5, 5, 5))
	for _, sx in { -0.6, 0.6 } do
		local pupil = add(model, head, "Pupil", Vector3.new(0.25, 0.25, 0.25), CFrame.new(sx, 0.4, -1.28), C(255, 255, 255), M.Neon, Enum.PartType.Ball)
		pupil.Name = "Pupil"
		local l = Instance.new("PointLight")
		l.Color = C(255, 255, 255)
		l.Range = 5
		l.Parent = pupil
	end
	add(model, head, "Smile", Vector3.new(1.9, 0.25, 0.2), CFrame.new(0, -0.7, -1.15), C(200, 20, 30))
	for _, sx in { -1, 1 } do
		add(model, head, "SmileEnd", Vector3.new(0.6, 0.25, 0.2), CFrame.new(sx * 1.05, -0.45, -1.15) * CFrame.Angles(0, 0, math.rad(sx * 40)), C(200, 20, 30))
		add(model, head, "Cheek", Vector3.new(0.5, 0.5, 0.15), CFrame.new(sx * 0.9, -0.1, -1.16), C(255, 120, 150), M.SmoothPlastic, Enum.PartType.Ball)
	end
	add(model, head, "Jaw", Vector3.new(1.6, 0.4, 0.4), CFrame.new(0, -1.1, -1), mask)
	-- jester hat
	add(model, head, "HatBase", Vector3.new(2.8, 0.8, 2.6), CFrame.new(0, 1.7, 0), purple, M.Fabric)
	for _, side in { -1, 1 } do
		add(model, head, "HatProng", Vector3.new(0.9, 2.6, 0.9), CFrame.new(side * 1.3, 2.8, 0) * CFrame.Angles(0, 0, math.rad(-side * 40)),
			side < 0 and purple or yellow, M.Fabric)
		add(model, head, "HatBell", Vector3.new(0.6, 0.6, 0.6), CFrame.new(side * 2.3, 3.5, 0), yellow, M.Metal, Enum.PartType.Ball)
	end
	return model, { Legs = legs, Arms = armWelds, Head = headWeld }, hum
end

function AnimatronicBuilder.Build(name: string)
	local builder = Builders[name]
	assert(builder, "Unknown animatronic " .. tostring(name))
	local model, rig, hum = builder()
	hum.WalkSpeed = 10
	hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	hum:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
	hum:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
	hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CollisionGroup = "Animatronics"
		end
	end
	return model, rig
end

-- Static (anchored) copy for jumpscares / UI viewports
function AnimatronicBuilder.Template(name: string)
	local model = AnimatronicBuilder.Build(name)
	model:PivotTo(CFrame.new(0, 5, 0))
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		elseif d:IsA("Humanoid") then
			d:Destroy()
		end
	end
	return model
end

return AnimatronicBuilder
