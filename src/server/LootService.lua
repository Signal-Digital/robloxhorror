--[[
	LootService — in-game loot spawned every night:
	  * Prize tickets (persistent currency) scattered on the floor
	  * Batteries
	  * Prize Capsules: hold E to crack them open -> random reward with rarity
	    (items, ticket bundles, or a rare permanent cosmetic!)
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Items = require(Shared.Items)
local Cosmetics = require(Shared.Cosmetics)
local DataService = require(script.Parent.DataService)
local PlayerService = require(script.Parent.PlayerService)
local AnimatronicService = require(script.Parent.AnimatronicService)
local MonetizationService = require(script.Parent.MonetizationService)

local LootService = {}

local map
local lootFolder: Folder?
local rng = Random.new()

-- RoundService hook to track tickets earned during the night (for the results screen)
LootService.OnTickets = function(_player: Player, _amount: number) end

local function C(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local function pickup(part: BasePart, onTake: (Player) -> boolean)
	local taken = false
	part.Touched:Connect(function(hit)
		if taken then
			return
		end
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if player and PlayerService.IsActive(player) and onTake(player) then
			taken = true
			part:Destroy()
		end
	end)
end

local function spawnTickets(pos: Vector3)
	local p = Instance.new("Part")
	p.Name = "Tickets"
	p.Size = Vector3.new(1.4, 0.2, 0.8)
	p.CFrame = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi), math.rad(20))
	p.Color = C(255, 90, 140)
	p.Material = Enum.Material.Neon
	p.Anchored = true
	p.CanCollide = false
	CollectionService:AddTag(p, "Spin")
	local sparkle = Instance.new("Sparkles")
	sparkle.SparkleColor = C(255, 150, 200)
	sparkle.Parent = p
	p.Parent = lootFolder
	pickup(p, function(player)
		local amount = DataService.AddTickets(player, rng:NextInteger(Config.Rewards.TicketPickupMin, Config.Rewards.TicketPickupMax))
		LootService.OnTickets(player, amount)
		Remotes.Notify:FireClient(player, ("+%d 🎟"):format(amount), "Ticket")
		return true
	end)
end

local function spawnBattery(pos: Vector3)
	local p = Instance.new("Part")
	p.Name = "BatteryPickup"
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(1.4, 0.7, 0.7)
	p.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
	p.Color = C(60, 220, 90)
	p.Material = Enum.Material.Neon
	p.Anchored = true
	p.CanCollide = false
	CollectionService:AddTag(p, "Spin")
	local l = Instance.new("PointLight")
	l.Color = C(60, 255, 90)
	l.Range = 7
	l.Parent = p
	p.Parent = lootFolder
	pickup(p, function(player)
		if PlayerService.GiveItem(player, "Battery") then
			Remotes.Notify:FireClient(player, "🔋 Battery found! (press 1)", "Good")
			return true
		end
		return false
	end)
end

local function grantCapsule(player: Player)
	local entry = Items.RollCapsule(rng)
	local reward = { Rarity = entry.Rarity, Title = "", Text = "" }
	if entry.Kind == "Item" then
		local def = Items.Defs[entry.Item]
		if not PlayerService.GiveItem(player, entry.Item) then
			local amount = DataService.AddTickets(player, 15)
			LootService.OnTickets(player, amount)
			reward.Title = ("+%d 🎟"):format(amount)
			reward.Text = "Your " .. def.Name .. " pocket was full"
		else
			reward.Title = def.Icon .. " " .. def.Name
			reward.Text = def.Desc
		end
	elseif entry.Kind == "Tickets" then
		local amount = DataService.AddTickets(player, entry.Amount)
		LootService.OnTickets(player, amount)
		reward.Title = ("+%d 🎟"):format(amount)
		reward.Text = "Prize tickets!"
	else
		local data = DataService.Get(player)
		local rarity = rng:NextNumber() < 0.25 and "Legendary" or "Epic"
		local item = Cosmetics.RandomOfRarity(rarity, rng)
		reward.Rarity = rarity
		if data and not data.Owned[item.Id] then
			data.Owned[item.Id] = true
			reward.Title = "✨ " .. item.Name
			reward.Text = "New " .. item.Type:lower() .. " cosmetic! Equip it in the Wardrobe."
			if rarity == "Legendary" then
				MonetizationService.AwardBadge(player, "Legendary")
			end
			DataService.Push(player)
		else
			local amount = DataService.AddTickets(player, Config.DuplicateRefund[rarity], true)
			reward.Title = ("+%d 🎟"):format(amount)
			reward.Text = "Duplicate " .. item.Name
		end
		for _, p in Players:GetPlayers() do
			Remotes.Notify:FireClient(p, ("🌟 %s found a %s cosmetic in a capsule!"):format(player.DisplayName, rarity:upper()), "Good")
		end
	end
	Remotes.Reward:FireClient(player, reward)
end

local function spawnCapsule(pos: Vector3)
	local model = Instance.new("Model")
	model.Name = "PrizeCapsule"
	local colors = { C(255, 80, 160), C(80, 200, 255), C(255, 210, 60), C(150, 90, 255) }
	local color = colors[rng:NextInteger(1, #colors)]
	local bottom = Instance.new("Part")
	bottom.Name = "Bottom"
	bottom.Shape = Enum.PartType.Ball
	bottom.Size = Vector3.new(2.4, 2.4, 2.4)
	bottom.CFrame = CFrame.new(pos + Vector3.new(0, -0.6, 0))
	bottom.Color = C(245, 245, 245)
	bottom.Material = Enum.Material.SmoothPlastic
	bottom.Anchored = true
	bottom.Parent = model
	local top = Instance.new("Part")
	top.Name = "Top"
	top.Shape = Enum.PartType.Ball
	top.Size = Vector3.new(2.45, 2.45, 2.45)
	top.CFrame = CFrame.new(pos + Vector3.new(0, -0.35, 0))
	top.Color = color
	top.Material = Enum.Material.Glass
	top.Transparency = 0.3
	top.Anchored = true
	top.CanCollide = false
	top.Parent = model
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 10
	light.Brightness = 1.5
	light.Parent = top
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = "Open"
	pp.ObjectText = "Prize Capsule"
	pp.HoldDuration = 1.5
	pp.RequiresLineOfSight = false
	pp.MaxActivationDistance = 8
	pp.Parent = bottom
	model.PrimaryPart = bottom
	model.Parent = lootFolder
	local opened = false
	pp.PromptButtonHoldBegan:Connect(function()
		AnimatronicService.AddNoise(pos, 40)
	end)
	pp.Triggered:Connect(function(player)
		if opened or not PlayerService.IsActive(player) then
			return
		end
		opened = true
		model:Destroy()
		grantCapsule(player)
	end)
end

function LootService.Spawn(playerCount: number)
	LootService.Cleanup()
	lootFolder = Instance.new("Folder")
	lootFolder.Name = "Loot"
	lootFolder.Parent = workspace
	for _ = 1, 14 + playerCount * 2 do
		spawnTickets(map.RandomSpot() + Vector3.new(0, -1.6, 0))
	end
	for _ = 1, 3 + math.ceil(playerCount / 2) do
		spawnBattery(map.RandomSpot() + Vector3.new(0, -1.2, 0))
	end
	for _ = 1, 3 + math.floor(playerCount / 3) do
		spawnCapsule(map.RandomSpot() + Vector3.new(0, -0.5, 0))
	end
end

function LootService.Cleanup()
	if lootFolder then
		lootFolder:Destroy()
		lootFolder = nil
	end
end

------------------------------------------------------------------------------
-- Prize Counter (lobby gacha, spend tickets on cosmetic capsules)
------------------------------------------------------------------------------
local function rollPrize(player: Player, tier: string)
	if typeof(tier) ~= "string" or not Config.CapsuleCosts[tier] then
		return { Ok = false, Error = "Invalid capsule" }
	end
	local data = DataService.Get(player)
	if not data then
		return { Ok = false, Error = "Profile still loading" }
	end
	if not DataService.SpendTickets(player, Config.CapsuleCosts[tier]) then
		return { Ok = false, Error = "Not enough tickets! Survive nights to earn more." }
	end
	local lucky = MonetizationService.HasPass(player, "LuckyCharm")
	local rarity = Cosmetics.RollRarity(tier, lucky, rng)
	local item = Cosmetics.RandomOfRarity(rarity, rng)
	local duplicate = data.Owned[item.Id] == true
	local refund = 0
	if duplicate then
		refund = DataService.AddTickets(player, Config.DuplicateRefund[rarity], true)
	else
		data.Owned[item.Id] = true
		DataService.Push(player)
	end
	if rarity == "Legendary" then
		MonetizationService.AwardBadge(player, "Legendary")
		for _, p in Players:GetPlayers() do
			Remotes.Notify:FireClient(p, ("🌟 %s won the LEGENDARY %s!"):format(player.DisplayName, item.Name), "Good")
		end
	end
	return { Ok = true, Id = item.Id, Name = item.Name, Type = item.Type, Rarity = rarity, Duplicate = duplicate, Refund = refund }
end

function LootService.Init(mapData)
	map = mapData
	Remotes.RollCapsule.OnServerInvoke = rollPrize
end

return LootService
