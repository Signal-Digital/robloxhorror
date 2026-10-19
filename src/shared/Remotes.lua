-- Creates (server) or waits for (client) every remote used by the game.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EVENTS = {
	-- server -> client
	"GameState",
	"Notify",
	"Jumpscare",
	"Reward",
	"Results",
	"ProfileUpdate",
	"OpenUI",
	-- client -> server
	"ToggleFlashlight",
	"UseItem",
	"GhostPing",
	"Equip",
	"ClaimDaily",
	"JoinShift",
	"TutorialDone",
}
local UNRELIABLE = { "Aim" }
local FUNCTIONS = { "RollCapsule", "GetProfile" }

local Remotes = {}
local folder

if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		for _, name in EVENTS do
			local r = Instance.new("RemoteEvent")
			r.Name = name
			r.Parent = folder
		end
		for _, name in UNRELIABLE do
			local r = Instance.new("UnreliableRemoteEvent")
			r.Name = name
			r.Parent = folder
		end
		for _, name in FUNCTIONS do
			local r = Instance.new("RemoteFunction")
			r.Name = name
			r.Parent = folder
		end
		folder.Parent = ReplicatedStorage
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

for _, list in { EVENTS, UNRELIABLE, FUNCTIONS } do
	for _, name in list do
		Remotes[name] = folder:WaitForChild(name)
	end
end

return Remotes
