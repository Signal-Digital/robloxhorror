--[[
	MapBuilder — generates the whole 3D world from code (no external assets):
	  * "Pip's Party Palace" pizzeria: 11 rooms (dining hall + stage, arcade, kitchen,
	    parts & service, backstage, security office, restrooms, halls, closet, entrance)
	  * the parking-lot lobby in front of it (neon sign, cars, lamps, prize counter...)
	Returns a "map" table used by the other services.
]]

local CollectionService = game:GetService("CollectionService")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local MapBuilder = {}

local H = 18 -- wall height
local DOOR_H = 11
local WALL_T = 1

local M = Enum.Material
local C = Color3.fromRGB

local PALETTE = {
	WallUpper = C(38, 52, 68),
	WallLower = C(125, 32, 40),
	Trim = C(225, 175, 60),
	DoorFrame = C(45, 30, 25),
	Ceiling = C(70, 70, 78),
	CheckA = C(235, 235, 235),
	CheckB = C(25, 25, 30),
	LightOn = C(255, 220, 170),
	LightOff = C(60, 60, 60),
}

-- Rooms (x1, x2, z1, z2) -------------------------------------------------
local ROOMS = {
	Entrance = { -14, 14, -50, -30, Floor = "Checker", Display = "Entrance" },
	Dining = { -40, 40, -30, 30, Floor = "Checker", Display = "Dining Hall" },
	WestHall = { -54, -40, -30, 30, Floor = "Checker", Display = "West Hall" },
	EastHall = { 40, 54, -30, 30, Floor = "Checker", Display = "East Hall" },
	Arcade = { -100, -54, 0, 30, Floor = "Carpet", Display = "Arcade" },
	Restrooms = { -80, -54, -30, 0, Floor = "Tile", Display = "Restrooms" },
	Kitchen = { 54, 96, 0, 30, Floor = "RedTile", Display = "Kitchen" },
	Parts = { 54, 90, -30, 0, Floor = "Concrete", Display = "Parts & Service" },
	Backstage = { -40, 8, 30, 50, Floor = "Wood", Display = "Backstage" },
	Security = { 8, 32, 30, 50, Floor = "Office", Display = "Security Office" },
	Closet = { 32, 54, 30, 50, Floor = "Concrete", Display = "Supply Closet" },
}

-- Walls: axis, fixed coordinate, from, to, doors {center, width}
local WALLS = {
	{ "X", -50, -14, 14, { { 0, 10 } } },
	{ "X", -30, -80, 90, { { 0, 12 } } },
	{ "Z", -14, -50, -30, {} },
	{ "Z", 14, -50, -30, {} },
	{ "X", 0, -100, -54, {} },
	{ "X", 0, 54, 96, {} },
	{ "Z", -80, -30, 0, {} },
	{ "Z", -100, 0, 30, {} },
	{ "Z", -54, -30, 30, { { -15, 8 }, { 15, 10 } } },
	{ "Z", -40, -30, 30, { { 0, 10 } } },
	{ "Z", 40, -30, 30, { { 0, 10 } } },
	{ "Z", 54, -30, 30, { { -15, 8 }, { 15, 10 } } },
	{ "Z", 90, -30, 0, {} },
	{ "Z", 96, 0, 30, {} },
	{ "X", 30, -100, 96, { { -30, 8 }, { 24, 8 }, { 47, 8 } } },
	{ "X", 50, -40, 54, {} },
	{ "Z", -40, 30, 50, {} },
	{ "Z", 8, 30, 50, { { 40, 8 } } },
	{ "Z", 32, 30, 50, { { 40, 8 } } },
	{ "Z", 54, 30, 50, {} },
}

-- Fuse box candidates: position, facing, rooms it powers
local FUSE_SPOTS = {
	{ Vector3.new(-39.3, 5, -20), Vector3.new(1, 0, 0), { "Dining", "Entrance" } },
	{ Vector3.new(-99.3, 5, 22), Vector3.new(1, 0, 0), { "Arcade", "WestHall" } },
	{ Vector3.new(-62, 5, -29.3), Vector3.new(0, 0, 1), { "Restrooms" } },
	{ Vector3.new(80, 5, 0.7), Vector3.new(0, 0, 1), { "Kitchen", "EastHall" } },
	{ Vector3.new(89.3, 5, -4), Vector3.new(-1, 0, 0), { "Parts" } },
	{ Vector3.new(-39.3, 5, 36), Vector3.new(1, 0, 0), { "Backstage" } },
	{ Vector3.new(45, 5, 49.3), Vector3.new(0, 0, -1), { "Closet", "Security" } },
}

local LOCKER_SPOTS = {
	{ Vector3.new(-41.8, 0, -24), Vector3.new(1, 0, 0) },
	{ Vector3.new(-41.8, 0, 24), Vector3.new(1, 0, 0) },
	{ Vector3.new(52.2, 0, -25), Vector3.new(-1, 0, 0) },
	{ Vector3.new(52.2, 0, 0), Vector3.new(-1, 0, 0) },
	{ Vector3.new(52.2, 0, 25), Vector3.new(-1, 0, 0) },
	{ Vector3.new(94.2, 0, 25), Vector3.new(-1, 0, 0) },
	{ Vector3.new(-98.2, 0, 5), Vector3.new(1, 0, 0) },
	{ Vector3.new(-78.2, 0, -25), Vector3.new(1, 0, 0) },
	{ Vector3.new(-38.2, 0, 46), Vector3.new(1, 0, 0) },
	{ Vector3.new(52.2, 0, 45), Vector3.new(-1, 0, 0) },
	{ Vector3.new(88.2, 0, -25), Vector3.new(-1, 0, 0) },
	{ Vector3.new(-38.2, 0, -27), Vector3.new(1, 0, 0) },
	{ Vector3.new(38.2, 0, -27), Vector3.new(-1, 0, 0) },
}

------------------------------------------------------------------------------
-- Generic helpers
------------------------------------------------------------------------------
local function part(parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, name: string?)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or M.SmoothPlastic
	p.Name = name or "Part"
	p.Parent = parent
	return p
end

local function ball(parent, diameter, pos, color, material)
	local p = part(parent, Vector3.new(diameter, diameter, diameter), CFrame.new(pos), color, material, "Ball")
	p.Shape = Enum.PartType.Ball
	return p
end

-- Vertical cylinder (Roblox cylinders run along X, so rotate 90°)
local function cyl(parent, height, diameter, pos, color, material)
	local p = part(parent, Vector3.new(height, diameter, diameter), CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), color, material, "Cylinder")
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function deco(p: BasePart)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
end

local function folder(name, parent)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function facing(pos: Vector3, dir: Vector3): CFrame
	return CFrame.lookAt(pos, pos + dir)
end

-- Text on the Front face (-Z) of a part
local function sign(p: BasePart, text: string, textColor: Color3, opts: { [string]: any }?)
	opts = opts or {}
	local sg = Instance.new("SurfaceGui")
	sg.Face = opts.Face or Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = opts.PPS or 40
	sg.LightInfluence = opts.Glow and 0 or 1
	sg.Brightness = opts.Glow and 2 or 1
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = opts.Bg and 0 or 1
	label.BackgroundColor3 = opts.Bg or Color3.new()
	label.Text = text
	label.TextColor3 = textColor
	label.TextScaled = true
	label.Font = opts.Font or Enum.Font.FredokaOne
	label.TextStrokeTransparency = opts.Stroke and 0 or 1
	label.TextStrokeColor3 = opts.StrokeColor or Color3.new()
	label.Parent = sg
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.04, 0)
	pad.PaddingRight = UDim.new(0.04, 0)
	pad.PaddingTop = UDim.new(0.06, 0)
	pad.PaddingBottom = UDim.new(0.06, 0)
	pad.Parent = label
	sg.Parent = p
	return sg, label
end

local function prompt(parent: Instance, action: string, object: string, hold: number, distance: number?)
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = action
	pp.ObjectText = object
	pp.HoldDuration = hold
	pp.MaxActivationDistance = distance or 9
	pp.RequiresLineOfSight = false
	pp.Parent = parent
	return pp
end

------------------------------------------------------------------------------
-- Structure
------------------------------------------------------------------------------
local function buildWallSpan(parent, axis, fixed, a, b, y0, y1)
	local len = b - a
	if len <= 0.05 or y1 - y0 <= 0.05 then
		return
	end
	local function piece(ya, yb, color, mat)
		if yb - ya <= 0.01 then
			return
		end
		local cy = (ya + yb) / 2
		local size, pos
		if axis == "X" then
			size = Vector3.new(len, yb - ya, WALL_T)
			pos = Vector3.new((a + b) / 2, cy, fixed)
		else
			size = Vector3.new(WALL_T, yb - ya, len)
			pos = Vector3.new(fixed, cy, (a + b) / 2)
		end
		part(parent, size, CFrame.new(pos), color, mat, "Wall")
	end
	-- wainscot / trim / upper wall layering
	piece(y0, math.min(y1, 4), PALETTE.WallLower, M.SmoothPlastic)
	piece(math.max(y0, 4), math.min(y1, 4.6), PALETTE.Trim, M.SmoothPlastic)
	piece(math.max(y0, 4.6), y1, PALETTE.WallUpper, M.Plaster)
end

local function doorFrame(parent, axis, fixed, center, width)
	local t = WALL_T + 0.6
	for _, side in { -1, 1 } do
		local c = center + side * (width / 2 + 0.3)
		local pos = axis == "X" and Vector3.new(c, DOOR_H / 2, fixed) or Vector3.new(fixed, DOOR_H / 2, c)
		local size = axis == "X" and Vector3.new(0.6, DOOR_H, t) or Vector3.new(t, DOOR_H, 0.6)
		deco(part(parent, size, CFrame.new(pos), PALETTE.DoorFrame, M.Wood, "DoorFrame"))
	end
	local pos = axis == "X" and Vector3.new(center, DOOR_H + 0.3, fixed) or Vector3.new(fixed, DOOR_H + 0.3, center)
	local size = axis == "X" and Vector3.new(width + 1.2, 0.6, t) or Vector3.new(t, 0.6, width + 1.2)
	deco(part(parent, size, CFrame.new(pos), PALETTE.DoorFrame, M.Wood, "DoorFrame"))
end

local function buildWall(parent, def)
	local axis, fixed, from, to, doors = def[1], def[2], def[3] - 0.5, def[4] + 0.5, def[5]
	table.sort(doors, function(x, y)
		return x[1] < y[1]
	end)
	local cursor = from
	for _, d in doors do
		local d0, d1 = d[1] - d[2] / 2, d[1] + d[2] / 2
		buildWallSpan(parent, axis, fixed, cursor, d0, 0, H)
		buildWallSpan(parent, axis, fixed, d0, d1, DOOR_H, H) -- lintel
		doorFrame(parent, axis, fixed, d[1], d[2])
		cursor = d1
	end
	buildWallSpan(parent, axis, fixed, cursor, to, 0, H)
end

local FLOOR_STYLES = {
	Checker = { Tile = 5, A = PALETTE.CheckA, B = PALETTE.CheckB, Mat = M.SmoothPlastic },
	Tile = { Tile = 3, A = C(220, 225, 230), B = C(180, 190, 200), Mat = M.SmoothPlastic },
	RedTile = { Tile = 4, A = C(170, 40, 40), B = C(230, 230, 230), Mat = M.SmoothPlastic },
	Carpet = { Color = C(45, 20, 70), Mat = M.Fabric },
	Concrete = { Color = C(95, 95, 100), Mat = M.Concrete },
	Wood = { Color = C(90, 60, 40), Mat = M.WoodPlanks },
	Office = { Color = C(50, 60, 80), Mat = M.Fabric },
}

local function buildFloor(parent, room)
	local x1, x2, z1, z2 = room[1], room[2], room[3], room[4]
	local style = FLOOR_STYLES[room.Floor]
	if style.Tile then
		local nx = math.max(1, math.round((x2 - x1) / style.Tile))
		local nz = math.max(1, math.round((z2 - z1) / style.Tile))
		local tx, tz = (x2 - x1) / nx, (z2 - z1) / nz
		for i = 0, nx - 1 do
			for j = 0, nz - 1 do
				local color = ((i + j) % 2 == 0) and style.A or style.B
				part(parent, Vector3.new(tx, 1, tz), CFrame.new(x1 + tx * (i + 0.5), -0.5, z1 + tz * (j + 0.5)), color, style.Mat, "Floor")
			end
		end
	else
		part(parent, Vector3.new(x2 - x1, 1, z2 - z1), CFrame.new((x1 + x2) / 2, -0.5, (z1 + z2) / 2), style.Color, style.Mat, "Floor")
	end
end

------------------------------------------------------------------------------
-- Props
------------------------------------------------------------------------------
local function partyTable(parent, center: Vector3, length: number)
	local top = part(parent, Vector3.new(4.4, 0.4, length), CFrame.new(center + Vector3.new(0, 3, 0)), C(245, 245, 245), M.Fabric, "Table")
	-- red runner
	deco(part(parent, Vector3.new(1.4, 0.05, length), CFrame.new(center + Vector3.new(0, 3.22, 0)), C(200, 40, 50), M.Fabric))
	for _, sx in { -1.8, 1.8 } do
		for _, sz in { -length / 2 + 0.6, length / 2 - 0.6 } do
			part(parent, Vector3.new(0.4, 2.8, 0.4), CFrame.new(center + Vector3.new(sx, 1.4, sz)), C(60, 60, 60), M.Metal)
		end
	end
	local colors = { C(255, 80, 80), C(80, 180, 255), C(255, 210, 60), C(120, 230, 120), C(220, 110, 255) }
	local n = math.floor(length / 3.2)
	for k = 0, n - 1 do
		local z = -length / 2 + 1.6 + k * 3.2
		for _, sx in { -3.2, 3.2 } do
			-- chair
			part(parent, Vector3.new(1.6, 0.3, 1.6), CFrame.new(center + Vector3.new(sx, 1.8, z)), colors[(k % #colors) + 1], M.SmoothPlastic, "Chair")
			deco(part(parent, Vector3.new(0.3, 1.8, 0.3), CFrame.new(center + Vector3.new(sx, 0.9, z)), C(60, 60, 60), M.Metal))
			-- plate + party hat
			deco(cyl(parent, 0.1, 1.2, center + Vector3.new(sx * 0.42, 3.25, z), C(255, 255, 255)))
			if k % 2 == 0 then
				local hc = colors[((k + 2) % #colors) + 1]
				deco(cyl(parent, 0.5, 0.8, center + Vector3.new(sx * 0.42, 3.55, z + 0.6), hc))
				deco(cyl(parent, 0.5, 0.45, center + Vector3.new(sx * 0.42, 4.05, z + 0.6), hc))
				deco(ball(parent, 0.3, center + Vector3.new(sx * 0.42, 4.4, z + 0.6), C(255, 255, 255)))
			end
		end
		if k % 3 == 1 then
			-- pizza!
			deco(cyl(parent, 0.15, 2.2, center + Vector3.new(0, 3.3, z), C(230, 160, 60)))
			deco(cyl(parent, 0.05, 1.9, center + Vector3.new(0, 3.4, z), C(200, 50, 30)))
		end
	end
	-- balloons
	for b = 1, 3 do
		local off = Vector3.new((b - 2) * 1.1, 0, length / 2 - 0.5)
		local base = center + off + Vector3.new(0, 3.2, 0)
		local top3 = base + Vector3.new(0, 5 + b * 0.6, 0)
		deco(part(parent, Vector3.new(0.08, (top3 - base).Magnitude, 0.08), CFrame.new((base + top3) / 2), C(240, 240, 240)))
		local bl = deco(ball(parent, 1.8, top3 + Vector3.new(0, 0.9, 0), colors[b + 1], M.SmoothPlastic))
		bl.Reflectance = 0.15
	end
	return top
end

local function arcadeMachine(parent, pos: Vector3, dir: Vector3, title: string, color: Color3)
	local cf = facing(pos, dir)
	local body = part(parent, Vector3.new(3, 7, 2.6), cf * CFrame.new(0, 3.5, 0), C(25, 25, 30), M.SmoothPlastic, "Arcade")
	deco(part(parent, Vector3.new(3.1, 0.25, 2.7), cf * CFrame.new(0, 6.9, 0), color, M.Neon))
	deco(part(parent, Vector3.new(0.15, 7, 2.7), cf * CFrame.new(-1.55, 3.5, 0), color, M.Neon))
	deco(part(parent, Vector3.new(0.15, 7, 2.7), cf * CFrame.new(1.55, 3.5, 0), color, M.Neon))
	local screen = deco(part(parent, Vector3.new(2.4, 1.8, 0.1), cf * CFrame.new(0, 4.6, -1.31), C(10, 10, 20), M.Neon, "Screen"))
	sign(screen, title, color, { Glow = true, Bg = C(10, 10, 25), Stroke = true })
	local marquee = deco(part(parent, Vector3.new(2.8, 0.8, 0.1), cf * CFrame.new(0, 6.3, -1.31), color, M.SmoothPlastic))
	sign(marquee, "★ " .. title .. " ★", C(255, 255, 255), { Glow = true })
	deco(part(parent, Vector3.new(2.8, 0.3, 1), cf * CFrame.new(0, 3.3, -1.6), C(40, 40, 50), M.SmoothPlastic))
	deco(ball(parent, 0.45, (cf * CFrame.new(-0.6, 3.6, -1.7)).Position, C(255, 40, 40)))
	deco(ball(parent, 0.35, (cf * CFrame.new(0.5, 3.55, -1.8)).Position, C(40, 140, 255)))
	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Front
	light.Color = color
	light.Range = 10
	light.Brightness = 1.2
	light.Parent = screen
	return body
end

local function locker(parent, pos: Vector3, dir: Vector3)
	local cf = facing(pos, dir)
	local model = Instance.new("Model")
	model.Name = "Locker"
	local back = part(model, Vector3.new(4, 8, 0.3), cf * CFrame.new(0, 4, 1.35), C(70, 90, 110), M.Metal)
	part(model, Vector3.new(0.3, 8, 3), cf * CFrame.new(-1.85, 4, 0), C(70, 90, 110), M.Metal)
	part(model, Vector3.new(0.3, 8, 3), cf * CFrame.new(1.85, 4, 0), C(70, 90, 110), M.Metal)
	part(model, Vector3.new(4, 0.3, 3), cf * CFrame.new(0, 8, 0), C(70, 90, 110), M.Metal)
	local door = part(model, Vector3.new(3.4, 7.6, 0.2), cf * CFrame.new(0, 4, -1.4), C(85, 110, 135), M.Metal, "Door")
	door.CanCollide = true
	for i = 0, 3 do
		deco(part(model, Vector3.new(2, 0.15, 0.1), cf * CFrame.new(0, 6.6 - i * 0.4, -1.52), C(20, 20, 25), M.Metal))
	end
	deco(part(model, Vector3.new(0.2, 0.8, 0.2), cf * CFrame.new(1.2, 4, -1.6), C(200, 200, 200), M.Metal))
	model.PrimaryPart = back
	local pp = prompt(door, "Hide", "Locker", 0, 7)
	model:SetAttribute("Inside", cf * CFrame.new(0, 3, 0) :: any)
	model:SetAttribute("Outside", cf * CFrame.new(0, 3, -4) :: any)
	CollectionService:AddTag(model, "Locker")
	model.Parent = parent
	return model, pp
end

local function fuseBox(parent, pos: Vector3, dir: Vector3, zone)
	local cf = facing(pos, dir)
	local model = Instance.new("Model")
	model.Name = "FuseBox"
	local box = part(model, Vector3.new(2.6, 3.4, 0.7), cf, C(110, 115, 120), M.DiamondPlate, "Box")
	deco(part(model, Vector3.new(2.2, 0.4, 0.1), cf * CFrame.new(0, 1.2, -0.4), C(240, 200, 30), M.SmoothPlastic))
	local lamp = deco(part(model, Vector3.new(0.5, 0.5, 0.2), cf * CFrame.new(0.8, -1.2, -0.42), C(255, 40, 40), M.Neon, "Lamp"))
	local lever = deco(part(model, Vector3.new(0.3, 1.2, 0.3), cf * CFrame.new(-0.6, -0.4, -0.55) * CFrame.Angles(math.rad(-30), 0, 0), C(30, 30, 30), M.Metal, "Lever"))
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "Sparks"
	sparks.Color = ColorSequence.new(C(255, 220, 120))
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(0.15, 0)
	sparks.Speed = NumberRange.new(6, 12)
	sparks.SpreadAngle = Vector2.new(60, 60)
	sparks.Lifetime = NumberRange.new(0.2, 0.5)
	sparks.Rate = 0
	sparks.Acceleration = Vector3.new(0, -40, 0)
	sparks.Parent = lamp
	local tag = deco(part(model, Vector3.new(2.4, 0.6, 0.1), cf * CFrame.new(0, 2.1, -0.36), C(30, 30, 30)))
	sign(tag, "FUSE " .. table.concat(zone, "/"):upper(), C(255, 220, 80), { Glow = true })
	model.PrimaryPart = box
	local pp = prompt(box, "Repair", "Fuse Box", 2.5, 8)
	pp.Enabled = false
	model.Parent = parent
	return { Model = model, Box = box, Lamp = lamp, Lever = lever, Prompt = pp, Zone = zone, Sparks = sparks }
end

local function shelf(parent, pos: Vector3, dir: Vector3, length: number, items: (BasePart, CFrame) -> ()?)
	local cf = facing(pos, dir)
	for _, sx in { -length / 2 + 0.2, length / 2 - 0.2 } do
		part(parent, Vector3.new(0.3, 8, 2), cf * CFrame.new(sx, 4, 0), C(80, 80, 85), M.Metal)
	end
	for lvl = 0, 3 do
		local board = part(parent, Vector3.new(length, 0.25, 2), cf * CFrame.new(0, 0.8 + lvl * 2.2, 0), C(110, 90, 70), M.Wood)
		if items then
			items(board, cf * CFrame.new(0, 0.8 + lvl * 2.2, 0))
		end
	end
end

local function spareHead(parent, pos: Vector3, rot: number, color: Color3)
	local cf = CFrame.new(pos) * CFrame.Angles(0, rot, 0)
	deco(part(parent, Vector3.new(1.6, 1.4, 1.4), cf, color, M.Fabric))
	deco(ball(parent, 0.45, (cf * CFrame.new(-0.35, 0.2, -0.65)).Position, C(255, 255, 255)))
	deco(ball(parent, 0.45, (cf * CFrame.new(0.35, 0.2, -0.65)).Position, C(255, 255, 255)))
	deco(ball(parent, 0.18, (cf * CFrame.new(-0.35, 0.2, -0.86)).Position, C(10, 10, 10)))
	deco(ball(parent, 0.18, (cf * CFrame.new(0.35, 0.2, -0.86)).Position, C(10, 10, 10)))
end

local function poster(parent, pos: Vector3, dir: Vector3, text: string, bg: Color3, fg: Color3, size: Vector2?)
	local s = size or Vector2.new(5, 6)
	local p = deco(part(parent, Vector3.new(s.X, s.Y, 0.1), facing(pos, dir), bg, M.SmoothPlastic, "Poster"))
	sign(p, text, fg, { Bg = bg, PPS = 30 })
	return p
end

local function lamp(parent, pos: Vector3, color: Color3, range: number, brightness: number)
	local p = deco(part(parent, Vector3.new(4.5, 0.4, 2), CFrame.new(pos), PALETTE.LightOn, M.Neon, "Fixture"))
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = true
	light.Parent = p
	return p, light
end

------------------------------------------------------------------------------
-- Room decoration
------------------------------------------------------------------------------
local function decorateDining(d)
	-- Stage
	local stageColor = C(60, 25, 70)
	part(d, Vector3.new(32, 3, 10), CFrame.new(0, 1.5, 25), stageColor, M.Wood, "Stage")
	for i = 0, 2 do
		part(d, Vector3.new(32, 1 + i, 2), CFrame.new(0, (1 + i) / 2, 14 + 1 + i * 2), stageColor, M.Wood, "Step")
	end
	deco(part(d, Vector3.new(32.2, 0.2, 0.3), CFrame.new(0, 3.05, 20.1), PALETTE.Trim, M.Neon))
	-- Curtains
	for i = 0, 15 do
		local x = -15 + i * 2
		deco(part(d, Vector3.new(2, 14, 0.6), CFrame.new(x, 10, 29.2 - (i % 2) * 0.35), C(150, 20, 35), M.Fabric, "Curtain"))
	end
	for _, side in { -1, 1 } do
		for i = 0, 2 do
			deco(part(d, Vector3.new(1.4, 15, 1), CFrame.new(side * (16.5 - i * 1.2), 10.5, 24 + i * 2), C(130, 15, 30), M.Fabric))
		end
	end
	deco(part(d, Vector3.new(34, 2, 1), CFrame.new(0, 17, 21), C(120, 15, 30), M.Fabric, "Valance"))
	deco(part(d, Vector3.new(34, 0.3, 1.1), CFrame.new(0, 16, 21), PALETTE.Trim, M.Neon))
	local banner = deco(part(d, Vector3.new(22, 3, 0.2), facing(Vector3.new(0, 14.5, 28.7), Vector3.new(0, 0, -1)), C(255, 210, 60), M.SmoothPlastic))
	sign(banner, "PIP & FRIENDS!", C(150, 20, 35), { Bg = C(255, 210, 60) })
	-- stars on curtains
	for i = 1, 14 do
		deco(part(d, Vector3.new(0.6, 0.6, 0.1), CFrame.new(-13 + i * 1.8, 5 + (i * 7 % 6), 28.7) * CFrame.Angles(0, 0, math.rad(45)), C(255, 230, 120), M.Neon))
	end
	-- Party tables
	for _, x in { -28, -14, 14, 28 } do
		for _, z in { -16, 4 } do
			partyTable(d, Vector3.new(x, 0, z), 12)
		end
	end
	-- Prize shelf / birthday corner
	local cake = Vector3.new(34, 0, -24)
	part(d, Vector3.new(6, 3, 4), CFrame.new(cake + Vector3.new(0, 1.5, 0)), C(245, 245, 245), M.Fabric)
	deco(cyl(d, 1.5, 3, cake + Vector3.new(0, 3.75, 0), C(255, 170, 200)))
	deco(cyl(d, 1, 2, cake + Vector3.new(0, 5, 0), C(255, 255, 255)))
	for i = 0, 4 do
		local a = i / 5 * math.pi * 2
		deco(part(d, Vector3.new(0.15, 0.8, 0.15), CFrame.new(cake + Vector3.new(math.cos(a) * 0.6, 5.9, math.sin(a) * 0.6)), C(120, 200, 255), M.SmoothPlastic))
	end
	-- Posters
	poster(d, Vector3.new(-39.4, 9, -12), Vector3.new(1, 0, 0), "BRUNO SAYS:\nALWAYS SMILE!", C(140, 85, 45), C(255, 240, 200))
	poster(d, Vector3.new(-39.4, 9, 16), Vector3.new(1, 0, 0), "LET'S PARTY\nWITH PIP!", C(35, 40, 60), C(120, 220, 255))
	poster(d, Vector3.new(39.4, 9, -12), Vector3.new(-1, 0, 0), "STAFF: WIND\nTHE MUSIC BOX\nEVERY HOUR", C(240, 230, 210), C(120, 20, 20))
	poster(d, Vector3.new(39.4, 9, 16), Vector3.new(-1, 0, 0), "HAVE YOU\nSEEN JINX?", C(120, 60, 170), C(255, 230, 80))
	local welcome = deco(part(d, Vector3.new(24, 3, 0.2), facing(Vector3.new(0, 14, -29.3), Vector3.new(0, 0, 1)), C(30, 30, 40), M.SmoothPlastic))
	sign(welcome, "WHERE FUN NEVER SLEEPS", C(255, 120, 200), { Glow = true, Bg = C(30, 30, 40) })
	-- Stage spotlights (part of dining power)
	local spots = {}
	for i, x in { -10, 0, 10 } do
		local can = deco(part(d, Vector3.new(1.2, 1.6, 1.2), CFrame.new(x, 16.6, 16) * CFrame.Angles(math.rad(-35), 0, 0), C(20, 20, 20), M.Metal, "SpotCan"))
		local sl = Instance.new("SpotLight")
		sl.Face = Enum.NormalId.Bottom
		sl.Angle = 45
		sl.Range = 25
		sl.Brightness = 2
		sl.Color = ({ C(255, 80, 120), C(255, 230, 150), C(80, 160, 255) })[i]
		sl.Parent = can
		table.insert(spots, { can, sl })
	end
	return spots
end

local function decorateArcade(d)
	local games = {
		{ "PIXEL PANIC", C(0, 255, 230) },
		{ "PIP KART", C(255, 60, 200) },
		{ "BEAR BASH", C(255, 160, 30) },
		{ "MOOSE RUN", C(120, 255, 80) },
		{ "STAR BLASTER", C(90, 140, 255) },
		{ "PIZZA DASH", C(255, 80, 60) },
		{ "JESTER JUMP", C(200, 90, 255) },
	}
	for i = 0, 6 do
		local g = games[i + 1]
		arcadeMachine(d, Vector3.new(-95 + i * 5, 0, 27.6), Vector3.new(0, 0, -1), g[1], g[2])
	end
	for i = 0, 3 do
		local g = games[((i + 3) % #games) + 1]
		arcadeMachine(d, Vector3.new(-92 + i * 5, 0, 2.4), Vector3.new(0, 0, 1), g[1], g[2])
	end
	-- Claw machine
	local claw = Vector3.new(-62, 0, 6)
	part(d, Vector3.new(5, 3, 5), CFrame.new(claw + Vector3.new(0, 1.5, 0)), C(220, 40, 60), M.SmoothPlastic)
	local glass = part(d, Vector3.new(5, 5, 5), CFrame.new(claw + Vector3.new(0, 5.5, 0)), C(200, 230, 255), M.Glass)
	glass.Transparency = 0.6
	part(d, Vector3.new(5.2, 0.6, 5.2), CFrame.new(claw + Vector3.new(0, 8.3, 0)), C(255, 210, 60), M.Neon)
	for i = 1, 8 do
		local colors = { C(140, 85, 45), C(35, 40, 60), C(196, 150, 95), C(120, 60, 170) }
		deco(ball(d, 1.2, claw + Vector3.new((i % 3 - 1) * 1.3, 3.6 + (i % 2) * 0.6, (math.floor(i / 3) - 1) * 1.3), colors[(i % 4) + 1], M.Fabric))
	end
	-- Jinx's gift box (center of the arcade)
	local box = Vector3.new(-77, 0, 15)
	part(d, Vector3.new(6, 6, 6), CFrame.new(box + Vector3.new(0, 3, 0)), C(110, 40, 160), M.SmoothPlastic, "GiftBox")
	deco(part(d, Vector3.new(6.1, 6.1, 1), CFrame.new(box + Vector3.new(0, 3, 0)), C(255, 210, 60), M.SmoothPlastic))
	deco(part(d, Vector3.new(1, 6.1, 6.1), CFrame.new(box + Vector3.new(0, 3, 0)), C(255, 210, 60), M.SmoothPlastic))
	part(d, Vector3.new(6.6, 0.8, 6.6), CFrame.new(box + Vector3.new(0, 6.4, 0)), C(130, 50, 180), M.SmoothPlastic, "Lid")
	deco(ball(d, 1.6, box + Vector3.new(-0.8, 7.4, 0), C(255, 210, 60)))
	deco(ball(d, 1.6, box + Vector3.new(0.8, 7.4, 0), C(255, 210, 60)))
	local tag = deco(part(d, Vector3.new(5, 1.4, 0.1), facing(box + Vector3.new(0, 4, -3.06), Vector3.new(0, 0, -1)), C(255, 255, 255)))
	sign(tag, "DO NOT OPEN", C(150, 20, 35), { Bg = C(255, 255, 255) })
	-- Neon confetti on the carpet
	local rng = Random.new(7)
	local neon = { C(0, 255, 230), C(255, 60, 200), C(255, 230, 60), C(120, 255, 80) }
	for _ = 1, 50 do
		local x, z = rng:NextNumber(-99, -55), rng:NextNumber(1, 29)
		deco(part(d, Vector3.new(0.6, 0.05, 0.6), CFrame.new(x, 0.03, z) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), neon[rng:NextInteger(1, 4)], M.Neon))
	end
	for _, z in { 0.6, 29.4 } do
		deco(part(d, Vector3.new(46, 0.3, 0.2), CFrame.new(-77, 12, z), C(255, 60, 200), M.Neon))
	end
	local sgn = deco(part(d, Vector3.new(10, 2.5, 0.2), facing(Vector3.new(-54.6, 13, 15), Vector3.new(-1, 0, 0)), C(20, 10, 30)))
	sign(sgn, "ARCADE", C(0, 255, 230), { Glow = true, Bg = C(20, 10, 30) })
end

local function decorateRestrooms(d)
	for i = 0, 3 do
		local z = -28 + i * 6
		part(d, Vector3.new(6, 8, 0.3), CFrame.new(-77, 4, z), C(150, 180, 200), M.SmoothPlastic, "Stall")
		local door = part(d, Vector3.new(0.3, 7, 4), CFrame.new(-74.2, 4, z + 3.2), C(130, 160, 185), M.SmoothPlastic, "StallDoor")
		door.CFrame = door.CFrame * CFrame.Angles(0, math.rad(25 + i * 15), 0)
		deco(cyl(d, 1.6, 2, Vector3.new(-79, 0.8, z + 3), C(250, 250, 250)))
	end
	part(d, Vector3.new(6, 8, 0.3), CFrame.new(-77, 4, -4), C(150, 180, 200), M.SmoothPlastic, "Stall")
	for i = 0, 2 do
		local x = -66 + i * 4
		part(d, Vector3.new(3, 0.8, 2), CFrame.new(x, 3.2, -1.4), C(240, 240, 240), M.Marble, "Sink")
		local mirror = deco(part(d, Vector3.new(3, 3.5, 0.15), CFrame.new(x, 6.5, -0.45), C(200, 220, 230), M.Glass))
		mirror.Reflectance = 0.6
	end
	poster(d, Vector3.new(-54.6, 9, -24), Vector3.new(-1, 0, 0), "WASH YOUR\nHANDS!", C(100, 170, 255), C(255, 255, 255), Vector2.new(4, 3))
end

local function decorateKitchen(d)
	for i = 0, 2 do
		local x = 62 + i * 9
		part(d, Vector3.new(8, 3.4, 3), CFrame.new(x, 1.7, 28), C(170, 175, 180), M.DiamondPlate, "Counter")
	end
	-- pizza ovens
	for i = 0, 1 do
		local pos = Vector3.new(88 + i * 0, 0, 7 + i * 10)
		part(d, Vector3.new(4, 7, 6), CFrame.new(pos + Vector3.new(3, 3.5, 0)), C(120, 60, 40), M.Brick, "Oven")
		local glow = deco(part(d, Vector3.new(0.2, 1.6, 3), CFrame.new(pos + Vector3.new(0.9, 3, 0)), C(255, 120, 30), M.Neon))
		local l = Instance.new("PointLight")
		l.Color = C(255, 120, 30)
		l.Range = 12
		l.Brightness = 1.5
		l.Parent = glow
	end
	part(d, Vector3.new(14, 3.4, 4), CFrame.new(72, 1.7, 15), C(170, 175, 180), M.DiamondPlate, "Island")
	for i = 0, 4 do
		deco(cyl(d, 0.6, 2.4, Vector3.new(67 + i * 2.5, 3.7 + (i % 2) * 0.6, 15), C(200, 160, 110)))
	end
	-- fridge
	part(d, Vector3.new(5, 9, 3), CFrame.new(58, 4.5, 27.4), C(220, 225, 230), M.Metal, "Fridge")
	-- pizza boxes
	for i = 0, 5 do
		deco(part(d, Vector3.new(2.4, 0.4, 2.4), CFrame.new(62, 3.6 + i * 0.42, 28) * CFrame.Angles(0, math.rad(i * 7), 0), C(235, 220, 190), M.Cardboard))
	end
	-- hanging pans
	for i = 0, 3 do
		deco(cyl(d, 0.2, 1.8, Vector3.new(68 + i * 3, 9, 15), C(50, 50, 55)))
	end
	poster(d, Vector3.new(54.6, 9, 24), Vector3.new(1, 0, 0), "EMPLOYEES ONLY", C(200, 40, 40), C(255, 255, 255), Vector2.new(5, 2))
end

local function decorateParts(d)
	local colors = { C(140, 85, 45), C(35, 40, 60), C(196, 150, 95), C(120, 60, 170) }
	shelf(d, Vector3.new(66, 0, -28.4), Vector3.new(0, 0, 1), 14, function(_, cf)
		for k = 0, 3 do
			spareHead(d, (cf * CFrame.new(-5 + k * 3.3, 0.9, 0)).Position, math.rad((k * 37) % 40 - 20), colors[(k % 4) + 1])
		end
	end)
	shelf(d, Vector3.new(88.4, 0, -14), Vector3.new(-1, 0, 0), 10, function(_, cf)
		for k = 0, 2 do
			deco(part(d, Vector3.new(1.6, 1.2, 1.6), cf * CFrame.new(-3 + k * 3, 0.75, 0), C(90, 90, 95), M.Metal))
		end
	end)
	-- workbench with a slumped endoskeleton
	part(d, Vector3.new(10, 3.2, 4), CFrame.new(70, 1.6, -4), C(100, 75, 55), M.Wood, "Workbench")
	deco(part(d, Vector3.new(2, 3, 1.2), CFrame.new(70, 4.7, -4.5) * CFrame.Angles(math.rad(15), 0, 0), C(80, 80, 85), M.Metal))
	spareHead(d, Vector3.new(70, 7, -4.2), math.rad(20), C(70, 70, 75))
	for i = 0, 4 do
		deco(part(d, Vector3.new(0.4, 0.4, 2.5), CFrame.new(66 + i * 0.5, 3.4, -3) * CFrame.Angles(0, math.rad(i * 30), 0), C(60, 60, 65), M.Metal))
	end
	-- crates
	for i = 0, 2 do
		part(d, Vector3.new(4, 4, 4), CFrame.new(60 + i * 1.5, 2 + i * 4, -25) * CFrame.Angles(0, math.rad(i * 15), 0), C(150, 110, 70), M.WoodPlanks, "Crate")
	end
end

local function decorateBackstage(d)
	-- costume racks with slumped suits
	local colors = { C(140, 85, 45), C(196, 150, 95), C(35, 40, 60) }
	for i = 0, 2 do
		local x = -34 + i * 10
		part(d, Vector3.new(6, 0.3, 0.3), CFrame.new(x, 7, 47), C(80, 80, 85), M.Metal)
		for _, sx in { -3, 3 } do
			deco(part(d, Vector3.new(0.3, 7, 0.3), CFrame.new(x + sx, 3.5, 47), C(80, 80, 85), M.Metal))
		end
		deco(part(d, Vector3.new(3, 5, 1.6), CFrame.new(x, 4.3, 47), colors[i + 1], M.Fabric))
		spareHead(d, Vector3.new(x - 4.5, 1, 43), math.rad(i * 25), colors[((i + 1) % 3) + 1])
	end
	part(d, Vector3.new(8, 3, 4), CFrame.new(-8, 1.5, 47), C(100, 75, 55), M.Wood, "Table")
	for i = 0, 3 do
		part(d, Vector3.new(3.5, 3.5, 3.5), CFrame.new(2, 1.75 + (i % 2) * 3.5, 33 + math.floor(i / 2) * 4), C(150, 110, 70), M.WoodPlanks, "Crate")
	end
	poster(d, Vector3.new(-39.4, 9, 40), Vector3.new(1, 0, 0), "SHOWTIME\nIN 5 MIN!", C(150, 20, 35), C(255, 230, 120), Vector2.new(4, 4))
end

local function decorateSecurity(d)
	part(d, Vector3.new(16, 3.2, 4), CFrame.new(20, 1.6, 47.5), C(90, 70, 55), M.Wood, "Desk")
	for i = 0, 2 do
		local pos = Vector3.new(14 + i * 4, 5, 48)
		part(d, Vector3.new(3.6, 2.8, 2), CFrame.new(pos), C(30, 30, 30), M.SmoothPlastic, "Monitor")
		local scr = deco(part(d, Vector3.new(3.2, 2.4, 0.1), facing(pos + Vector3.new(0, 0, -1.03), Vector3.new(0, 0, -1)), C(10, 30, 20), M.Neon))
		sign(scr, ("CAM 0%d\nNO SIGNAL"):format(i + 1), C(80, 255, 140), { Glow = true, Bg = C(5, 20, 10), Font = Enum.Font.Code })
		local l = Instance.new("SurfaceLight")
		l.Color = C(80, 255, 140)
		l.Range = 8
		l.Brightness = 0.8
		l.Parent = scr
	end
	-- chair
	part(d, Vector3.new(2.4, 0.5, 2.4), CFrame.new(20, 2.2, 43.5), C(30, 30, 35), M.Fabric, "Chair")
	part(d, Vector3.new(2.4, 3, 0.4), CFrame.new(20, 3.9, 42.4), C(30, 30, 35), M.Fabric)
	-- kids drawings
	for i = 0, 4 do
		local cols = { C(255, 230, 230), C(230, 255, 230), C(230, 230, 255), C(255, 255, 220), C(255, 230, 255) }
		local p = deco(part(d, Vector3.new(1.6, 1.2, 0.05), facing(Vector3.new(10 + i * 2.2, 9 + (i % 2) * 1.4, 49.45), Vector3.new(0, 0, -1)), cols[i + 1]))
		sign(p, ({ ":)", "PIP", "<3", "BRUNO", "?!" })[i + 1], C(40, 40, 160), { Font = Enum.Font.Cartoon })
	end
end

local function decorateCloset(d)
	shelf(d, Vector3.new(42, 0, 31.6), Vector3.new(0, 0, -1), 12, function(_, cf)
		for k = 0, 2 do
			deco(cyl(d, 1.2, 1, (cf * CFrame.new(-3 + k * 3, 0.75, 0)).Position, ({ C(60, 120, 220), C(220, 220, 60), C(220, 60, 60) })[k + 1]))
		end
	end)
	for i = 0, 2 do
		deco(cyl(d, 1.6, 1.8, Vector3.new(36 + i * 2.2, 0.8, 47), C(90, 140, 200)))
		deco(part(d, Vector3.new(0.2, 6, 0.2), CFrame.new(36 + i * 2.2, 3, 48.3) * CFrame.Angles(math.rad(10), 0, 0), C(150, 110, 70), M.Wood))
	end
end

local function decorateEntrance(d)
	-- ticket booth + rope barriers
	part(d, Vector3.new(6, 4, 3), CFrame.new(-9, 2, -44), C(200, 40, 50), M.SmoothPlastic, "Booth")
	deco(part(d, Vector3.new(6.2, 0.4, 3.2), CFrame.new(-9, 4.2, -44), PALETTE.Trim, M.Neon))
	for _, x in { 6, 10 } do
		deco(cyl(d, 3, 0.4, Vector3.new(x, 1.5, -40), C(220, 180, 60)))
	end
	deco(part(d, Vector3.new(4, 0.2, 0.2), CFrame.new(8, 2.6, -40), C(180, 20, 30), M.Fabric))
	local mat = deco(part(d, Vector3.new(9, 0.05, 5), CFrame.new(0, 0.03, -46), C(150, 20, 35), M.Fabric))
	sign(mat, "WELCOME!", C(255, 220, 80), { Face = Enum.NormalId.Top })
	for _, x in { -12, 12 } do
		deco(cyl(d, 2, 2.4, Vector3.new(x, 1, -32), C(120, 70, 40)))
		deco(ball(d, 3.2, Vector3.new(x, 3.5, -32), C(40, 120, 50), M.Grass))
	end
end

local function decorateHalls(d)
	poster(d, Vector3.new(-53.4, 9, 0), Vector3.new(1, 0, 0), "MAPLE'S\nSING-ALONG\nSATURDAYS!", C(196, 150, 95), C(90, 40, 20))
	poster(d, Vector3.new(53.4, 9, 8), Vector3.new(-1, 0, 0), "NO RUNNING\nIN THE HALLS", C(240, 230, 210), C(150, 20, 35), Vector2.new(5, 4))
	-- exit signs above doors
	for _, spec in {
		{ Vector3.new(-40, 12.5, 0), Vector3.new(1, 0, 0) },
		{ Vector3.new(40, 12.5, 0), Vector3.new(-1, 0, 0) },
		{ Vector3.new(0, 12.5, -29.4), Vector3.new(0, 0, 1) },
	} do
		local s = deco(part(d, Vector3.new(3, 1, 0.3), facing(spec[1] + spec[2] * 0.6, spec[2]), C(20, 120, 40), M.Neon))
		sign(s, "EXIT", C(255, 255, 255), { Glow = true })
	end
end

------------------------------------------------------------------------------
-- Lobby (parking lot in front of the pizzeria)
------------------------------------------------------------------------------
local function car(parent, pos: Vector3, yaw: number, color: Color3)
	local cf = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	part(parent, Vector3.new(6, 2.4, 11), cf * CFrame.new(0, 2, 0), color, M.SmoothPlastic, "Car")
	part(parent, Vector3.new(5.4, 2, 6), cf * CFrame.new(0, 4.2, 0.5), color, M.SmoothPlastic)
	local glass = deco(part(parent, Vector3.new(5.5, 1.6, 6.1), cf * CFrame.new(0, 4.3, 0.5), C(30, 40, 60), M.Glass))
	glass.Transparency = 0.3
	for _, sx in { -2.9, 2.9 } do
		for _, sz in { -3.5, 3.5 } do
			local w = part(parent, Vector3.new(1, 2.2, 2.2), cf * CFrame.new(sx, 1.1, sz), C(20, 20, 20), M.SmoothPlastic)
			w.Shape = Enum.PartType.Cylinder
		end
	end
	for _, sx in { -1.9, 1.9 } do
		deco(part(parent, Vector3.new(1, 0.6, 0.2), cf * CFrame.new(sx, 2.4, -5.55), C(255, 250, 220), M.Neon))
	end
end

local function streetLamp(parent, pos: Vector3)
	deco(cyl(parent, 14, 0.6, pos + Vector3.new(0, 7, 0), C(40, 40, 45), M.Metal)).CanCollide = true
	local head = deco(part(parent, Vector3.new(2.6, 0.6, 1.4), CFrame.new(pos + Vector3.new(0, 14.2, 0)), C(255, 230, 180), M.Neon))
	local l = Instance.new("SpotLight")
	l.Face = Enum.NormalId.Bottom
	l.Angle = 110
	l.Range = 34
	l.Brightness = 2.2
	l.Color = C(255, 210, 150)
	l.Shadows = true
	l.Parent = head
end

local function tree(parent, pos: Vector3, scale: number)
	cyl(parent, 6 * scale, 1.4 * scale, pos + Vector3.new(0, 3 * scale, 0), C(70, 50, 35), M.Wood)
	for i = 0, 2 do
		deco(ball(parent, (7 - i * 1.6) * scale, pos + Vector3.new(0, (6.5 + i * 2.6) * scale, 0), C(25, 60 + i * 10, 35), M.Grass))
	end
end

local function booth(parent, pos: Vector3, dir: Vector3, title: string, color: Color3, action: string)
	local cf = facing(pos, dir)
	part(parent, Vector3.new(10, 4, 3), cf * CFrame.new(0, 2, 0), C(240, 240, 240), M.SmoothPlastic, "Counter")
	deco(part(parent, Vector3.new(10.2, 0.4, 3.2), cf * CFrame.new(0, 4.2, 0), color, M.Neon))
	for _, sx in { -4.7, 4.7 } do
		part(parent, Vector3.new(0.6, 10, 0.6), cf * CFrame.new(sx, 5, 1.2), C(60, 60, 65), M.Metal)
	end
	-- striped awning
	for i = 0, 5 do
		deco(part(parent, Vector3.new(10 / 6, 0.4, 4), cf * CFrame.new(-5 + 10 / 12 + i * 10 / 6, 10, 0) * CFrame.Angles(math.rad(-12), 0, 0),
			(i % 2 == 0) and color or C(255, 255, 255), M.Fabric))
	end
	local board = deco(part(parent, Vector3.new(9, 2.2, 0.3), cf * CFrame.new(0, 11.6, -0.4), C(25, 25, 35)))
	sign(board, title, color, { Glow = true, Bg = C(25, 25, 35) })
	local anchor = part(parent, Vector3.new(1, 1, 1), cf * CFrame.new(0, 3, -2), color)
	anchor.Transparency = 1
	anchor.CanCollide = false
	anchor.Name = "PromptAnchor"
	local pp = prompt(anchor, action, title, 0, 12)
	return pp, cf
end

local function buildLobby(root, map)
	local lobby = folder("Lobby", root)
	-- ground
	part(lobby, Vector3.new(220, 1, 150), CFrame.new(0, -0.5, -125), C(38, 38, 42), M.Asphalt, "Asphalt")
	part(lobby, Vector3.new(220, 0.4, 10), CFrame.new(0, 0.2, -55), C(120, 120, 125), M.Concrete, "Sidewalk")
	part(lobby, Vector3.new(86, 1, 19.5), CFrame.new(-57, -0.5, -40.75), C(120, 120, 125), M.Concrete, "FrontWalk")
	part(lobby, Vector3.new(86, 1, 19.5), CFrame.new(57, -0.5, -40.75), C(120, 120, 125), M.Concrete, "FrontWalk")
	-- grass beyond the fence
	part(lobby, Vector3.new(500, 1, 500), CFrame.new(0, -1.2, -100), C(30, 50, 30), M.Grass, "Grass")
	-- parking lines
	for row = 0, 1 do
		for i = -5, 5 do
			deco(part(lobby, Vector3.new(0.4, 0.05, 12), CFrame.new(i * 10 + 5, 0.03, -78 - row * 70), C(230, 230, 200), M.SmoothPlastic))
		end
	end
	-- cars
	car(lobby, Vector3.new(-40, 0, -78), 0, C(150, 30, 30))
	car(lobby, Vector3.new(-20, 0, -78), 0, C(40, 70, 140))
	car(lobby, Vector3.new(40, 0, -148), math.pi, C(60, 60, 60))
	car(lobby, Vector3.new(-50, 0, -148), math.pi, C(210, 200, 170))
	car(lobby, Vector3.new(50, 0, -78), 0, C(30, 110, 60))
	-- lamps & trees
	for _, x in { -60, -20, 20, 60 } do
		streetLamp(lobby, Vector3.new(x, 0, -95))
		streetLamp(lobby, Vector3.new(x, 0, -165))
	end
	local rng = Random.new(3)
	for i = 0, 13 do
		tree(lobby, Vector3.new(-90 + i * 14, 0, -192 + rng:NextNumber(-3, 3)), rng:NextNumber(0.9, 1.3))
	end
	for i = 0, 6 do
		tree(lobby, Vector3.new(-95, 0, -70 - i * 17), rng:NextNumber(0.9, 1.3))
		tree(lobby, Vector3.new(95, 0, -70 - i * 17), rng:NextNumber(0.9, 1.3))
	end
	-- fence + invisible boundary
	for _, spec in {
		{ Vector3.new(0, 4, -185), Vector3.new(178, 8, 0.4) },
		{ Vector3.new(-88, 4, -107.5), Vector3.new(0.4, 8, 155) },
		{ Vector3.new(88, 4, -107.5), Vector3.new(0.4, 8, 155) },
	} do
		local f = part(lobby, spec[2], CFrame.new(spec[1]), C(90, 90, 95), M.DiamondPlate, "Fence")
		f.Transparency = 0.55
		local inv = part(lobby, spec[2] + Vector3.new(1.6, 40, 1.6), CFrame.new(spec[1] + Vector3.new(0, 20, 0)), C(0, 0, 0))
		inv.Transparency = 1
		inv.Name = "Boundary"
	end
	-- plug the gap between the west fence and the facade
	local plug = part(lobby, Vector3.new(8, 40, 1), CFrame.new(-84, 20, -30.9), C(0, 0, 0))
	plug.Transparency = 1
	plug.Name = "Boundary"

	-- Spawn
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(0, 0.1, -120)
	spawn.Color = C(255, 60, 160)
	spawn.Material = M.Neon
	spawn.Transparency = 0.4
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = lobby
	map.Spawns.Lobby = CFrame.new(0, 4, -120)

	-- Facade: neon sign + awning + windows
	local facadeColor = C(150, 55, 45)
	part(lobby, Vector3.new(66, H + 6, 0.6), CFrame.new(-47, (H + 6) / 2, -30.9), facadeColor, M.Brick, "Facade")
	part(lobby, Vector3.new(76, H + 6, 0.6), CFrame.new(52, (H + 6) / 2, -30.9), facadeColor, M.Brick, "Facade")
	part(lobby, Vector3.new(28.8, 8, 0.6), CFrame.new(0, H + 4, -50.9), facadeColor, M.Brick, "Facade")
	for _, x in { -60, -35, 35, 60 } do
		local w = part(lobby, Vector3.new(12, 7, 0.3), CFrame.new(x, 6, -31.3), C(255, 200, 120), M.Glass, "Window")
		w.Transparency = 0.55
		for i = 0, 3 do
			deco(part(lobby, Vector3.new(12 / 4, 1, 3), CFrame.new(x - 4.5 + i * 3, 10.5, -32.6) * CFrame.Angles(math.rad(20), 0, 0), (i % 2 == 0) and C(200, 30, 40) or C(255, 255, 255), M.Fabric))
		end
	end
	local neon = deco(part(lobby, Vector3.new(34, 6, 0.6), facing(Vector3.new(0, H + 7, -51.5), Vector3.new(0, 0, -1)), C(20, 10, 30), M.SmoothPlastic, "NeonSign"))
	sign(neon, Config.PizzeriaName, C(255, 90, 200), { Glow = true, Bg = C(20, 10, 30), Stroke = true, StrokeColor = C(120, 0, 90) })
	local glow = Instance.new("SurfaceLight")
	glow.Face = Enum.NormalId.Front
	glow.Color = C(255, 80, 200)
	glow.Range = 40
	glow.Brightness = 3
	glow.Parent = neon
	for _, x in { -18, 18 } do
		deco(part(lobby, Vector3.new(0.6, 6.6, 0.8), CFrame.new(x, H + 7, -51.5), C(0, 255, 230), M.Neon))
	end
	-- pole sign "NOW HIRING"
	cyl(lobby, 16, 1, Vector3.new(-70, 8, -62), C(60, 60, 65), M.Metal)
	local hiring = deco(part(lobby, Vector3.new(14, 7, 1), facing(Vector3.new(-70, 19, -62), Vector3.new(0.4, 0, -1)), C(255, 230, 120), M.SmoothPlastic))
	sign(hiring, "NOW HIRING:\nNIGHT GUARDS\n12AM - 6AM", C(150, 20, 35), { Bg = C(255, 230, 120), Glow = true })

	-- Shift board (client writes the countdown on it)
	local board = part(lobby, Vector3.new(18, 7, 0.6), facing(Vector3.new(0, 9, -96), Vector3.new(0, 0, -1)), C(15, 15, 22), M.SmoothPlastic, "ShiftBoard")
	for _, x in { -8, 8 } do
		cyl(lobby, 6, 0.6, Vector3.new(x, 3, -95.6), C(60, 60, 65), M.Metal)
	end
	sign(board, "NEXT SHIFT SOON", C(255, 220, 80), { Glow = true, Bg = C(15, 15, 22) })
	map.ShiftBoard = board

	-- Booths
	local prizePrompt = booth(lobby, Vector3.new(-32, 0, -112), Vector3.new(0.5, 0, -1), "PRIZE COUNTER", C(255, 80, 180), "Open")
	prizePrompt:SetAttribute("UI", "Prizes")
	-- plushies on the prize counter
	for i = 0, 3 do
		local cols = { C(140, 85, 45), C(35, 40, 60), C(196, 150, 95), C(120, 60, 170) }
		local cf = facing(Vector3.new(-32, 0, -112), Vector3.new(0.5, 0, -1))
		deco(ball(lobby, 1.6, (cf * CFrame.new(-3 + i * 2, 5.2, 0.4)).Position, cols[i + 1], M.Fabric))
	end
	local wardrobePrompt = booth(lobby, Vector3.new(32, 0, -112), Vector3.new(-0.5, 0, -1), "WARDROBE", C(0, 220, 255), "Open")
	wardrobePrompt:SetAttribute("UI", "Wardrobe")
	local shopPrompt = booth(lobby, Vector3.new(-32, 0, -140), Vector3.new(0.5, 0, 1), "GUARD SHOP", C(80, 255, 120), "Open")
	shopPrompt:SetAttribute("UI", "Shop")
	local guidePrompt = booth(lobby, Vector3.new(32, 0, -140), Vector3.new(-0.5, 0, 1), "MEET THE MASCOTS", C(255, 200, 60), "Read")
	guidePrompt:SetAttribute("UI", "Guide")
	map.LobbyPrompts = { prizePrompt, wardrobePrompt, shopPrompt, guidePrompt }

	-- Leaderboard
	local lb = part(lobby, Vector3.new(16, 20, 0.6), facing(Vector3.new(70, 11, -115), Vector3.new(-1, 0, 0)), C(15, 15, 22), M.SmoothPlastic, "Leaderboard")
	cyl(lobby, 2, 1, Vector3.new(70, 1, -109), C(60, 60, 65))
	cyl(lobby, 2, 1, Vector3.new(70, 1, -121), C(60, 60, 65))
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 30
	sg.LightInfluence = 0
	sg.Parent = lb
	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 0.12)
	title.BackgroundColor3 = C(150, 20, 35)
	title.Text = "🏆 TOP GUARDS — NIGHTS SURVIVED"
	title.TextScaled = true
	title.Font = Enum.Font.FredokaOne
	title.TextColor3 = C(255, 230, 120)
	title.Parent = sg
	local list = Instance.new("TextLabel")
	list.Name = "List"
	list.Position = UDim2.fromScale(0.05, 0.14)
	list.Size = UDim2.fromScale(0.9, 0.84)
	list.BackgroundTransparency = 1
	list.Text = "Loading..."
	list.TextScaled = true
	list.Font = Enum.Font.GothamMedium
	list.TextColor3 = C(240, 240, 240)
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.Parent = sg
	map.LeaderboardLabel = list
end

------------------------------------------------------------------------------
-- Build
------------------------------------------------------------------------------
function MapBuilder.Build()
	local old = workspace:FindFirstChild("Map")
	if old then
		old:Destroy()
	end
	local root = folder("Map", workspace)
	local floors = folder("Floor", root)
	local walls = folder("Walls", root)
	local decor = folder("Decor", root)
	local lights = folder("Lights", root)
	local interactive = folder("Interactive", root)

	local map = {
		Folder = root,
		Rooms = ROOMS,
		Lights = {},
		Spawns = {},
		NavPoints = {},
		FuseBoxes = {},
		Lockers = {},
		Floors = floors,
	}

	-- Floors, ceilings, lights
	for name, room in ROOMS do
		buildFloor(floors, room)
		local x1, x2, z1, z2 = room[1], room[2], room[3], room[4]
		part(walls, Vector3.new(x2 - x1, 1, z2 - z1), CFrame.new((x1 + x2) / 2, H + 0.5, (z1 + z2) / 2), PALETTE.Ceiling, M.SmoothPlastic, "Ceiling")
		map.Lights[name] = {}
		local nx = math.max(1, math.round((x2 - x1) / 20))
		local nz = math.max(1, math.round((z2 - z1) / 20))
		for i = 0, nx - 1 do
			for j = 0, nz - 1 do
				local pos = Vector3.new(x1 + (x2 - x1) * (i + 0.5) / nx, H - 0.2, z1 + (z2 - z1) * (j + 0.5) / nz)
				local p, l = lamp(lights, pos, PALETTE.LightOn, 30, 1.4)
				p:SetAttribute("Room", name)
				table.insert(map.Lights[name], { p, l })
			end
		end
		-- dim red emergency light, always on
		local em = deco(part(lights, Vector3.new(0.8, 0.4, 0.8), CFrame.new(x1 + 2, H - 0.4, z1 + 2), C(255, 30, 30), M.Neon, "Emergency"))
		local el = Instance.new("PointLight")
		el.Color = C(255, 40, 40)
		el.Range = math.max(18, math.min(40, (x2 - x1 + z2 - z1) / 2))
		el.Brightness = 0.5
		el.Parent = em
		table.insert(map.NavPoints, Vector3.new((x1 + x2) / 2, 3, (z1 + z2) / 2))
	end
	-- whole-building roof
	part(walls, Vector3.new(200, 1, 102), CFrame.new(-2, H + 1.5, 0), C(50, 50, 55), M.Concrete, "Roof")

	-- Walls + door nav points
	for _, def in WALLS do
		buildWall(walls, def)
		for _, d in def[5] do
			for _, side in { -3.5, 3.5 } do
				local p = def[1] == "X" and Vector3.new(d[1], 3, def[2] + side) or Vector3.new(def[2] + side, 3, d[1])
				-- skip the outside of the front door
				if not (def[1] == "X" and def[2] == -50 and side < 0) then
					table.insert(map.NavPoints, p)
				end
			end
		end
	end

	-- Decor
	local stageSpots = decorateDining(decor)
	for _, s in stageSpots do
		table.insert(map.Lights.Dining, s)
	end
	decorateArcade(decor)
	decorateRestrooms(decor)
	decorateKitchen(decor)
	decorateParts(decor)
	decorateBackstage(decor)
	decorateSecurity(decor)
	decorateCloset(decor)
	decorateEntrance(decor)
	decorateHalls(decor)

	-- Lockers
	for _, spec in LOCKER_SPOTS do
		local model, pp = locker(interactive, spec[1], spec[2])
		table.insert(map.Lockers, { Model = model, Prompt = pp })
	end

	-- Fuse boxes
	for _, spec in FUSE_SPOTS do
		table.insert(map.FuseBoxes, fuseBox(interactive, spec[1], spec[2], spec[3]))
	end

	-- Music box (Security office)
	do
		local pos = Vector3.new(12, 0, 34)
		part(interactive, Vector3.new(3, 3, 3), CFrame.new(pos + Vector3.new(0, 1.5, 0)), C(60, 30, 80), M.Wood, "Pedestal")
		local box = part(interactive, Vector3.new(2.4, 1.6, 2.4), CFrame.new(pos + Vector3.new(0, 3.8, 0)), C(255, 200, 220), M.SmoothPlastic, "MusicBox")
		deco(part(interactive, Vector3.new(2.5, 0.3, 2.5), CFrame.new(pos + Vector3.new(0, 4.3, 0)), PALETTE.Trim, M.Neon))
		deco(part(interactive, Vector3.new(0.3, 0.3, 1.2), CFrame.new(pos + Vector3.new(1.4, 3.8, 0)), C(220, 180, 60), M.Metal, "Crank"))
		deco(ball(interactive, 0.8, pos + Vector3.new(0, 5.1, 0), C(120, 60, 170)))
		local pp = prompt(box, "Wind", "Music Box", 1.2, 9)
		pp.Enabled = false
		map.MusicBox = { Part = box, Prompt = pp }
	end
	-- VCR (Security office) — tape delivery target
	do
		local pos = Vector3.new(26, 3.2, 47.5)
		part(interactive, Vector3.new(3, 2.6, 2.4), CFrame.new(pos + Vector3.new(0, 1.3, 0)), C(40, 40, 40), M.SmoothPlastic, "TV")
		local vcr = part(interactive, Vector3.new(3, 0.6, 2.2), CFrame.new(pos + Vector3.new(0, -0.0, -0.2)), C(25, 25, 25), M.SmoothPlastic, "VCR")
		deco(part(interactive, Vector3.new(0.3, 0.15, 0.05), CFrame.new(pos + Vector3.new(1, 0, -1.32)), C(255, 40, 40), M.Neon))
		local scr = deco(part(interactive, Vector3.new(2.4, 1.9, 0.1), facing(pos + Vector3.new(0, 1.3, -1.25), Vector3.new(0, 0, -1)), C(20, 20, 50), M.Neon))
		sign(scr, "INSERT TAPE", C(150, 150, 255), { Glow = true, Bg = C(10, 10, 30), Font = Enum.Font.Code })
		local pp = prompt(vcr, "Insert Tape", "VCR", 1, 9)
		map.VCR = { Part = vcr, Prompt = pp }
	end
	-- Generator (Parts & Service) — gas delivery target
	do
		local pos = Vector3.new(80, 0, -24)
		local gen = part(interactive, Vector3.new(7, 5, 5), CFrame.new(pos + Vector3.new(0, 2.5, 0)), C(220, 180, 30), M.Metal, "Generator")
		for i = 0, 3 do
			deco(part(interactive, Vector3.new(7.1, 0.5, 0.2), CFrame.new(pos + Vector3.new(0, 1 + i * 1.1, -2.55)) * CFrame.Angles(0, 0, math.rad(20)), C(20, 20, 20)))
		end
		deco(cyl(interactive, 4, 0.8, pos + Vector3.new(2.5, 7, 1.5), C(60, 60, 60), M.Metal))
		local gauge = deco(part(interactive, Vector3.new(1.6, 1.6, 0.1), facing(pos + Vector3.new(-2, 3.5, -2.56), Vector3.new(0, 0, -1)), C(240, 240, 240)))
		sign(gauge, "FUEL", C(200, 30, 30), {})
		local pp = prompt(gen, "Refuel", "Generator", 1.5, 10)
		map.Generator = { Part = gen, Prompt = pp }
	end

	-- Front door / exit
	do
		local glass = part(interactive, Vector3.new(10, DOOR_H, 0.4), CFrame.new(0, DOOR_H / 2, -50), C(170, 210, 240), M.Glass, "FrontDoor")
		glass.Transparency = 0.5
		local sgn = deco(part(interactive, Vector3.new(4, 1.2, 0.3), facing(Vector3.new(0, DOOR_H + 1.2, -49.4), Vector3.new(0, 0, 1)), C(120, 20, 20), M.Neon, "ExitSign"))
		local _, exitLabel = sign(sgn, "LOCKED", C(255, 255, 255), { Glow = true })
		-- invisible wall that only blocks animatronics
		local npcBlock = part(interactive, Vector3.new(12, DOOR_H, 1), CFrame.new(0, DOOR_H / 2, -48.6), C(0, 0, 0))
		npcBlock.Transparency = 1
		npcBlock.Name = "NPCBlock"
		npcBlock.CollisionGroup = "NPCBlock"
		local zone = part(interactive, Vector3.new(10, 8, 3), CFrame.new(0, 4, -53), C(0, 255, 0))
		zone.Transparency = 1
		zone.CanCollide = false
		zone.Name = "ExitZone"
		map.FrontDoor = { Glass = glass, Sign = sgn, Label = exitLabel, Zone = zone }
	end

	-- Spawn points
	map.Spawns.Entrance = {}
	for i = 0, 7 do
		table.insert(map.Spawns.Entrance, CFrame.new(-4.5 + (i % 4) * 3, 3, -37 + math.floor(i / 4) * 3.5) * CFrame.Angles(0, math.pi, 0))
	end
	map.Spawns.Ghost = CFrame.new(0, 4, -4)
	map.Spawns.Stage = { Vector3.new(-8, 8.2, 25), Vector3.new(8, 8.2, 25), Vector3.new(0, 8.2, 25) }
	map.Spawns.Backstage = { Vector3.new(-16, 5.2, 40) }
	map.Spawns.GiftBox = { Vector3.new(-77, 5.2, 8) }

	buildLobby(root, map)

	-- Random free spot on the floor of a room (for loot/objectives)
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { floors, lights }
	local rng = Random.new()
	local weighted = {}
	for name, room in ROOMS do
		if name ~= "Entrance" then
			local area = (room[2] - room[1]) * (room[4] - room[3])
			for _ = 1, math.max(1, math.floor(area / 300)) do
				table.insert(weighted, name)
			end
		end
	end
	function map.RandomSpot(roomName: string?, exclude: { [string]: boolean }?): Vector3
		for _ = 1, 25 do
			local name = roomName or weighted[rng:NextInteger(1, #weighted)]
			if not (exclude and exclude[name]) then
				local room = ROOMS[name]
				local pos = Vector3.new(rng:NextNumber(room[1] + 4, room[2] - 4), 2.6, rng:NextNumber(room[3] + 4, room[4] - 4))
				local hits = workspace:GetPartBoundsInBox(CFrame.new(pos), Vector3.new(3, 3.5, 3), overlap)
				local blocked = false
				for _, h in hits do
					if h.CanCollide then
						blocked = true
						break
					end
				end
				if not blocked then
					return pos
				end
			end
		end
		return Vector3.new(0, 2.6, -10)
	end

	-- drop navigation points that ended up inside furniture, add a few free ones per room
	local valid = {}
	for _, p in map.NavPoints do
		local blocked = false
		for _, h in workspace:GetPartBoundsInBox(CFrame.new(p), Vector3.new(4, 4, 4), overlap) do
			if h.CanCollide then
				blocked = true
				break
			end
		end
		if not blocked then
			table.insert(valid, p)
		end
	end
	for name in ROOMS do
		if name ~= "Entrance" then
			for _ = 1, 2 do
				table.insert(valid, map.RandomSpot(name) + Vector3.new(0, 0.4, 0))
			end
		end
	end
	map.NavPoints = valid

	function map.SetRoomLights(name: string, on: boolean)
		for _, entry in map.Lights[name] or {} do
			local p, l = entry[1], entry[2]
			l.Enabled = on
			if p.Name == "Fixture" then
				p.Material = on and M.Neon or M.SmoothPlastic
				p.Color = on and PALETTE.LightOn or PALETTE.LightOff
			end
		end
	end

	function map.RoomAt(pos: Vector3): string?
		for name, r in ROOMS do
			if pos.X >= r[1] and pos.X <= r[2] and pos.Z >= r[3] and pos.Z <= r[4] then
				return name
			end
		end
		return nil
	end

	return map
end

return MapBuilder
