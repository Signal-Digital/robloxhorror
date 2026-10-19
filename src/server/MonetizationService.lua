--[[
	MonetizationService — game passes, developer products, group bonus, badges.
	IDs come from Config (0 = disabled).
]]

local MarketplaceService = game:GetService("MarketplaceService")
local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local DataService = require(script.Parent.DataService)

local MonetizationService = {}

local owned: { [Player]: { [string]: boolean } } = {}
local friendsInServer: { [Player]: { [Player]: boolean } } = {}

-- product handlers: name -> function(player) -> boolean (true = granted)
MonetizationService.Handlers = {}

local productById = {}
for name, id in Config.Products do
	if id ~= 0 then
		productById[id] = name
	end
end
local passById = {}
for name, id in Config.GamePasses do
	if id ~= 0 then
		passById[id] = name
	end
end

function MonetizationService.HasPass(player: Player, name: string): boolean
	local o = owned[player]
	return o ~= nil and o[name] == true
end

function MonetizationService.HasFriendHere(player: Player): boolean
	local f = friendsInServer[player]
	if not f then
		return false
	end
	for other in f do
		if other.Parent then
			return true
		end
	end
	return false
end

function MonetizationService.Multiplier(player: Player): number
	local m = 1
	if MonetizationService.HasPass(player, "VIP") then
		m *= Config.Rewards.VIPMultiplier
	end
	if MonetizationService.HasFriendHere(player) then
		m *= 1 + Config.Rewards.FriendBonus
	end
	return m
end

function MonetizationService.AwardBadge(player: Player, name: string)
	local id = Config.Badges[name]
	if not id or id == 0 then
		return
	end
	task.spawn(function()
		pcall(function()
			if not BadgeService:UserHasBadgeAsync(player.UserId, id) then
				BadgeService:AwardBadge(player.UserId, id)
			end
		end)
	end)
end

local function refreshPasses(player: Player)
	local o = owned[player] or {}
	owned[player] = o
	for name, id in Config.GamePasses do
		if id ~= 0 and not o[name] then
			local ok, has = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id)
			end)
			o[name] = ok and has or false
		end
	end
	player:SetAttribute("VIP", o.VIP == true)
end

local function onPlayerAdded(player: Player)
	owned[player] = {}
	friendsInServer[player] = {}
	task.spawn(refreshPasses, player)
	-- friends bonus (+20% tickets when playing together)
	for _, other in Players:GetPlayers() do
		if other ~= player then
			task.spawn(function()
				local ok, isFriend = pcall(function()
					return player:IsFriendsWith(other.UserId)
				end)
				if ok and isFriend and friendsInServer[player] and friendsInServer[other] then
					friendsInServer[player][other] = true
					friendsInServer[other][player] = true
					Remotes.Notify:FireClient(player, ("👫 Playing with your friend %s: +20%% tickets!"):format(other.DisplayName), "Good")
					Remotes.Notify:FireClient(other, ("👫 Playing with your friend %s: +20%% tickets!"):format(player.DisplayName), "Good")
				end
			end)
		end
	end
end

-- group bonus, called once the profile is loaded
function MonetizationService.CheckGroup(player: Player)
	local data = DataService.Get(player)
	if not data or data.GroupRewardClaimed or Config.GroupId == 0 then
		return
	end
	local ok, inGroup = pcall(function()
		return player:IsInGroup(Config.GroupId)
	end)
	if ok and inGroup then
		data.GroupRewardClaimed = true
		DataService.AddTickets(player, Config.GroupReward, true)
		Remotes.Notify:FireClient(player, ("Thanks for joining the group! +%d 🎟"):format(Config.GroupReward), "Good")
	end
end

local function processReceipt(info)
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = DataService.Get(player)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	-- idempotency: never grant the same receipt twice
	for _, id in data.Receipts do
		if id == info.PurchaseId then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
	end
	local name = productById[info.ProductId]
	if not name then
		warn("[Monetization] unknown product " .. tostring(info.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local granted = false
	if Config.ProductRewards[name] then
		DataService.AddTickets(player, Config.ProductRewards[name], true)
		Remotes.Notify:FireClient(player, ("+%d 🎟 Thanks for your support!"):format(Config.ProductRewards[name]), "Good")
		granted = true
	elseif MonetizationService.Handlers[name] then
		local ok, result = pcall(MonetizationService.Handlers[name], player)
		granted = ok and result ~= false
		if not ok then
			warn("[Monetization] handler error: " .. tostring(result))
		end
	end
	if not granted then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	table.insert(data.Receipts, info.PurchaseId)
	while #data.Receipts > 50 do
		table.remove(data.Receipts, 1)
	end
	task.spawn(DataService.Save, player)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationService.Init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, p in Players:GetPlayers() do
		onPlayerAdded(p)
	end
	Players.PlayerRemoving:Connect(function(player)
		owned[player] = nil
		friendsInServer[player] = nil
		for _, f in friendsInServer do
			f[player] = nil
		end
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if purchased and passById[passId] then
			owned[player] = owned[player] or {}
			owned[player][passById[passId]] = true
			player:SetAttribute("VIP", owned[player].VIP == true)
			Remotes.Notify:FireClient(player, "✨ " .. passById[passId] .. " unlocked! Thank you!", "Good")
			DataService.Push(player)
		end
	end)

	MarketplaceService.ProcessReceipt = processReceipt

	DataService.MultiplierHook = MonetizationService.Multiplier
	DataService.ExtraProfileInfo = function(player)
		local passes = {}
		for name in Config.GamePasses do
			passes[name] = MonetizationService.HasPass(player, name)
		end
		return { Passes = passes }
	end
end

return MonetizationService
