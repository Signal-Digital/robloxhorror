--[[
	RoundService — the game loop:
	  Intermission (parking lot) -> Night (12 AM -> 6 AM, ~5 min) -> Results -> ...
	Survive = next night is harder. Everyone caught = retry the same night.
	Caught guards become ghosts: they can reveal the mascots (Q) and are revived
	every time the team completes an objective (or with the Revive product).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Nights = require(Shared.Nights)
local DataService = require(script.Parent.DataService)
local PlayerService = require(script.Parent.PlayerService)
local QuestService = require(script.Parent.QuestService)
local LootService = require(script.Parent.LootService)
local AnimatronicService = require(script.Parent.AnimatronicService)
local MonetizationService = require(script.Parent.MonetizationService)

local RoundService = {}

local map
local state = {
	Phase = "Intermission",
	Night = 1,
	TimeLeft = Config.IntermissionTime,
	Hour = 0,
	Elapsed = 0,
	Message = "",
}
-- participants[player] = { Status = "Alive" | "Ghost" | "Escaped", Tickets = n, Tokens = n }
local participants: { [Player]: any } = {}

local function inRound(): boolean
	return state.Phase == "Night"
end

local function aliveCount(): (number, number)
	local alive, total = 0, 0
	for player, p in participants do
		if player.Parent then
			total += 1
			if p.Status == "Alive" then
				alive += 1
			end
		end
	end
	return alive, total
end

local function canJoin(): boolean
	return inRound() and state.Elapsed < Config.NightLength * Config.LateJoinWindow
end

function RoundService.Snapshot()
	local alive, total = aliveCount()
	return {
		Phase = state.Phase,
		Night = state.Night,
		NightName = Nights.Name(state.Night),
		TimeLeft = math.max(0, math.ceil(state.TimeLeft)),
		Hour = state.Hour,
		Objectives = QuestService.GetObjectives(),
		MusicBox = inRound() and QuestService.MusicBoxValue() or nil,
		ExitOpen = QuestService.ExitOpen(),
		Alive = alive,
		Total = total,
		CanJoin = canJoin(),
		Message = state.Message,
	}
end

local function broadcast()
	Remotes.GameState:FireAllClients(RoundService.Snapshot())
end

local function notifyNight(text: string, kind: string?)
	for player in participants do
		if player.Parent then
			Remotes.Notify:FireClient(player, text, kind or "Info")
		end
	end
end

local function award(player: Player, amount: number, raw: boolean?)
	local got = DataService.AddTickets(player, amount, raw)
	local p = participants[player]
	if p then
		p.Tickets += got
	end
	return got
end

------------------------------------------------------------------------------
-- Character placement
------------------------------------------------------------------------------
local function placeCharacter(player: Player, char: Model)
	local p = participants[player]
	if not inRound() or not p or p.Status == "Escaped" then
		return
	end
	local hrp = char:WaitForChild("HumanoidRootPart", 5)
	if not hrp then
		return
	end
	task.wait() -- let the default spawn finish
	if p.Status == "Ghost" then
		PlayerService.ApplyGhostLook(char)
		char:PivotTo(map.Spawns.Ghost)
	else
		local spots = map.Spawns.Entrance
		char:PivotTo(spots[math.random(1, #spots)])
	end
end

local function bringIn(player: Player)
	participants[player] = participants[player] or { Status = "Alive", Tickets = 0, Tokens = 0 }
	participants[player].Status = "Alive"
	PlayerService.ResetForNight(player)
	player:SetAttribute("InNight", true)
	player:SetAttribute("Ghost", false)
	task.spawn(function()
		player:LoadCharacter()
	end)
end

function RoundService.Revive(player: Player): boolean
	local p = participants[player]
	if not inRound() or not p or p.Status ~= "Ghost" then
		return false
	end
	p.Status = "Alive"
	player:SetAttribute("Ghost", false)
	player:SetAttribute("Battery", math.max(50, player:GetAttribute("Battery") or 0))
	task.spawn(function()
		player:LoadCharacter()
	end)
	return true
end

local function reviveAll(reason: string)
	local n = 0
	for player, p in participants do
		if p.Status == "Ghost" and player.Parent then
			RoundService.Revive(player)
			n += 1
		end
	end
	if n > 0 then
		notifyNight("💖 " .. reason .. " Fallen guards are back!", "Good")
	end
end

local function makeGhost(player: Player)
	local p = participants[player]
	if not p or p.Status ~= "Alive" then
		return false
	end
	p.Status = "Ghost"
	QuestService.DropCarry(player)
	PlayerService.Unhide(player, true)
	PlayerService.SetFlashlight(player, false)
	player:SetAttribute("Ghost", true)
	broadcast()
	return true
end

-- Animatronic caught someone
local function onCatch(player: Player, mascot: string): boolean
	if not inRound() or not makeGhost(player) then
		return false
	end
	Remotes.Jumpscare:FireClient(player, mascot)
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if hrp then
		hrp.Anchored = true
	end
	for other in participants do
		if other ~= player and other.Parent then
			Remotes.Notify:FireClient(other, ("💀 %s was caught by %s!"):format(player.DisplayName, mascot), "Bad")
		end
	end
	task.delay(2.2, function()
		if player.Parent and participants[player] and participants[player].Status == "Ghost" and inRound() then
			player:LoadCharacter()
			Remotes.Notify:FireClient(player, "👻 You're a ghost! Press Q to reveal the mascots. Teammates revive you by completing tasks.", "Big")
		end
	end)
	return true
end

local function onEscape(player: Player)
	local p = participants[player]
	if not p or p.Status ~= "Alive" then
		return
	end
	p.Status = "Escaped"
	QuestService.DropCarry(player)
	PlayerService.SetFlashlight(player, false)
	player:SetAttribute("InNight", false)
	local got = award(player, Config.Rewards.Escape)
	local data = DataService.Get(player)
	if data then
		data.Escapes += 1
	end
	MonetizationService.AwardBadge(player, "Escape")
	Remotes.Notify:FireClient(player, ("🏃 YOU ESCAPED! +%d 🎟"):format(got), "Big")
	notifyNight(("🚪 %s escaped the pizzeria!"):format(player.DisplayName), "Good")
	broadcast()
end

------------------------------------------------------------------------------
-- Night flow
------------------------------------------------------------------------------
local function startNight()
	local cfg = Nights.Get(state.Night)
	table.clear(participants)
	local players = {}
	for _, player in Players:GetPlayers() do
		if DataService.IsLoaded(player) then
			table.insert(players, player)
		end
	end
	state.Phase = "Night"
	state.Elapsed = 0
	state.Hour = 0
	state.TimeLeft = Config.NightLength
	state.Message = cfg.Intro

	QuestService.Setup(cfg, state.Night, #players)
	LootService.Spawn(#players)
	for _, player in players do
		bringIn(player)
	end

	for _, name in cfg.Animatronics do
		AnimatronicService.Spawn(name, cfg.SpeedMult, nil)
	end

	for _, player in players do
		Remotes.Notify:FireClient(player, Nights.Name(state.Night) .. "|12 AM — " .. cfg.Intro, "Title")
		task.delay(6, function()
			if player.Parent and inRound() then
				Remotes.Notify:FireClient(player, "💡 " .. cfg.Tip, "Info")
			end
		end)
	end
	broadcast()
	return cfg
end

local function endNight(success: boolean)
	state.Phase = "Results"
	state.TimeLeft = Config.ResultsTime
	AnimatronicService.DespawnAll()

	local night = state.Night
	for player, p in participants do
		if player.Parent then
			local survived = p.Status ~= "Ghost"
			local lines = {}
			if survived and success then
				local base = award(player, Config.Rewards.SurviveBase + Config.Rewards.SurvivePerNight * math.min(night, 10))
				table.insert(lines, ("Survived %s: +%d 🎟"):format(Nights.Name(night), base))
				local data = DataService.Get(player)
				if data then
					data.NightsSurvived += 1
					data.BestNight = math.max(data.BestNight, night)
				end
				if night >= 1 then
					MonetizationService.AwardBadge(player, "Night1")
				end
				if night >= 3 then
					MonetizationService.AwardBadge(player, "Night3")
				end
				if night >= 5 then
					MonetizationService.AwardBadge(player, "Night5")
				end
			end
			if MonetizationService.HasPass(player, "VIP") then
				table.insert(lines, "⭐ VIP bonus: x2 tickets")
			end
			if MonetizationService.HasFriendHere(player) then
				table.insert(lines, "👫 Friend bonus: +20% tickets")
			end
			Remotes.Results:FireClient(player, {
				Success = success,
				Survived = survived,
				NightName = Nights.Name(night),
				Escaped = p.Status == "Escaped",
				Tickets = p.Tickets,
				Lines = lines,
			})
			DataService.Push(player)
			task.spawn(DataService.Save, player)
		end
	end

	if success then
		state.Message = Nights.Name(night) .. " complete! Next: " .. Nights.Name(night + 1)
		state.Night += 1
	else
		state.Message = "Everyone got caught... retrying " .. Nights.Name(night)
	end
	broadcast()

	task.wait(Config.ResultsTime)

	QuestService.Cleanup()
	LootService.Cleanup()
	local back = {}
	for player in participants do
		table.insert(back, player)
	end
	table.clear(participants)
	state.Phase = "Intermission"
	for _, player in back do
		if player.Parent then
			PlayerService.ClearNight(player)
			task.spawn(function()
				player:LoadCharacter()
			end)
		end
	end
end

local function runNight()
	startNight()
	local last = os.clock()
	local lastBroadcast = 0
	while true do
		task.wait(0.25)
		local now = os.clock()
		local dt = now - last
		last = now
		state.Elapsed += dt
		state.TimeLeft = Config.NightLength - state.Elapsed
		local hour = math.clamp(math.floor(state.Elapsed / (Config.NightLength / 6)), 0, 6)
		if hour ~= state.Hour then
			state.Hour = hour
			if hour < 6 then
				notifyNight(("🕐 %d AM"):format(hour), "Info")
			end
		end
		QuestService.Tick(dt)

		local alive = aliveCount()
		local anyEscaped = false
		for _, p in participants do
			if p.Status == "Escaped" then
				anyEscaped = true
			end
		end
		if alive == 0 then
			endNight(anyEscaped)
			return
		end
		if state.TimeLeft <= 0 then
			notifyNight("🔔 6 AM! Your shift is over!", "Title")
			endNight(true)
			return
		end
		if now - lastBroadcast >= 1 then
			lastBroadcast = now
			broadcast()
		end
	end
end

local function updateShiftBoard()
	-- the client renders the live countdown; the server keeps a fallback text
	local label = map.ShiftBoard:FindFirstChildOfClass("SurfaceGui")
	label = label and label:FindFirstChild("Label")
	if label then
		if state.Phase == "Intermission" then
			label.Text = ("%s STARTS IN %d"):format(Nights.Name(state.Night), math.max(0, math.ceil(state.TimeLeft)))
		elseif state.Phase == "Night" then
			label.Text = ("%s IN PROGRESS — %d AM"):format(Nights.Name(state.Night), state.Hour == 0 and 12 or state.Hour)
		else
			label.Text = state.Message
		end
	end
end

local function loop()
	while true do
		state.Phase = "Intermission"
		state.TimeLeft = Config.IntermissionTime
		state.Message = ""
		while state.TimeLeft > 0 do
			local ready = 0
			for _, player in Players:GetPlayers() do
				if DataService.IsLoaded(player) then
					ready += 1
				end
			end
			if ready < Config.MinPlayers then
				state.TimeLeft = Config.IntermissionTime
				state.Message = "Waiting for guards..."
			else
				state.Message = ""
			end
			updateShiftBoard()
			broadcast()
			task.wait(1)
			state.TimeLeft -= 1
		end
		local ok, err = pcall(runNight)
		if not ok then
			warn("[RoundService] night crashed: " .. tostring(err))
			AnimatronicService.DespawnAll()
			QuestService.Cleanup()
			LootService.Cleanup()
			for player in participants do
				if player.Parent then
					PlayerService.ClearNight(player)
					player:LoadCharacter()
				end
			end
			table.clear(participants)
		end
	end
end

------------------------------------------------------------------------------
-- Init
------------------------------------------------------------------------------
function RoundService.Init(mapData)
	map = mapData

	AnimatronicService.Init({
		GetTargets = PlayerService.GetTargets,
		IsLit = PlayerService.IsLit,
		OnCatch = onCatch,
	}, map)

	QuestService.Changed = broadcast
	QuestService.OnEscape = onEscape
	QuestService.OnAction = function(player, kind)
		local p = participants[player]
		if kind == "Tokens" then
			if p then
				p.Tokens += 1
			end
			local data = DataService.Get(player)
			if data then
				data.TokensCollected += 1
			end
			local got = award(player, Config.Rewards.Token)
			Remotes.Notify:FireClient(player, ("🪙 Party token! +%d 🎟"):format(got), "Ticket")
		elseif kind == "Fuses" then
			award(player, 5)
			notifyNight(("⚡ %s repaired a fuse box!"):format(player.DisplayName), "Good")
		elseif kind == "Tape" or kind == "Gas" then
			award(player, 10)
			notifyNight(("📦 %s delivered the %s!"):format(player.DisplayName, kind == "Tape" and "tape" or "gas can"), "Good")
		elseif kind == "MusicBox" then
			award(player, 2)
		end
	end
	QuestService.OnObjectiveComplete = function(obj)
		for player, p in participants do
			if player.Parent and p.Status ~= "Escaped" then
				award(player, Config.Rewards.Objective)
			end
		end
		notifyNight(("✅ Task complete: %s (+%d 🎟)"):format(obj.Text, Config.Rewards.Objective), "Good")
		reviveAll("Task complete!")
	end
	QuestService.OnAllComplete = function()
		notifyNight("🚪 ALL TASKS DONE! The front doors are OPEN — escape now or survive until 6 AM!", "Big")
	end
	LootService.OnTickets = function(player, amount)
		local p = participants[player]
		if p then
			p.Tickets += amount
		end
	end

	PlayerService.OnDied = function(player)
		if inRound() and participants[player] and participants[player].Status == "Alive" then
			makeGhost(player)
			notifyNight(("💀 %s is down!"):format(player.DisplayName), "Bad")
		end
	end

	-- character placement during a night
	local function hook(player: Player)
		player.CharacterAdded:Connect(function(char)
			placeCharacter(player, char)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in Players:GetPlayers() do
		hook(p)
	end
	Players.PlayerRemoving:Connect(function(player)
		QuestService.DropCarry(player)
		participants[player] = nil
	end)

	Remotes.JoinShift.OnServerEvent:Connect(function(player)
		if canJoin() and not participants[player] and DataService.IsLoaded(player) then
			bringIn(player)
			Remotes.Notify:FireClient(player, Nights.Name(state.Night) .. "|You clocked in late. Get to work!", "Title")
			broadcast()
		end
	end)

	MonetizationService.Handlers.Revive = function(player)
		if RoundService.Revive(player) then
			notifyNight(("💖 %s used an instant revive!"):format(player.DisplayName), "Good")
			return true
		end
		-- not a ghost anymore: give tickets instead so the purchase is never lost
		DataService.AddTickets(player, 100, true)
		Remotes.Notify:FireClient(player, "You weren't a ghost — here are 100 🎟 instead!", "Good")
		return true
	end
	MonetizationService.Handlers.PowerSurge = function(player)
		for other, p in participants do
			if other.Parent and p.Status == "Alive" then
				other:SetAttribute("Battery", 100)
				PlayerService.GiveItem(other, "Soda")
			end
		end
		for _, other in Players:GetPlayers() do
			Remotes.Notify:FireClient(other, ("⚡ %s bought a POWER SURGE for everyone! Full batteries + soda!"):format(player.DisplayName), "Big")
		end
		if not inRound() then
			DataService.AddTickets(player, 100, true)
		end
		return true
	end

	-- lobby leaderboard
	task.spawn(function()
		while true do
			local top = DataService.GetTop(10)
			local lines = {}
			for i, entry in top do
				table.insert(lines, ("%d. %s — %d"):format(i, entry.Name, entry.Value))
			end
			map.LeaderboardLabel.Text = #lines > 0 and table.concat(lines, "\n") or "Be the first legend!\n(Publish the game to enable leaderboards)"
			task.wait(90)
		end
	end)

	task.spawn(loop)
end

function RoundService.GetState()
	return state
end

return RoundService
