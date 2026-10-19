--[[
	Night Shift at Pip's — server entry point.
	Builds the world, sets up lighting/physics, then starts every service.
]]

local Lighting = game:GetService("Lighting")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Cosmetics = require(Shared.Cosmetics)

local Server = script.Parent
local MapBuilder = require(Server.MapBuilder)
local DataService = require(Server.DataService)
local MonetizationService = require(Server.MonetizationService)
local PlayerService = require(Server.PlayerService)
local QuestService = require(Server.QuestService)
local LootService = require(Server.LootService)
local RoundService = require(Server.RoundService)

-- Collision groups ----------------------------------------------------------
for _, g in { "Players", "Ghosts", "Animatronics", "NPCBlock" } do
	pcall(function()
		PhysicsService:RegisterCollisionGroup(g)
	end)
end
PhysicsService:CollisionGroupSetCollidable("Ghosts", "Players", false)
PhysicsService:CollisionGroupSetCollidable("Ghosts", "Ghosts", false)
PhysicsService:CollisionGroupSetCollidable("Ghosts", "Animatronics", false)
PhysicsService:CollisionGroupSetCollidable("Ghosts", "NPCBlock", false)
PhysicsService:CollisionGroupSetCollidable("Players", "NPCBlock", false)
PhysicsService:CollisionGroupSetCollidable("Animatronics", "Animatronics", false)
PhysicsService:CollisionGroupSetCollidable("Default", "NPCBlock", false)

-- Lighting: spooky night ----------------------------------------------------
Lighting.ClockTime = 0.5
Lighting.Brightness = 1
Lighting.Ambient = Color3.fromRGB(28, 26, 38)
Lighting.OutdoorAmbient = Color3.fromRGB(45, 45, 70)
Lighting.EnvironmentDiffuseScale = 0.3
Lighting.EnvironmentSpecularScale = 0.5
Lighting.GlobalShadows = true
Lighting.ExposureCompensation = 0.1
for _, child in Lighting:GetChildren() do
	if child:IsA("PostEffect") or child:IsA("Atmosphere") or child:IsA("Sky") then
		child:Destroy()
	end
end
local atmosphere = Instance.new("Atmosphere")
atmosphere.Density = 0.38
atmosphere.Offset = 0.1
atmosphere.Color = Color3.fromRGB(70, 60, 100)
atmosphere.Decay = Color3.fromRGB(40, 30, 60)
atmosphere.Glare = 0
atmosphere.Haze = 2
atmosphere.Parent = Lighting
local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.8
bloom.Size = 30
bloom.Threshold = 1.4
bloom.Parent = Lighting
local cc = Instance.new("ColorCorrectionEffect")
cc.Name = "BaseGrade"
cc.Contrast = 0.12
cc.Saturation = -0.08
cc.TintColor = Color3.fromRGB(235, 230, 255)
cc.Parent = Lighting
local sky = Instance.new("Sky")
sky.StarCount = 3000
sky.MoonAngularSize = 14
sky.Parent = Lighting

-- World ---------------------------------------------------------------------
local map = MapBuilder.Build()

-- Services ------------------------------------------------------------------
DataService.Init()
MonetizationService.Init()
PlayerService.Init(map)
QuestService.Init(map)
LootService.Init(map)
RoundService.Init(map)

-- Lobby booths open UI panels
for _, pp in map.LobbyPrompts do
	pp.Triggered:Connect(function(player)
		Remotes.OpenUI:FireClient(player, pp:GetAttribute("UI"))
	end)
end

-- Players -------------------------------------------------------------------
local function onPlayerAdded(player: Player)
	local data = DataService.Load(player)
	if not data then
		return
	end
	MonetizationService.AwardBadge(player, "Welcome")
	MonetizationService.CheckGroup(player)
	PlayerService.ApplyCosmetics(player)
	DataService.Push(player)
end
Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in Players:GetPlayers() do
	task.spawn(onPlayerAdded, p)
end

-- Profile remotes -----------------------------------------------------------
Remotes.GetProfile.OnServerInvoke = function(player)
	DataService.Push(player)
	return RoundService.Snapshot()
end

Remotes.Equip.OnServerEvent:Connect(function(player, slot, id)
	local data = DataService.Get(player)
	if not data or typeof(slot) ~= "string" or (slot ~= "Light" and slot ~= "Trail" and slot ~= "Title") then
		return
	end
	if id == nil or id == false then
		if slot ~= "Light" then
			data.Equipped[slot] = nil
		end
	elseif typeof(id) == "string" and data.Owned[id] and Cosmetics.ById[id] and Cosmetics.ById[id].Type == slot then
		data.Equipped[slot] = id
	else
		return
	end
	PlayerService.ApplyCosmetics(player)
	DataService.Push(player)
end)

Remotes.ClaimDaily.OnServerEvent:Connect(function(player)
	local data = DataService.Get(player)
	if not data or not DataService.DailyAvailable(player) then
		return
	end
	local now = os.time()
	if now - data.LastDaily > Config.Daily.StreakBreak then
		data.DailyStreak = 0
	end
	data.DailyStreak = math.min(data.DailyStreak + 1, Config.Daily.MaxStreak)
	data.LastDaily = now
	local amount = Config.Daily.Base + Config.Daily.PerStreak * (data.DailyStreak - 1)
	DataService.AddTickets(player, amount, true)
	Remotes.Reward:FireClient(player, {
		Rarity = data.DailyStreak >= Config.Daily.MaxStreak and "Legendary" or (data.DailyStreak >= 4 and "Epic" or "Rare"),
		Title = ("+%d 🎟"):format(amount),
		Text = ("Daily reward — day %d streak! Come back tomorrow for more."):format(data.DailyStreak),
	})
	DataService.Push(player)
end)

Remotes.TutorialDone.OnServerEvent:Connect(function(player)
	local data = DataService.Get(player)
	if data and not data.Tutorial then
		data.Tutorial = true
		DataService.AddTickets(player, 50, true)
		Remotes.Notify:FireClient(player, "Welcome bonus: +50 🎟. Go win prizes!", "Good")
	end
end)

print(("[%s] server ready"):format(Config.GameName))
