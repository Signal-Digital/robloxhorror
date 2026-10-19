--[[
	PlayerService — everything attached to a guard:
	flashlight (battery, aim, freezing Pip), lockers, consumable items,
	ghost look + ghost ping, cosmetics (beam colour, trail, title).

	State is exposed to clients through Player attributes:
	  InNight, Ghost, Hidden, HideUntil, Battery, FlashlightOn, Carrying,
	  SpeedBoostUntil, Inv_Battery, Inv_Soda, Inv_Decoy
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Items = require(Shared.Items)
local Cosmetics = require(Shared.Cosmetics)
local DataService = require(script.Parent.DataService)
local MonetizationService = require(script.Parent.MonetizationService)
local AnimatronicService = require(script.Parent.AnimatronicService)

local PlayerService = {}

local aims: { [Player]: Vector3 } = {}
local hiding: { [Player]: { Locker: Model } } = {}
local lockerOwner: { [Model]: Player } = {}
local lastPing: { [Player]: number } = {}

local litParams = RaycastParams.new()
litParams.FilterType = Enum.RaycastFilterType.Exclude
litParams.RespectCanCollide = true

-- RoundService hook: called when a guard dies outside of an animatronic catch (reset, fall...)
PlayerService.OnDied = nil :: ((Player) -> ())?

local function root(player: Player): BasePart?
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function PlayerService.IsActive(player: Player): boolean
	if not player:GetAttribute("InNight") or player:GetAttribute("Ghost") then
		return false
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0 and root(player) ~= nil
end

-- Living, visible guards the animatronics can go after
function PlayerService.GetTargets()
	local out = {}
	for _, player in Players:GetPlayers() do
		if PlayerService.IsActive(player) and not player:GetAttribute("Hidden") then
			local r = root(player) :: BasePart
			local v = r.AssemblyLinearVelocity
			table.insert(out, {
				Player = player,
				Char = player.Character,
				Root = r,
				Sprinting = Vector3.new(v.X, 0, v.Z).Magnitude > Config.SprintNoiseSpeed,
			})
		end
	end
	return out
end

-- Is any flashlight beam pointed at one of these points (with line of sight)?
function PlayerService.IsLit(...: Vector3): boolean
	local points = { ... }
	local animFolder = workspace:FindFirstChild("Animatronics")
	for _, player in Players:GetPlayers() do
		local dir = aims[player]
		if dir and player:GetAttribute("FlashlightOn") and PlayerService.IsActive(player) then
			local head = player.Character:FindFirstChild("Head") :: BasePart?
			if head then
				local origin = head.Position
				for _, point in points do
					local v = point - origin
					local d = v.Magnitude
					if d < Config.Flashlight.Range and d > 0.1 and dir:Dot(v.Unit) >= Config.Flashlight.FreezeCone then
						litParams.FilterDescendantsInstances = { player.Character, animFolder }
						if not workspace:Raycast(origin, v, litParams) then
							return true
						end
					end
				end
			end
		end
	end
	return false
end

------------------------------------------------------------------------------
-- Flashlight
------------------------------------------------------------------------------
local function getSpot(player: Player): SpotLight?
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	local att = head and head:FindFirstChild("FlashlightAttachment")
	return att and att:FindFirstChildOfClass("SpotLight")
end

function PlayerService.SetFlashlight(player: Player, on: boolean)
	if on and ((player:GetAttribute("Battery") or 0) <= 0 or not PlayerService.IsActive(player) or player:GetAttribute("Hidden")) then
		on = false
	end
	player:SetAttribute("FlashlightOn", on)
	local spot = getSpot(player)
	if spot then
		spot.Enabled = on
	end
end

local function buildFlashlight(player: Player, char: Model)
	local head = char:WaitForChild("Head", 5) :: BasePart?
	if not head then
		return
	end
	local att = Instance.new("Attachment")
	att.Name = "FlashlightAttachment"
	att.Position = Vector3.new(0, 0.1, -0.7)
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Front
	spot.Range = Config.Flashlight.Range
	spot.Angle = Config.Flashlight.Angle
	spot.Brightness = Config.Flashlight.Brightness
	spot.Shadows = true
	spot.Enabled = false
	spot.Parent = att
	att.Parent = head
	PlayerService.ApplyCosmetics(player)
end

------------------------------------------------------------------------------
-- Cosmetics
------------------------------------------------------------------------------
function PlayerService.ApplyCosmetics(player: Player)
	local char = player.Character
	local data = DataService.Get(player)
	if not char or not data then
		return
	end
	local eq = data.Equipped
	-- beam colour (+ pro flashlight brightness)
	local spot = getSpot(player)
	if spot then
		local light = Cosmetics.ById[eq.Light or "Light_Default"] or Cosmetics.ById.Light_Default
		spot.Color = light.Color
		spot.Brightness = Config.Flashlight.Brightness * (MonetizationService.HasPass(player, "ProFlashlight") and 1.4 or 1)
	end
	-- trail
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if hrp then
		for _, name in { "CosmeticTrail", "TrailA0", "TrailA1" } do
			local old = hrp:FindFirstChild(name)
			if old then
				old:Destroy()
			end
		end
		local trailItem = eq.Trail and Cosmetics.ById[eq.Trail]
		if trailItem and not player:GetAttribute("Ghost") then
			local a0 = Instance.new("Attachment")
			a0.Name = "TrailA0"
			a0.Position = Vector3.new(0, 0.9, 0)
			a0.Parent = hrp
			local a1 = Instance.new("Attachment")
			a1.Name = "TrailA1"
			a1.Position = Vector3.new(0, -0.9, 0)
			a1.Parent = hrp
			local trail = Instance.new("Trail")
			trail.Name = "CosmeticTrail"
			trail.Attachment0 = a0
			trail.Attachment1 = a1
			trail.Color = trailItem.Colors
			trail.Lifetime = 0.6
			trail.LightEmission = 0.6
			trail.Transparency = NumberSequence.new(0.2, 1)
			trail.Parent = hrp
		end
	end
	-- overhead tag: title + VIP star
	local head = char:FindFirstChild("Head")
	if head then
		local old = head:FindFirstChild("NameTag")
		if old then
			old:Destroy()
		end
		local title = eq.Title and Cosmetics.ById[eq.Title]
		local vip = MonetizationService.HasPass(player, "VIP")
		if title or vip then
			local bb = Instance.new("BillboardGui")
			bb.Name = "NameTag"
			bb.Size = UDim2.fromOffset(200, 26)
			bb.StudsOffset = Vector3.new(0, 2.6, 0)
			bb.MaxDistance = 60
			bb.AlwaysOnTop = false
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.TextScaled = true
			label.Font = Enum.Font.FredokaOne
			label.TextStrokeTransparency = 0.3
			label.Text = (vip and "⭐ VIP " or "") .. (title and title.Name or "")
			label.TextColor3 = title and title.Color or Color3.fromRGB(255, 205, 60)
			label.Parent = bb
			bb.Parent = head
		end
	end
end

------------------------------------------------------------------------------
-- Ghosts
------------------------------------------------------------------------------
function PlayerService.ApplyGhostLook(char: Model)
	for _, d in char:GetDescendants() do
		if d:IsA("BasePart") then
			d.CollisionGroup = "Ghosts"
			if d.Name ~= "HumanoidRootPart" then
				d.Transparency = math.max(d.Transparency, 0.55)
				d.Material = Enum.Material.ForceField
				d.Color = Color3.fromRGB(150, 220, 255)
			end
		elseif d:IsA("Decal") then
			d.Transparency = 0.6
		end
	end
	local head = char:FindFirstChild("Head")
	if head then
		local bb = Instance.new("BillboardGui")
		bb.Name = "GhostTag"
		bb.Size = UDim2.fromOffset(60, 40)
		bb.StudsOffset = Vector3.new(0, 2.5, 0)
		bb.MaxDistance = 80
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.TextScaled = true
		label.Text = "👻"
		label.Parent = bb
		bb.Parent = head
	end
end

------------------------------------------------------------------------------
-- Lockers
------------------------------------------------------------------------------
function PlayerService.Unhide(player: Player, silent: boolean?)
	local info = hiding[player]
	if not info then
		return
	end
	hiding[player] = nil
	lockerOwner[info.Locker] = nil
	player:SetAttribute("Hidden", false)
	local r = root(player)
	if r then
		r.Anchored = false
		local outside = info.Locker:GetAttribute("Outside")
		if not silent and typeof(outside) == "CFrame" then
			player.Character:PivotTo(outside)
		end
	end
end

local function hide(player: Player, model: Model)
	local r = root(player)
	local inside = model:GetAttribute("Inside")
	if not r or typeof(inside) ~= "CFrame" then
		return
	end
	hiding[player] = { Locker = model }
	lockerOwner[model] = player
	PlayerService.SetFlashlight(player, false)
	player.Character:PivotTo(inside)
	r.Anchored = true
	player:SetAttribute("Hidden", true)
	player:SetAttribute("HideUntil", workspace:GetServerTimeNow() + Config.HideMaxTime)
end

local function onLocker(player: Player, model: Model)
	local info = hiding[player]
	if info then
		if info.Locker == model then
			PlayerService.Unhide(player)
		end
		return
	end
	if lockerOwner[model] then
		Remotes.Notify:FireClient(player, "Someone is already hiding in there!", "Bad")
		return
	end
	if PlayerService.IsActive(player) then
		hide(player, model)
	end
end

------------------------------------------------------------------------------
-- Items
------------------------------------------------------------------------------
function PlayerService.GiveItem(player: Player, item: string, n: number?): boolean
	local def = Items.Defs[item]
	if not def then
		return false
	end
	local attr = "Inv_" .. item
	local current = player:GetAttribute(attr) or 0
	if current >= def.Max then
		return false
	end
	player:SetAttribute(attr, math.min(def.Max, current + (n or 1)))
	return true
end

local function useItem(player: Player, item: string)
	if typeof(item) ~= "string" or not Items.Defs[item] or not PlayerService.IsActive(player) then
		return
	end
	local attr = "Inv_" .. item
	local count = player:GetAttribute(attr) or 0
	if count <= 0 then
		return
	end
	local r = root(player) :: BasePart
	if item == "Battery" then
		if (player:GetAttribute("Battery") or 0) >= 99 then
			Remotes.Notify:FireClient(player, "Your flashlight is already full!", "Info")
			return
		end
		player:SetAttribute("Battery", 100)
		Remotes.Notify:FireClient(player, "🔋 Flashlight recharged!", "Good")
	elseif item == "Soda" then
		player:SetAttribute("SpeedBoostUntil", workspace:GetServerTimeNow() + Config.SodaDuration)
		Remotes.Notify:FireClient(player, "🥤 Sugar rush! Run!", "Good")
	elseif item == "Decoy" then
		if player:GetAttribute("Hidden") then
			return
		end
		AnimatronicService.AddDecoy(r.Position + r.CFrame.LookVector * 3, Config.DecoyDuration)
		Remotes.Notify:FireClient(player, "🧸 Squeak! The mascots are distracted...", "Good")
	end
	player:SetAttribute(attr, count - 1)
end

------------------------------------------------------------------------------
-- Night lifecycle helpers (used by RoundService)
------------------------------------------------------------------------------
function PlayerService.ResetForNight(player: Player)
	player:SetAttribute("Battery", 100)
	player:SetAttribute("FlashlightOn", false)
	player:SetAttribute("Carrying", "")
	player:SetAttribute("SpeedBoostUntil", 0)
	player:SetAttribute("Hidden", false)
	for _, item in Items.Order do
		player:SetAttribute("Inv_" .. item, item == "Battery" and 1 or 0)
	end
end

function PlayerService.ClearNight(player: Player)
	PlayerService.Unhide(player, true)
	PlayerService.SetFlashlight(player, false)
	player:SetAttribute("InNight", false)
	player:SetAttribute("Ghost", false)
	player:SetAttribute("Carrying", "")
	for _, item in Items.Order do
		player:SetAttribute("Inv_" .. item, 0)
	end
end

------------------------------------------------------------------------------
-- Init
------------------------------------------------------------------------------
local function setCollisionGroup(player: Player, char: Model)
	local function apply(d)
		if d:IsA("BasePart") then
			d.CollisionGroup = player:GetAttribute("Ghost") and "Ghosts" or "Players"
		end
	end
	for _, d in char:GetDescendants() do
		apply(d)
	end
	char.DescendantAdded:Connect(apply)
end

local function onCharacter(player: Player, char: Model)
	setCollisionGroup(player, char)
	task.spawn(buildFlashlight, player, char)
	local hum = char:WaitForChild("Humanoid", 5) :: Humanoid?
	if hum then
		hum.Died:Connect(function()
			PlayerService.Unhide(player, true)
			PlayerService.SetFlashlight(player, false)
			if PlayerService.OnDied then
				PlayerService.OnDied(player)
			end
		end)
	end
end

function PlayerService.Init(map)
	local function onPlayer(player: Player)
		player:SetAttribute("InNight", false)
		player:SetAttribute("Ghost", false)
		PlayerService.ResetForNight(player)
		player.CharacterAdded:Connect(function(char)
			onCharacter(player, char)
		end)
		if player.Character then
			onCharacter(player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		task.spawn(onPlayer, p)
	end
	Players.PlayerRemoving:Connect(function(player)
		PlayerService.Unhide(player, true)
		aims[player] = nil
		lastPing[player] = nil
	end)

	for _, entry in map.Lockers do
		entry.Prompt.Triggered:Connect(function(player)
			onLocker(player, entry.Model)
		end)
	end

	Remotes.ToggleFlashlight.OnServerEvent:Connect(function(player)
		PlayerService.SetFlashlight(player, not player:GetAttribute("FlashlightOn"))
	end)

	Remotes.Aim.OnServerEvent:Connect(function(player, dir)
		if typeof(dir) ~= "Vector3" or dir.Magnitude < 0.5 or dir.Magnitude > 1.5 then
			return
		end
		dir = dir.Unit
		aims[player] = dir
		local char = player.Character
		local head = char and char:FindFirstChild("Head") :: BasePart?
		local att = head and head:FindFirstChild("FlashlightAttachment") :: Attachment?
		if head and att then
			local rot = (head.CFrame - head.Position):Inverse() * CFrame.lookAt(Vector3.zero, dir)
			att.CFrame = CFrame.new(0, 0.1, -0.7) * rot
		end
	end)

	Remotes.UseItem.OnServerEvent:Connect(useItem)

	Remotes.GhostPing.OnServerEvent:Connect(function(player)
		if not player:GetAttribute("Ghost") or not player:GetAttribute("InNight") then
			return
		end
		local now = os.clock()
		if lastPing[player] and now - lastPing[player] < Config.GhostPingCooldown then
			return
		end
		lastPing[player] = now
		AnimatronicService.Reveal(Config.GhostPingDuration)
		for _, p in Players:GetPlayers() do
			if p:GetAttribute("InNight") then
				Remotes.Notify:FireClient(p, ("👻 %s revealed the animatronics!"):format(player.DisplayName), "Info")
			end
		end
	end)

	-- battery drain + locker breath timer
	task.spawn(function()
		while true do
			task.wait(0.25)
			for _, player in Players:GetPlayers() do
				if player:GetAttribute("FlashlightOn") then
					local drain = MonetizationService.HasPass(player, "ProFlashlight") and Config.Flashlight.ProDrain or Config.Flashlight.Drain
					local b = math.max(0, (player:GetAttribute("Battery") or 0) - drain * 0.25)
					player:SetAttribute("Battery", b)
					if b <= 0 then
						PlayerService.SetFlashlight(player, false)
						Remotes.Notify:FireClient(player, "🔦 Battery dead! Find a battery.", "Bad")
					end
				end
				if hiding[player] and workspace:GetServerTimeNow() > (player:GetAttribute("HideUntil") or 0) then
					PlayerService.Unhide(player)
					Remotes.Notify:FireClient(player, "😮‍💨 You ran out of breath!", "Bad")
				end
			end
		end
	end)
end

return PlayerService
