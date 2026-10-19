--[[
	AnimatronicService — spawns the mascots and runs their AI.

	Behaviours (one simple rule each, so players learn fast):
	  Hunter   (Bruno) : sees you in a cone -> chases. Lose him by breaking line of sight / lockers.
	  Listener (Maple) : blind, goes to noises (running, repairs, capsules, decoys).
	  Watcher  (Pip)   : frozen while a flashlight is on him, very fast in the dark.
	  Stalker  (Jinx)  : always knows where the closest guard is. Only out when the music box stops.
]]

local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Mascots = require(Shared.Mascots)
local Builder = require(script.Parent.AnimatronicBuilder)

local AnimatronicService = {}

local brains = {}
local noises = {}
local decoys = {}
local ctx
local folder: Folder
local map
local rng = Random.new()

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.RespectCanCollide = true

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function lineOfSight(from: Vector3, char: Model, to: Vector3): boolean
	local result = workspace:Raycast(from, to - from, rayParams)
	if not result then
		return true
	end
	return result.Instance:IsDescendantOf(char)
end

------------------------------------------------------------------------------
-- Movement helpers
------------------------------------------------------------------------------
local function setSpeed(brain, speed: number)
	brain.Humanoid.WalkSpeed = speed * brain.SpeedMult
end

local function directMove(brain, pos: Vector3)
	brain.Waypoints = nil
	brain.Humanoid:MoveTo(pos)
	brain.Moving = true
end

-- Follows a computed path towards `goal`. Returns true once arrived.
local function pathTo(brain, goal: Vector3): boolean
	local now = os.clock()
	local rootPos = brain.Root.Position
	if (flat(goal - rootPos)).Magnitude < 4 then
		brain.Waypoints = nil
		return true
	end
	local needNew = not brain.Waypoints
		or not brain.PathGoal
		or (brain.PathGoal - goal).Magnitude > 6
		or now - brain.PathTime > 3
	if needNew then
		local ok = pcall(function()
			brain.Path:ComputeAsync(rootPos, goal)
		end)
		if not brain.Alive then
			return false
		end
		if ok and brain.Path.Status == Enum.PathStatus.Success then
			brain.Waypoints = brain.Path:GetWaypoints()
			brain.WpIndex = math.min(2, #brain.Waypoints)
			brain.PathGoal = goal
			brain.PathTime = now
		else
			brain.Waypoints = nil
			brain.Humanoid:MoveTo(goal)
			brain.Moving = true
			return false
		end
	end
	local wps = brain.Waypoints
	local wp = wps[brain.WpIndex]
	while wp and (flat(wp.Position - rootPos)).Magnitude < 3.5 do
		brain.WpIndex += 1
		wp = wps[brain.WpIndex]
	end
	if not wp then
		brain.Waypoints = nil
		return true
	end
	brain.Humanoid:MoveTo(wp.Position)
	brain.Moving = true
	return false
end

local function stop(brain)
	brain.Waypoints = nil
	brain.Moving = false
	brain.Humanoid:MoveTo(brain.Root.Position)
end

local function nearestNav(pos: Vector3, pickAmong: number?): Vector3
	local sorted = table.clone(map.NavPoints)
	table.sort(sorted, function(a, b)
		return (a - pos).Magnitude < (b - pos).Magnitude
	end)
	local n = math.min(pickAmong or 1, #sorted)
	return sorted[rng:NextInteger(1, n)]
end

local function pickRoamGoal(): Vector3
	local targets = ctx.GetTargets()
	if #targets > 0 and rng:NextNumber() < 0.45 then
		-- drift towards a random guard (not exactly on them: gives them a chance)
		local t = targets[rng:NextInteger(1, #targets)]
		return nearestNav(t.Root.Position, 3)
	end
	return map.NavPoints[rng:NextInteger(1, #map.NavPoints)]
end

local function roam(brain, now: number)
	brain.State = "Roam"
	setSpeed(brain, brain.Def.RoamSpeed)
	if not brain.RoamGoal or now > brain.RoamUntil then
		brain.RoamGoal = pickRoamGoal()
		brain.RoamUntil = now + 15
	end
	if pathTo(brain, brain.RoamGoal) then
		brain.RoamGoal = nil
	end
end

local function activeDecoy(pos: Vector3, range: number)
	local now = os.clock()
	local best, bestD
	for _, d in decoys do
		if d.Expires > now then
			local dist = (d.Pos - pos).Magnitude
			if dist < range and (not best or dist < bestD) then
				best, bestD = d, dist
			end
		end
	end
	return best
end

local function nearestVisible(brain, range: number, fovCos: number?)
	local head = brain.Head.Position
	local look = brain.Root.CFrame.LookVector
	local best, bestDist
	for _, t in ctx.GetTargets() do
		local delta = t.Root.Position - brain.Root.Position
		local d = delta.Magnitude
		if d < range then
			local f = flat(delta)
			local inFov = not fovCos or d < 12 or (f.Magnitude > 0.01 and look:Dot(f.Unit) >= fovCos)
			if inFov and lineOfSight(head, t.Char, t.Root.Position) then
				if not best or d < bestDist then
					best, bestDist = t, d
				end
			end
		end
	end
	return best, bestDist
end

local function nearestAny(brain, range: number)
	local best, bestDist
	for _, t in ctx.GetTargets() do
		local d = (t.Root.Position - brain.Root.Position).Magnitude
		if d < range and (not best or d < bestDist) then
			best, bestDist = t, d
		end
	end
	return best, bestDist
end

local function setChasing(brain, target)
	local id = target and target.Player.UserId or 0
	if brain.Model:GetAttribute("Target") ~= id then
		brain.Model:SetAttribute("Target", id)
		for _, pupil in brain.Pupils do
			local light = pupil:FindFirstChildOfClass("PointLight")
			if light then
				light.Brightness = target and 4 or 1.5
				light.Range = target and 10 or 6
			end
		end
	end
end

local function chase(brain, target, dist: number, speed: number)
	brain.State = "Chase"
	brain.LastSeen = target.Root.Position
	brain.LastSeenTime = os.clock()
	setSpeed(brain, speed)
	setChasing(brain, target)
	if dist < 35 and lineOfSight(brain.Head.Position, target.Char, target.Root.Position) then
		directMove(brain, target.Root.Position)
	else
		pathTo(brain, target.Root.Position)
	end
end

------------------------------------------------------------------------------
-- Behaviours
------------------------------------------------------------------------------
local Behaviors = {}

function Behaviors.Hunter(brain, now)
	local def = brain.Def
	local target, dist = nearestVisible(brain, def.Sight, def.FOV)
	local decoy = activeDecoy(brain.Root.Position, 70)
	if decoy and not (target and dist < 10) then
		brain.State = "Distracted"
		setChasing(brain, nil)
		setSpeed(brain, def.ChaseSpeed)
		pathTo(brain, decoy.Pos)
		return
	end
	if target then
		chase(brain, target, dist, def.ChaseSpeed)
		return
	end
	setChasing(brain, nil)
	if brain.State == "Chase" and now - brain.LastSeenTime < 6 then
		setSpeed(brain, def.ChaseSpeed * 0.9)
		if pathTo(brain, brain.LastSeen) then
			brain.State = "Search"
			brain.SearchUntil = now + 3
			stop(brain)
		end
		return
	end
	if brain.State == "Search" and now < brain.SearchUntil then
		return
	end
	roam(brain, now)
end

function Behaviors.Listener(brain, now)
	local def = brain.Def
	local pos = brain.Root.Position
	-- touch range: she can feel you
	local close, closeDist = nearestAny(brain, 9)
	if close then
		chase(brain, close, closeDist, def.ChaseSpeed)
		return
	end
	setChasing(brain, nil)
	local decoy = activeDecoy(pos, 90)
	if decoy then
		brain.State = "Investigate"
		brain.Goal = decoy.Pos
		brain.GoalTime = now
	else
		-- running guards & quiet footsteps nearby
		local heard, heardDist
		for _, t in ctx.GetTargets() do
			local d = (t.Root.Position - pos).Magnitude
			local radius = t.Sprinting and def.Hearing or 14
			if d < radius and (not heard or d < heardDist) then
				heard, heardDist = t, d
			end
		end
		if heard then
			brain.State = "Investigate"
			brain.Goal = heard.Root.Position
			brain.GoalTime = now
		else
			for i = #noises, 1, -1 do
				local n = noises[i]
				if now - n.Time > 3 then
					table.remove(noises, i)
				elseif (n.Pos - pos).Magnitude < n.Radius then
					brain.State = "Investigate"
					brain.Goal = n.Pos
					brain.GoalTime = now
					break
				end
			end
		end
	end
	if brain.State == "Investigate" then
		setSpeed(brain, def.ChaseSpeed)
		if pathTo(brain, brain.Goal) or now - brain.GoalTime > 10 then
			brain.State = "Search"
			brain.SearchUntil = now + 2.5
			stop(brain)
		end
		return
	end
	if brain.State == "Search" and now < brain.SearchUntil then
		return
	end
	roam(brain, now)
end

function Behaviors.Watcher(brain, now)
	local def = brain.Def
	if ctx.IsLit(brain.Head.Position, brain.Torso.Position) then
		if not brain.Model:GetAttribute("Frozen") then
			brain.Model:SetAttribute("Frozen", true)
		end
		brain.Humanoid.WalkSpeed = 0
		stop(brain)
		brain.UnfreezeAt = now + 0.7 -- small grace period once the light leaves him
		return
	end
	if brain.UnfreezeAt and now < brain.UnfreezeAt then
		return
	end
	brain.Model:SetAttribute("Frozen", false)
	local target, dist = nearestAny(brain, def.Sight)
	if target then
		chase(brain, target, dist, def.ChaseSpeed)
		return
	end
	setChasing(brain, nil)
	roam(brain, now)
end

function Behaviors.Stalker(brain, now)
	local def = brain.Def
	local decoy = activeDecoy(brain.Root.Position, 50)
	if decoy then
		setChasing(brain, nil)
		setSpeed(brain, def.ChaseSpeed)
		pathTo(brain, decoy.Pos)
		return
	end
	local target, dist = nearestAny(brain, 1000)
	if target then
		chase(brain, target, dist, def.ChaseSpeed)
	else
		roam(brain, now)
	end
end

------------------------------------------------------------------------------
-- Brain loop
------------------------------------------------------------------------------
local function tryCatch(brain, now: number): boolean
	local pos = brain.Root.Position
	for _, t in ctx.GetTargets() do
		local delta = t.Root.Position - pos
		if flat(delta).Magnitude < Config.CatchDistance + 1 and math.abs(delta.Y) < 7 then
			if lineOfSight(brain.Head.Position, t.Char, t.Root.Position) or flat(delta).Magnitude < 3 then
				if ctx.OnCatch(t.Player, brain.Name) then
					brain.PauseUntil = now + 3
					brain.State = "Roam"
					brain.RoamGoal = nil
					setChasing(brain, nil)
					stop(brain)
					return true
				end
			end
		end
	end
	return false
end

local function step(brain)
	local now = os.clock()
	if now < brain.WakeAt then
		return
	end
	if not brain.Model:GetAttribute("Awake") then
		brain.Model:SetAttribute("Awake", true)
	end
	if now < brain.PauseUntil then
		return
	end
	if brain.Def.Behavior ~= "Watcher" or not brain.Model:GetAttribute("Frozen") then
		if tryCatch(brain, now) then
			return
		end
	end
	Behaviors[brain.Def.Behavior](brain, now)

	-- stuck detection
	local pos = brain.Root.Position
	if brain.Moving and brain.Humanoid.WalkSpeed > 0 then
		if (pos - brain.LastPos).Magnitude < 0.4 then
			if now - brain.StuckSince > 2.5 then
				brain.StuckSince = now
				brain.StuckCount += 1
				brain.Waypoints = nil
				brain.RoamGoal = nil
				if brain.StuckCount >= 3 then
					brain.StuckCount = 0
					brain.Model:PivotTo(CFrame.new(nearestNav(pos) + Vector3.new(0, 2.5, 0)))
				end
			end
		else
			brain.StuckSince = now
			brain.StuckCount = 0
		end
	else
		brain.StuckSince = now
	end
	brain.LastPos = pos
end

-- Procedural walk animation (legs/arms swing with speed), 20 Hz to save bandwidth
local animAccum = 0
local function animate(dt: number)
	animAccum += dt
	if animAccum < 0.05 then
		return
	end
	local step_dt = animAccum
	animAccum = 0
	for _, brain in brains do
		if brain.Alive then
			local v = flat(brain.Root.AssemblyLinearVelocity).Magnitude
			brain.Phase += step_dt * v * 0.55
			local amp = math.clamp(v / 12, 0, 1) * 0.65
			local s = math.sin(brain.Phase) * amp
			for i, w in brain.Rig.Legs do
				local pivot, len = w:GetAttribute("Pivot"), w:GetAttribute("Length")
				w.C0 = pivot * CFrame.Angles(i == 1 and s or -s, 0, 0) * CFrame.new(0, -len / 2, 0)
			end
			local chasing = (brain.Model:GetAttribute("Target") or 0) ~= 0
			for i, w in brain.Rig.Arms do
				local pivot, len = w:GetAttribute("Pivot"), w:GetAttribute("Length")
				local angle = chasing and (-1.35 + (i == 1 and s or -s) * 0.25) or (i == 1 and -s or s)
				w.C0 = pivot * CFrame.Angles(angle, 0, 0) * CFrame.new(0, -len / 2, 0)
			end
			-- creepy head twitch
			if rng:NextNumber() < 0.04 then
				brain.HeadTilt = rng:NextNumber(-0.35, 0.35)
			end
			local hw = brain.Rig.Head
			hw.C0 = brain.HeadBase * CFrame.Angles(0, 0, brain.HeadTilt)
		end
	end
end

------------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------------
function AnimatronicService.Init(context, mapData)
	ctx = context
	map = mapData
	folder = Instance.new("Folder")
	folder.Name = "Animatronics"
	folder.Parent = workspace
	rayParams.FilterDescendantsInstances = { folder }
	rayParams.CollisionGroup = "Animatronics" -- ghosts don't collide with this group, so rays ignore them

	local templates = Instance.new("Folder")
	templates.Name = "AnimatronicTemplates"
	for _, name in Mascots.Order do
		Builder.Template(name).Parent = templates
	end
	templates.Parent = ReplicatedStorage

	RunService.Heartbeat:Connect(animate)
end

function AnimatronicService.Spawn(name: string, speedMult: number, wakeDelay: number?)
	if brains[name] then
		return brains[name]
	end
	local def = Mascots[name]
	local model, rig = Builder.Build(name)
	local spawns = map.Spawns[def.Spawn]
	local pos = spawns[rng:NextInteger(1, #spawns)]
	-- face the dining hall
	model:PivotTo(CFrame.lookAt(pos, Vector3.new(0, pos.Y, -10)))
	model.Parent = folder
	local root = model.PrimaryPart :: BasePart
	pcall(function()
		root:SetNetworkOwner(nil)
	end)

	local pupils = {}
	for _, d in model:GetDescendants() do
		if d.Name == "Pupil" then
			table.insert(pupils, d)
		end
	end

	local brain = {
		Name = name,
		Def = def,
		Model = model,
		Root = root,
		Head = model:FindFirstChild("Head") :: BasePart,
		Torso = model:FindFirstChild("Torso") :: BasePart,
		Humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid,
		Rig = rig,
		HeadBase = rig.Head.C0,
		HeadTilt = 0,
		Pupils = pupils,
		Path = PathfindingService:CreatePath({
			AgentRadius = 2.5,
			AgentHeight = 11,
			AgentCanJump = false,
			WaypointSpacing = 5,
		}),
		SpeedMult = speedMult,
		WakeAt = os.clock() + (wakeDelay or def.ActivateDelay),
		PauseUntil = 0,
		State = "Roam",
		LastSeenTime = 0,
		LastPos = root.Position,
		StuckSince = os.clock(),
		StuckCount = 0,
		Phase = 0,
		Alive = true,
	}
	brain.Humanoid.WalkSpeed = 0
	model:SetAttribute("Awake", false)
	model:SetAttribute("Target", 0)
	model:SetAttribute("DisplayName", def.DisplayName)
	brains[name] = brain

	task.spawn(function()
		while brain.Alive do
			local ok, err = pcall(step, brain)
			if not ok then
				warn("[Animatronic " .. name .. "] " .. tostring(err))
			end
			task.wait(0.15)
		end
	end)
	return brain
end

function AnimatronicService.Despawn(name: string)
	local brain = brains[name]
	if not brain then
		return
	end
	brain.Alive = false
	brains[name] = nil
	brain.Model:Destroy()
end

function AnimatronicService.DespawnAll()
	for name in brains do
		AnimatronicService.Despawn(name)
	end
	table.clear(noises)
	for _, d in decoys do
		if d.Part then
			d.Part:Destroy()
		end
	end
	table.clear(decoys)
end

function AnimatronicService.IsActive(name: string): boolean
	return brains[name] ~= nil
end

function AnimatronicService.AddNoise(pos: Vector3, radius: number)
	table.insert(noises, { Pos = pos, Radius = radius, Time = os.clock() })
	if #noises > 30 then
		table.remove(noises, 1)
	end
end

function AnimatronicService.AddDecoy(pos: Vector3, duration: number)
	local plush = Instance.new("Part")
	plush.Name = "DecoyPlush"
	plush.Shape = Enum.PartType.Ball
	plush.Size = Vector3.new(1.6, 1.6, 1.6)
	plush.Color = Color3.fromRGB(255, 150, 200)
	plush.Material = Enum.Material.Fabric
	plush.CFrame = CFrame.new(pos + Vector3.new(0, 1, 0))
	plush.CanCollide = true
	plush.Parent = workspace
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 120, 200)
	light.Range = 10
	light.Parent = plush
	plush.AssemblyLinearVelocity = Vector3.new(0, 18, 0)
	Debris:AddItem(plush, duration)
	table.insert(decoys, { Pos = pos, Expires = os.clock() + duration, Part = plush })
	AnimatronicService.AddNoise(pos, 90)
end

function AnimatronicService.Reveal(duration: number)
	for _, brain in brains do
		local hl = Instance.new("Highlight")
		hl.Name = "GhostReveal"
		hl.FillColor = Color3.fromRGB(255, 40, 40)
		hl.FillTransparency = 0.6
		hl.OutlineColor = Color3.fromRGB(255, 255, 255)
		hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		hl.Parent = brain.Model
		Debris:AddItem(hl, duration)
	end
end

return AnimatronicService
