--[[
	QuestService — the night's task list (clear objectives):
	  Fuses   : hold E on broken fuse boxes (each one turns the lights back on in its zone)
	  Tokens  : grab golden party tokens scattered around
	  Tape    : carry the mysterious tape to the VCR in the Security Office
	  Gas     : carry gas cans to the generator in Parts & Service
	  Escape  : once everything is done, the front doors open -> run!
	Plus the Music Box (night 4+): keep it wound or Jinx wakes up.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local PlayerService = require(script.Parent.PlayerService)
local AnimatronicService = require(script.Parent.AnimatronicService)

local QuestService = {}

local map
local rng = Random.new()
local nightFolder: Folder?
local objectives = {}
local fusesActive = {}
local items = {} -- delivery items
local carriers: { [Player]: any } = {}
local connections = {}
local musicBox = nil -- { Value, Drain, Warned }
local speedMult = 1
local exitOpen = false

-- callbacks (wired by RoundService)
QuestService.Changed = function() end
QuestService.OnAction = function(_player: Player, _kind: string) end
QuestService.OnObjectiveComplete = function(_obj) end
QuestService.OnAllComplete = function() end
QuestService.OnEscape = function(_player: Player) end

local TEXT = {
	Fuses = "Repair the fuse boxes",
	Tokens = "Collect party tokens",
	Tape = "Bring the tape to the Security Office VCR",
	Gas = "Refuel the generator (Parts & Service)",
	Escape = "ESCAPE through the front doors!",
}

local function C(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local function connect(signal, fn)
	local c = signal:Connect(fn)
	table.insert(connections, c)
	return c
end

local function markTarget(inst: Instance, label: string, active: boolean, forCarry: string?)
	inst:SetAttribute("Label", label)
	inst:SetAttribute("Active", active)
	inst:SetAttribute("ForCarry", forCarry or "")
	if not CollectionService:HasTag(inst, "ObjectiveTarget") then
		CollectionService:AddTag(inst, "ObjectiveTarget")
	end
end

local function getObjective(id: string)
	for _, o in objectives do
		if o.Id == id then
			return o
		end
	end
	return nil
end

local function allMandatoryDone(): boolean
	for _, o in objectives do
		if o.Id ~= "Escape" and not o.Done then
			return false
		end
	end
	return true
end

function QuestService.OpenExit()
	if exitOpen then
		return
	end
	exitOpen = true
	local door = map.FrontDoor
	door.Glass.CanCollide = false
	door.Glass.Transparency = 0.9
	door.Sign.Color = C(20, 160, 50)
	door.Label.Text = "EXIT ➜"
	markTarget(door.Zone, "EXIT", true)
	table.insert(objectives, { Id = "Escape", Text = TEXT.Escape, Progress = 0, Goal = 1, Done = false })
end

local function closeExit()
	exitOpen = false
	local door = map.FrontDoor
	door.Glass.CanCollide = true
	door.Glass.Transparency = 0.5
	door.Sign.Color = C(120, 20, 20)
	door.Label.Text = "LOCKED"
	door.Zone:SetAttribute("Active", false)
end

local function progress(id: string, player: Player?)
	local o = getObjective(id)
	if not o or o.Done then
		return
	end
	o.Progress += 1
	if player then
		QuestService.OnAction(player, id)
	end
	if o.Progress >= o.Goal then
		o.Done = true
		QuestService.OnObjectiveComplete(o)
		if allMandatoryDone() and not exitOpen then
			QuestService.OpenExit()
			QuestService.OnAllComplete()
		end
	end
	QuestService.Changed()
end

------------------------------------------------------------------------------
-- Fuses
------------------------------------------------------------------------------
local function setFuseVisual(fuse, broken: boolean)
	fuse.Lamp.Color = broken and C(255, 40, 40) or C(40, 255, 90)
	fuse.Sparks.Rate = broken and 6 or 0
	local cf = fuse.Box.CFrame
	fuse.Lever.CFrame = cf * CFrame.new(-0.6, -0.4, -0.55) * CFrame.Angles(math.rad(broken and -30 or 30), 0, 0)
end

local function setupFuses(count: number)
	for name in map.Rooms do
		map.SetRoomLights(name, true)
	end
	local pool = table.clone(map.FuseBoxes)
	for i = #pool, 2, -1 do
		local j = rng:NextInteger(1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end
	table.clear(fusesActive)
	for _, fuse in map.FuseBoxes do
		setFuseVisual(fuse, false)
		fuse.Prompt.Enabled = false
		markTarget(fuse.Box, "Fuse Box", false)
	end
	for i = 1, math.min(count, #pool) do
		local fuse = pool[i]
		fuse.Broken = true
		fusesActive[fuse] = true
		setFuseVisual(fuse, true)
		fuse.Prompt.Enabled = true
		markTarget(fuse.Box, "Fuse Box", true)
		for _, room in fuse.Zone do
			map.SetRoomLights(room, false)
		end
	end
	table.insert(objectives, { Id = "Fuses", Text = TEXT.Fuses, Progress = 0, Goal = math.min(count, #pool), Done = false })
end

------------------------------------------------------------------------------
-- Tokens
------------------------------------------------------------------------------
local function spawnToken(pos: Vector3)
	local token = Instance.new("Part")
	token.Name = "PartyToken"
	token.Shape = Enum.PartType.Cylinder
	token.Size = Vector3.new(0.4, 2.2, 2.2)
	token.CFrame = CFrame.new(pos)
	token.Color = C(255, 200, 40)
	token.Material = Enum.Material.Neon
	token.Anchored = true
	token.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = C(255, 200, 60)
	light.Range = 8
	light.Brightness = 1.2
	light.Parent = token
	markTarget(token, "Token", true)
	CollectionService:AddTag(token, "Spin")
	token.Parent = nightFolder
	local taken = false
	token.Touched:Connect(function(hit)
		if taken then
			return
		end
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if player and PlayerService.IsActive(player) then
			taken = true
			token:Destroy()
			progress("Tokens", player)
		end
	end)
end

------------------------------------------------------------------------------
-- Deliveries (tape / gas)
------------------------------------------------------------------------------
local function itemVisual(kind: string): Part
	local p = Instance.new("Part")
	p.CanCollide = false
	p.Massless = true
	if kind == "Tape" then
		p.Size = Vector3.new(1.6, 0.4, 1)
		p.Color = C(25, 25, 25)
	else
		p.Size = Vector3.new(1.4, 1.8, 0.8)
		p.Color = C(210, 30, 30)
		p.Material = Enum.Material.Metal
	end
	return p
end

local function attachToHand(player: Player, kind: string)
	local char = player.Character
	local hand = char and (char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")) :: BasePart?
	if not hand then
		return nil
	end
	local v = itemVisual(kind)
	v.Name = "Carried"
	v.Anchored = false
	v.CFrame = hand.CFrame * CFrame.new(0, -0.6, -0.4)
	local w = Instance.new("WeldConstraint")
	w.Part0 = hand
	w.Part1 = v
	w.Parent = v
	v.Parent = char
	return v
end

local function placeItem(item, pos: Vector3)
	item.Part.CFrame = CFrame.new(pos)
	item.Part.Transparency = 0
	item.Prompt.Enabled = true
	item.Part:SetAttribute("Active", true)
	item.Holder = nil
end

local function spawnDelivery(kind: string, count: number)
	local exclude = kind == "Tape" and { Security = true } or { Parts = true }
	for _ = 1, count do
		local part = itemVisual(kind)
		part.Name = kind
		part.Anchored = true
		local glow = Instance.new("PointLight")
		glow.Color = kind == "Tape" and C(150, 150, 255) or C(255, 120, 60)
		glow.Range = 8
		glow.Parent = part
		local pp = Instance.new("ProximityPrompt")
		pp.ActionText = "Pick up"
		pp.ObjectText = kind == "Tape" and "Strange Tape" or "Gas Can"
		pp.HoldDuration = 0.3
		pp.RequiresLineOfSight = false
		pp.MaxActivationDistance = 8
		pp.Parent = part
		markTarget(part, kind == "Tape" and "Tape" or "Gas Can", true)
		part.Parent = nightFolder
		local item = { Kind = kind, Part = part, Prompt = pp, Holder = nil }
		placeItem(item, map.RandomSpot(nil, exclude))
		table.insert(items, item)
		connect(pp.Triggered, function(player)
			if item.Holder or not PlayerService.IsActive(player) then
				return
			end
			if (player:GetAttribute("Carrying") or "") ~= "" then
				Remotes.Notify:FireClient(player, "Your hands are full! Deliver what you carry first.", "Bad")
				return
			end
			item.Holder = player
			carriers[player] = item
			player:SetAttribute("Carrying", kind)
			item.Part.Transparency = 1
			item.Prompt.Enabled = false
			item.Part:SetAttribute("Active", false)
			item.Visual = attachToHand(player, kind)
			Remotes.Notify:FireClient(player, kind == "Tape" and "📼 Bring it to the VCR in the Security Office!" or "⛽ Bring it to the generator in Parts & Service!", "Info")
			QuestService.Changed()
		end)
	end
	table.insert(objectives, { Id = kind, Text = TEXT[kind], Progress = 0, Goal = count, Done = false })
end

local function deliver(player: Player, kind: string)
	local item = carriers[player]
	if not item or item.Kind ~= kind then
		local want = kind == "Tape" and "the strange tape" or "a gas can"
		Remotes.Notify:FireClient(player, "You need " .. want .. " first!", "Info")
		return
	end
	carriers[player] = nil
	player:SetAttribute("Carrying", "")
	if item.Visual then
		item.Visual:Destroy()
	end
	item.Part:Destroy()
	progress(kind, player)
	if kind == "Gas" then
		AnimatronicService.AddNoise(map.Generator.Part.Position, 50)
	end
end

function QuestService.DropCarry(player: Player)
	local item = carriers[player]
	if not item then
		return
	end
	carriers[player] = nil
	player:SetAttribute("Carrying", "")
	if item.Visual then
		item.Visual:Destroy()
		item.Visual = nil
	end
	local char = player.Character
	local r = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local pos = r and Vector3.new(r.Position.X, 2.6, r.Position.Z) or map.RandomSpot()
	if not map.RoomAt(pos) then
		pos = map.RandomSpot()
	end
	placeItem(item, pos)
end

------------------------------------------------------------------------------
-- Music box
------------------------------------------------------------------------------
local function setupMusicBox(enabled: boolean, night: number)
	map.MusicBox.Prompt.Enabled = enabled
	markTarget(map.MusicBox.Part, "Music Box", false)
	if enabled then
		musicBox = { Value = 100, Drain = night >= 5 and 2.1 or 1.6, Warned = false }
	else
		musicBox = nil
	end
end

function QuestService.Tick(dt: number)
	if not musicBox then
		return
	end
	local before = musicBox.Value
	musicBox.Value = math.max(0, musicBox.Value - musicBox.Drain * dt)
	map.MusicBox.Part:SetAttribute("Active", musicBox.Value < 50)
	if musicBox.Value < 30 and not musicBox.Warned then
		musicBox.Warned = true
		for _, p in Players:GetPlayers() do
			if p:GetAttribute("InNight") then
				Remotes.Notify:FireClient(p, "🎵 The music box is running out! Wind it in the Security Office!", "Bad")
			end
		end
	end
	if before > 0 and musicBox.Value <= 0 and not AnimatronicService.IsActive("Jinx") then
		AnimatronicService.Spawn("Jinx", speedMult, 2)
		for _, p in Players:GetPlayers() do
			if p:GetAttribute("InNight") then
				Remotes.Notify:FireClient(p, "🃏 The music stopped... JINX IS OUT!", "Big")
			end
		end
	end
end

function QuestService.MusicBoxValue(): number?
	return musicBox and math.floor(musicBox.Value) or nil
end

------------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------------
function QuestService.Setup(cfg, night: number, playerCount: number)
	QuestService.Cleanup()
	nightFolder = Instance.new("Folder")
	nightFolder.Name = "NightObjects"
	nightFolder.Parent = workspace
	speedMult = cfg.SpeedMult

	setupFuses(cfg.Fuses)

	local tokenCount = cfg.Tokens + math.min(6, math.max(0, playerCount - 1))
	for _ = 1, tokenCount do
		spawnToken(map.RandomSpot())
	end
	table.insert(objectives, { Id = "Tokens", Text = TEXT.Tokens, Progress = 0, Goal = tokenCount, Done = false })

	for _, d in cfg.Deliveries do
		spawnDelivery(d.Kind, d.Count)
	end
	markTarget(map.VCR.Part, "VCR", getObjective("Tape") ~= nil, "Tape")
	markTarget(map.Generator.Part, "Generator", getObjective("Gas") ~= nil, "Gas")

	setupMusicBox(cfg.MusicBox, night)
	QuestService.Changed()
end

function QuestService.Cleanup()
	for _, c in connections do
		c:Disconnect()
	end
	table.clear(connections)
	for player in carriers do
		player:SetAttribute("Carrying", "")
		local item = carriers[player]
		if item.Visual then
			item.Visual:Destroy()
		end
	end
	table.clear(carriers)
	table.clear(items)
	table.clear(objectives)
	if nightFolder then
		nightFolder:Destroy()
		nightFolder = nil
	end
	for _, fuse in map.FuseBoxes do
		fuse.Broken = false
		fuse.Prompt.Enabled = false
		setFuseVisual(fuse, false)
		fuse.Box:SetAttribute("Active", false)
	end
	for name in map.Rooms do
		map.SetRoomLights(name, true)
	end
	map.VCR.Part:SetAttribute("Active", false)
	map.Generator.Part:SetAttribute("Active", false)
	map.MusicBox.Prompt.Enabled = false
	map.MusicBox.Part:SetAttribute("Active", false)
	musicBox = nil
	closeExit()
end

function QuestService.GetObjectives()
	local out = {}
	for _, o in objectives do
		table.insert(out, { Id = o.Id, Text = o.Text, Progress = o.Progress, Goal = o.Goal, Done = o.Done })
	end
	return out
end

function QuestService.ExitOpen(): boolean
	return exitOpen
end

function QuestService.Init(mapData)
	map = mapData

	for _, fuse in map.FuseBoxes do
		fuse.Prompt.PromptButtonHoldBegan:Connect(function()
			-- repairs are noisy: Maple will come and check
			AnimatronicService.AddNoise(fuse.Box.Position, 55)
		end)
		fuse.Prompt.Triggered:Connect(function(player)
			if not fuse.Broken or not PlayerService.IsActive(player) then
				return
			end
			fuse.Broken = false
			fusesActive[fuse] = nil
			fuse.Prompt.Enabled = false
			setFuseVisual(fuse, false)
			fuse.Box:SetAttribute("Active", false)
			for _, room in fuse.Zone do
				map.SetRoomLights(room, true)
			end
			fuse.Sparks:Emit(30)
			progress("Fuses", player)
		end)
	end

	map.VCR.Prompt.Triggered:Connect(function(player)
		if PlayerService.IsActive(player) and getObjective("Tape") then
			deliver(player, "Tape")
		end
	end)
	map.Generator.Prompt.Triggered:Connect(function(player)
		if PlayerService.IsActive(player) and getObjective("Gas") then
			deliver(player, "Gas")
		end
	end)

	map.MusicBox.Prompt.Triggered:Connect(function(player)
		if not musicBox or not PlayerService.IsActive(player) then
			return
		end
		musicBox.Value = math.min(100, musicBox.Value + 40)
		if musicBox.Value >= 30 then
			musicBox.Warned = false
		end
		QuestService.OnAction(player, "MusicBox")
		if AnimatronicService.IsActive("Jinx") and musicBox.Value >= 60 then
			AnimatronicService.Despawn("Jinx")
			for _, p in Players:GetPlayers() do
				if p:GetAttribute("InNight") then
					Remotes.Notify:FireClient(p, ("🎵 %s wound the music box. Jinx went back to sleep..."):format(player.DisplayName), "Good")
				end
			end
		end
	end)

	map.FrontDoor.Zone.Touched:Connect(function(hit)
		if not exitOpen then
			return
		end
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if player and PlayerService.IsActive(player) then
			QuestService.OnEscape(player)
		end
	end)
end

return QuestService
