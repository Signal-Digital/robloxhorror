--[[
	Controls — keyboard / touch / gamepad input, sprint & stamina, walk speed,
	local flashlight aiming (smooth) + aim replication to the server.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Items = require(Shared.Items)

local player = Players.LocalPlayer

local Controls = {}

local stamina = Config.StaminaMax
local sprintHeld = false
local sprintToggled = false
local exhausted = false
local lastAim = 0

local function humanoid(): Humanoid?
	local char = player.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

function Controls.ToggleFlashlight()
	if player:GetAttribute("InNight") and not player:GetAttribute("Ghost") then
		Remotes.ToggleFlashlight:FireServer()
	end
end

function Controls.UseItem(item: string)
	Remotes.UseItem:FireServer(item)
end

function Controls.Ping()
	Remotes.GhostPing:FireServer()
end

function Controls.SprintToggle()
	sprintToggled = not sprintToggled
end

local KEY_ITEMS = {}
for _, item in Items.Order do
	KEY_ITEMS[Enum.KeyCode[Items.Defs[item].Key]] = item
end

function Controls.Init(UI)
	UI.Callbacks.Flashlight = Controls.ToggleFlashlight
	UI.Callbacks.UseItem = Controls.UseItem
	UI.Callbacks.Ping = Controls.Ping
	UI.Callbacks.SprintToggle = Controls.SprintToggle

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local key = input.KeyCode
		if key == Enum.KeyCode.F or key == Enum.KeyCode.ButtonR1 then
			Controls.ToggleFlashlight()
		elseif key == Enum.KeyCode.LeftShift or key == Enum.KeyCode.ButtonL3 then
			sprintHeld = true
		elseif key == Enum.KeyCode.Q or key == Enum.KeyCode.ButtonY then
			Controls.Ping()
		elseif KEY_ITEMS[key] then
			Controls.UseItem(KEY_ITEMS[key])
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL3 then
			sprintHeld = false
		end
	end)

	local lastMode = nil
	RunService.RenderStepped:Connect(function(dt)
		local hum = humanoid()
		local ghost = player:GetAttribute("Ghost") == true
		local hidden = player:GetAttribute("Hidden") == true
		local inNight = player:GetAttribute("InNight") == true

		-- ghosts can't interact
		if ProximityPromptService.Enabled == ghost then
			ProximityPromptService.Enabled = not ghost
		end

		-- camera: first person while hiding in a locker
		local mode = hidden and Enum.CameraMode.LockFirstPerson or Enum.CameraMode.Classic
		if mode ~= lastMode then
			player.CameraMode = mode
			if not hidden then
				player.CameraMinZoomDistance = 0.5
			end
			lastMode = mode
		end

		-- sprint / stamina
		local moving = hum and hum.MoveDirection.Magnitude > 0.1
		local wantsSprint = (sprintHeld or sprintToggled) and moving and not ghost
		if stamina <= 0 then
			exhausted = true
		elseif stamina > Config.StaminaMax * 0.3 then
			exhausted = false
		end
		local sprinting = wantsSprint and not exhausted
		if sprinting then
			stamina = math.max(0, stamina - Config.StaminaDrain * dt)
		else
			stamina = math.min(Config.StaminaMax, stamina + Config.StaminaRegen * dt)
		end

		if hum then
			local speed = Config.WalkSpeed
			if ghost then
				speed = Config.GhostSpeed
			elseif sprinting then
				speed = Config.SprintSpeed
			end
			if not ghost and workspace:GetServerTimeNow() < (player:GetAttribute("SpeedBoostUntil") or 0) then
				speed += Config.SodaBonus
			end
			if not inNight and not ghost then
				speed = Config.WalkSpeed + 4 -- lobby: comfy speed
			end
			hum.WalkSpeed = speed
		end

		-- flashlight: smooth local aim + 10 Hz replication
		if player:GetAttribute("FlashlightOn") then
			local cam = workspace.CurrentCamera
			local dir = cam.CFrame.LookVector
			local char = player.Character
			local head = char and char:FindFirstChild("Head") :: BasePart?
			local att = head and head:FindFirstChild("FlashlightAttachment") :: Attachment?
			if head and att then
				local rot = (head.CFrame - head.Position):Inverse() * CFrame.lookAt(Vector3.zero, dir)
				att.CFrame = CFrame.new(0, 0.1, -0.7) * rot
			end
			local now = os.clock()
			if now - lastAim > 0.1 then
				lastAim = now
				Remotes.Aim:FireServer(dir)
			end
		end

		UI.UpdatePlayer(stamina)
	end)
end

return Controls
