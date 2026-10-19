--[[
	Effects — atmosphere and danger feedback, all client-side:
	  * lights flicker when a mascot is near (the #1 "danger" cue)
	  * red vignette + tint + camera shake as a mascot gets closer
	  * "X IS CHASING YOU" banner, ghost colour grading
	  * spinning loot, ambience/chase sounds, lobby shift board
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local player = Players.LocalPlayer

local Effects = {}

local sounds: { [string]: Sound } = {}

function Effects.Sound(name: string, looped: boolean?): Sound?
	local id = Config.Sounds[name]
	if not id or id == "" then
		return nil
	end
	if sounds[name] then
		return sounds[name]
	end
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = id:match("^rbxassetid://") and id or ("rbxassetid://" .. id)
	s.Looped = looped == true
	s.Parent = SoundService
	sounds[name] = s
	return s
end

function Effects.Play(name: string, volume: number?)
	local s = Effects.Sound(name)
	if s then
		s.Volume = volume or 0.8
		s:Play()
	end
end

local function makeVignette(gui: ScreenGui)
	local holder = Instance.new("Frame")
	holder.Name = "Vignette"
	holder.Size = UDim2.fromScale(1, 1)
	holder.BackgroundTransparency = 1
	holder.Parent = gui
	local edges = {}
	for _, spec in {
		{ UDim2.fromScale(1, 0.35), UDim2.fromScale(0, 0), 90 },
		{ UDim2.fromScale(1, 0.35), UDim2.fromScale(0, 0.65), -90 },
		{ UDim2.fromScale(0.3, 1), UDim2.fromScale(0, 0), 0 },
		{ UDim2.fromScale(0.3, 1), UDim2.fromScale(0.7, 0), 180 },
	} do
		local f = Instance.new("Frame")
		f.Size = spec[1]
		f.Position = spec[2]
		f.BorderSizePixel = 0
		f.BackgroundColor3 = Color3.fromRGB(160, 0, 0)
		f.BackgroundTransparency = 1
		local g = Instance.new("UIGradient")
		g.Rotation = spec[3]
		g.Transparency = NumberSequence.new(0, 1)
		g.Parent = f
		f.Parent = holder
		table.insert(edges, f)
	end
	return edges
end

function Effects.Init(UI)
	local gui = Instance.new("ScreenGui")
	gui.Name = "Effects"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = -1
	gui.Parent = player:WaitForChild("PlayerGui")
	local edges = makeVignette(gui)

	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "LocalGrade"
	grade.Parent = Lighting

	local ambience = Effects.Sound("Ambience", true)
	if ambience then
		ambience.Volume = 0.4
		ambience:Play()
	end
	local heartbeat = Effects.Sound("Heartbeat", true)
	local chaseMusic = Effects.Sound("Chase", true)

	-- base brightness of every ceiling light (for flickering)
	local lights = {}
	local mapFolder = workspace:WaitForChild("Map", 30)
	local lightFolder = mapFolder and mapFolder:WaitForChild("Lights", 10)
	if lightFolder then
		for _, d in lightFolder:GetDescendants() do
			if d:IsA("PointLight") or d:IsA("SpotLight") then
				local parentPart = d.Parent :: BasePart
				table.insert(lights, { Light = d, Base = d.Brightness, Pos = parentPart.Position })
			end
		end
	end

	local accum = 0
	local danger = 0
	local animFolder = workspace:WaitForChild("Animatronics", 30)
	RunService.RenderStepped:Connect(function(dt)
		-- spinning loot (local only)
		for _, p in CollectionService:GetTagged("Spin") do
			if p:IsA("BasePart") and p.Parent then
				p.CFrame = CFrame.new(p.Position) * CFrame.Angles(0, dt * 2.2, 0) * (p.CFrame - p.Position)
			end
		end

		accum += dt
		if accum < 0.08 then
			return
		end
		local stepDt = accum
		accum = 0

		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local inNight = player:GetAttribute("InNight") == true
		local ghost = player:GetAttribute("Ghost") == true

		-- nearest awake mascot + chase detection
		local nearest = math.huge
		local chasedBy = nil
		local awakePositions = {}
		if animFolder then
			for _, model in animFolder:GetChildren() do
				local r = model:FindFirstChild("HumanoidRootPart") :: BasePart?
				if r and model:GetAttribute("Awake") then
					table.insert(awakePositions, r.Position)
					if hrp then
						nearest = math.min(nearest, (r.Position - hrp.Position).Magnitude)
					end
					if model:GetAttribute("Target") == player.UserId then
						chasedBy = model:GetAttribute("DisplayName") or model.Name
					end
				end
			end
		end
		UI.Chased = (inNight and not ghost) and chasedBy or nil

		-- flicker lights near awake mascots
		for _, entry in lights do
			local near = false
			for _, pos in awakePositions do
				if (pos - entry.Pos).Magnitude < 32 then
					near = true
					break
				end
			end
			if near then
				entry.Light.Brightness = math.random() < 0.35 and entry.Base * 0.08 or entry.Base * (0.6 + math.random() * 0.5)
				entry.Flickering = true
			elseif entry.Flickering then
				entry.Light.Brightness = entry.Base
				entry.Flickering = false
			end
		end

		-- danger level
		local target = 0
		if inNight and not ghost then
			target = math.clamp(1 - (nearest - 8) / 45, 0, 1)
			if chasedBy then
				target = math.max(target, 0.55)
			end
		end
		danger += (target - danger) * math.clamp(stepDt * 4, 0, 1)
		for _, e in edges do
			e.BackgroundTransparency = 1 - danger * 0.85
		end
		if ghost and inNight then
			grade.Saturation = -0.75
			grade.TintColor = Color3.fromRGB(190, 220, 255)
			grade.Brightness = 0.05
		else
			grade.Saturation = -danger * 0.3
			grade.TintColor = Color3.new(1, 1 - danger * 0.35, 1 - danger * 0.35)
			grade.Brightness = 0
		end
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			if danger > 0.7 then
				local s = (danger - 0.7) * 0.8
				hum.CameraOffset = Vector3.new((math.random() - 0.5) * s, (math.random() - 0.5) * s, 0)
			else
				hum.CameraOffset = Vector3.zero
			end
		end
		if heartbeat then
			heartbeat.Volume = danger
			if danger > 0.05 and not heartbeat.IsPlaying then
				heartbeat:Play()
			elseif danger <= 0.05 and heartbeat.IsPlaying then
				heartbeat:Stop()
			end
		end
		if chaseMusic then
			if UI.Chased and not chaseMusic.IsPlaying then
				chaseMusic.Volume = 0.6
				chaseMusic:Play()
			elseif not UI.Chased and chaseMusic.IsPlaying then
				chaseMusic:Stop()
			end
		end
	end)

	-- lobby shift board (live countdown)
	local board = mapFolder and mapFolder:FindFirstChild("ShiftBoard", true)
	local boardLabel = board and board:FindFirstChildOfClass("SurfaceGui") and board:FindFirstChildOfClass("SurfaceGui"):FindFirstChild("Label")
	-- 3D lullaby on the music box: slows down as it unwinds
	local boxPart = mapFolder and mapFolder:FindFirstChild("MusicBox", true)
	local lullaby
	local id = Config.Sounds.MusicBox
	if boxPart and id and id ~= "" then
		lullaby = Instance.new("Sound")
		lullaby.Name = "Lullaby"
		lullaby.SoundId = id:match("^rbxassetid://") and id or ("rbxassetid://" .. id)
		lullaby.Looped = true
		lullaby.Volume = 0.7
		lullaby.RollOffMaxDistance = 70
		lullaby.RollOffMinDistance = 8
		lullaby.Parent = boxPart
	end

	local lastPhase = nil
	Remotes.GameState.OnClientEvent:Connect(function(s)
		if lullaby then
			local on = s.Phase == "Night" and s.MusicBox ~= nil and s.MusicBox > 0
			if on then
				lullaby.PlaybackSpeed = 0.75 + 0.25 * (s.MusicBox / 100)
				if not lullaby.IsPlaying then
					lullaby:Play()
				end
			elseif lullaby.IsPlaying then
				lullaby:Stop()
			end
		end
		if boardLabel then
			if s.Phase == "Intermission" then
				boardLabel.Text = ("%s STARTS IN %d"):format(s.NightName, s.TimeLeft)
			elseif s.Phase == "Night" then
				boardLabel.Text = ("%s — %d/%d GUARDS ALIVE"):format(s.NightName, s.Alive, s.Total)
			else
				boardLabel.Text = s.Message
			end
		end
		if s.Phase ~= lastPhase then
			if s.Phase == "Results" and lastPhase == "Night" then
				Effects.Play("SixAM", 0.8)
			end
			lastPhase = s.Phase
		end
	end)

	-- pickup / repair sounds
	Remotes.Notify.OnClientEvent:Connect(function(_text, kind)
		if kind == "Ticket" then
			Effects.Play("Pickup", 0.5)
		end
	end)
	Remotes.Reward.OnClientEvent:Connect(function()
		Effects.Play("Capsule", 0.7)
	end)
end

return Effects
