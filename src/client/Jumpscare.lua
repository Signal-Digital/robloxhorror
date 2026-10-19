--[[
	Jumpscare — full-screen close-up of the mascot that caught you, rendered with a
	ViewportFrame using the server's template model (no image assets needed).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local player = Players.LocalPlayer

local Jumpscare = {}

function Jumpscare.Play(name: string, effects)
	local templates = ReplicatedStorage:FindFirstChild("AnimatronicTemplates")
	local template = templates and templates:FindFirstChild(name)
	if not template then
		return
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "Jumpscare"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 100
	gui.ResetOnSpawn = false

	local vp = Instance.new("ViewportFrame")
	vp.Size = UDim2.fromScale(1, 1)
	vp.BackgroundColor3 = Color3.new(0, 0, 0)
	vp.Ambient = Color3.fromRGB(150, 140, 140)
	vp.LightColor = Color3.fromRGB(255, 210, 200)
	vp.LightDirection = Vector3.new(0.3, -0.6, 1)
	vp.Parent = gui

	local model = template:Clone()
	model.Parent = vp
	local cam = Instance.new("Camera")
	cam.FieldOfView = 60
	cam.Parent = vp
	vp.CurrentCamera = cam

	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
	flash.BackgroundTransparency = 0.4
	flash.ZIndex = 5
	flash.Parent = gui

	gui.Parent = player:WaitForChild("PlayerGui")
	if effects then
		effects.Play("Jumpscare", 1)
	end

	local head = model:FindFirstChild("Head") :: BasePart
	local jaw = model:FindFirstChild("Jaw") :: BasePart?
	local jawBase = jaw and jaw.CFrame
	local center = head.Position + Vector3.new(0, -0.6, 0)
	local forward = head.CFrame.LookVector
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		local approach = math.clamp(t / 0.35, 0, 1)
		local dist = 16 - 12.2 * (approach ^ 0.5)
		local shake = (1 - math.clamp((t - 1) / 0.6, 0, 1)) * 0.35
		local offset = Vector3.new((math.random() - 0.5) * shake, (math.random() - 0.5) * shake, 0)
		cam.CFrame = CFrame.lookAt(center + forward * dist + offset, center) * CFrame.Angles(0, 0, (math.random() - 0.5) * shake * 0.3)
		if jaw and jawBase then
			jaw.CFrame = jawBase * CFrame.new(0, -0.9 * math.clamp(t * 4, 0, 1), 0.2)
		end
		flash.BackgroundTransparency = 0.4 + 0.6 * math.clamp(t * 3, 0, 1) + (math.random() < 0.2 and -0.3 or 0)
		if t > 1.7 then
			conn:Disconnect()
			gui:Destroy()
		end
	end)
end

function Jumpscare.Init(effects)
	Remotes.Jumpscare.OnClientEvent:Connect(function(name)
		Jumpscare.Play(name, effects)
	end)
end

return Jumpscare
