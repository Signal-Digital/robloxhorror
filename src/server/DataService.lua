--[[
	DataService — persistent player profiles (DataStore) + leaderstats.
	Works in Studio without API access (falls back to an in-memory profile).
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local DataService = {}

local store, ordered
pcall(function()
	store = DataStoreService:GetDataStore(Config.DataStoreName)
	ordered = DataStoreService:GetOrderedDataStore(Config.LeaderboardStoreName)
end)

local profiles: { [Player]: any } = {}
local loaded: { [Player]: boolean } = {}

-- hooks set by other services
DataService.MultiplierHook = nil :: ((Player) -> number)?
DataService.ExtraProfileInfo = nil :: ((Player) -> { [string]: any })?

local DEFAULT = {
	Tickets = 50,
	Owned = { Light_Default = true },
	Equipped = { Light = "Light_Default" },
	BestNight = 0,
	NightsSurvived = 0,
	Escapes = 0,
	TokensCollected = 0,
	LastDaily = 0,
	DailyStreak = 0,
	GroupRewardClaimed = false,
	Tutorial = false,
	Receipts = {},
}

local function deepCopy(t)
	local c = {}
	for k, v in t do
		c[k] = type(v) == "table" and deepCopy(v) or v
	end
	return c
end

local function reconcile(data, template)
	for k, v in template do
		if data[k] == nil then
			data[k] = type(v) == "table" and deepCopy(v) or v
		end
	end
	return data
end

local function key(player: Player)
	return "u_" .. player.UserId
end

local function setupLeaderstats(player: Player, data)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local t = Instance.new("IntValue")
	t.Name = "🎟 Tickets"
	t.Value = data.Tickets
	t.Parent = ls
	local n = Instance.new("IntValue")
	n.Name = "🌙 Nights"
	n.Value = data.NightsSurvived
	n.Parent = ls
	ls.Parent = player
end

local function updateLeaderstats(player: Player)
	local data = profiles[player]
	local ls = player:FindFirstChild("leaderstats")
	if not data or not ls then
		return
	end
	local t = ls:FindFirstChild("🎟 Tickets") :: IntValue
	local n = ls:FindFirstChild("🌙 Nights") :: IntValue
	if t then
		t.Value = data.Tickets
	end
	if n then
		n.Value = data.NightsSurvived
	end
end

function DataService.DailyAvailable(player: Player): boolean
	local data = profiles[player]
	return data ~= nil and os.time() - data.LastDaily >= Config.Daily.Cooldown
end

function DataService.Push(player: Player)
	local data = profiles[player]
	if not data then
		return
	end
	updateLeaderstats(player)
	local payload = {
		Tickets = data.Tickets,
		Owned = data.Owned,
		Equipped = data.Equipped,
		BestNight = data.BestNight,
		NightsSurvived = data.NightsSurvived,
		DailyAvailable = DataService.DailyAvailable(player),
		DailyStreak = data.DailyStreak,
		Tutorial = data.Tutorial,
		GroupRewardClaimed = data.GroupRewardClaimed,
	}
	if DataService.ExtraProfileInfo then
		for k, v in DataService.ExtraProfileInfo(player) do
			payload[k] = v
		end
	end
	Remotes.ProfileUpdate:FireClient(player, payload)
end

function DataService.Load(player: Player)
	local data
	if store then
		for attempt = 1, 3 do
			local ok, result = pcall(function()
				return store:GetAsync(key(player))
			end)
			if ok then
				data = result
				break
			end
			warn(("[DataService] load attempt %d failed for %s: %s"):format(attempt, player.Name, tostring(result)))
			task.wait(1.5 * attempt)
		end
	end
	if not player.Parent then
		return nil
	end
	data = reconcile(data or {}, DEFAULT)
	profiles[player] = data
	loaded[player] = true
	setupLeaderstats(player, data)
	DataService.Push(player)
	return data
end

function DataService.Get(player: Player)
	return profiles[player]
end

function DataService.IsLoaded(player: Player): boolean
	return loaded[player] == true
end

function DataService.Save(player: Player)
	local data = profiles[player]
	if not data or not store then
		return
	end
	local ok, err = pcall(function()
		store:SetAsync(key(player), data)
	end)
	if not ok then
		warn("[DataService] save failed for " .. player.Name .. ": " .. tostring(err))
	end
	if ordered then
		pcall(function()
			ordered:SetAsync(key(player), data.NightsSurvived)
		end)
	end
end

-- Reward tickets. `raw = true` skips multipliers (purchases, refunds).
function DataService.AddTickets(player: Player, amount: number, raw: boolean?): number
	local data = profiles[player]
	if not data then
		return 0
	end
	if not raw and DataService.MultiplierHook then
		amount = math.floor(amount * DataService.MultiplierHook(player) + 0.5)
	end
	data.Tickets += amount
	DataService.Push(player)
	return amount
end

function DataService.SpendTickets(player: Player, amount: number): boolean
	local data = profiles[player]
	if not data or data.Tickets < amount then
		return false
	end
	data.Tickets -= amount
	DataService.Push(player)
	return true
end

function DataService.Init()
	Players.PlayerRemoving:Connect(function(player)
		DataService.Save(player)
		profiles[player] = nil
		loaded[player] = nil
	end)

	game:BindToClose(function()
		for player in profiles do
			task.spawn(DataService.Save, player)
		end
		task.wait(3)
	end)

	-- autosave
	task.spawn(function()
		while true do
			task.wait(120)
			for player in profiles do
				task.spawn(DataService.Save, player)
			end
		end
	end)
end

-- Global top-10 for the lobby board
local nameCache: { [number]: string } = {}
function DataService.GetTop(n: number)
	if not ordered then
		return {}
	end
	local ok, pages = pcall(function()
		return ordered:GetSortedAsync(false, n)
	end)
	if not ok then
		return {}
	end
	local out = {}
	for _, entry in pages:GetCurrentPage() do
		local userId = tonumber(string.sub(entry.key, 3))
		local name = userId and nameCache[userId] or "???"
		if userId and not nameCache[userId] then
			local okName, result = pcall(function()
				return Players:GetNameFromUserIdAsync(userId)
			end)
			if okName then
				name = result
				nameCache[userId] = result
			end
		end
		table.insert(out, { Name = name, Value = entry.value })
	end
	return out
end

return DataService
