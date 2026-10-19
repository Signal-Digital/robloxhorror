-- Night Shift at Pip's — client entry point.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local UI = require(script.Parent.UI)
local Controls = require(script.Parent.Controls)
local Effects = require(script.Parent.Effects)
local Jumpscare = require(script.Parent.Jumpscare)
local Markers = require(script.Parent.Markers)

UI.Init()
Controls.Init(UI)
Jumpscare.Init(Effects)
Markers.Init()
task.spawn(Effects.Init, UI)

-- initial sync
task.spawn(function()
	local ok, state = pcall(function()
		return Remotes.GetProfile:InvokeServer()
	end)
	if ok and state then
		UI.SetState(state)
	end
end)
