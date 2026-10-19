--[[
	Markers — floating objective markers (icon + distance) so players always
	know where to go next. Tokens only show the 3 closest to avoid clutter.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local Markers = {}

local ICONS = {
	["Fuse Box"] = "⚡",
	Token = "🪙",
	Tape = "📼",
	["Gas Can"] = "⛽",
	VCR = "📺",
	Generator = "🔧",
	["Music Box"] = "🎵",
	EXIT = "🚪",
}
local COLORS = {
	["Fuse Box"] = Color3.fromRGB(255, 220, 60),
	Token = Color3.fromRGB(255, 200, 40),
	EXIT = Color3.fromRGB(80, 255, 120),
	["Music Box"] = Color3.fromRGB(255, 120, 200),
}

local boards: { [Instance]: BillboardGui } = {}

local function getBoard(inst: BasePart)
	local bb = boards[inst]
	if bb and bb.Parent then
		return bb
	end
	bb = Instance.new("BillboardGui")
	bb.Name = "ObjectiveMarker"
	bb.AlwaysOnTop = true
	bb.Size = UDim2.fromOffset(150, 46)
	bb.StudsOffset = Vector3.new(0, 3, 0)
	bb.LightInfluence = 0
	bb.Adornee = inst
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextStrokeTransparency = 0.2
	label.Parent = bb
	bb.Parent = player:WaitForChild("PlayerGui")
	boards[inst] = bb
	return bb
end

function Markers.Init()
	local accum = 0
	RunService.Heartbeat:Connect(function(dt)
		accum += dt
		if accum < 0.2 then
			return
		end
		accum = 0
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local show = player:GetAttribute("InNight") == true and hrp ~= nil
		local carrying = player:GetAttribute("Carrying") or ""

		local visible = {}
		local tokens = {}
		if show then
			for _, inst in CollectionService:GetTagged("ObjectiveTarget") do
				if inst:IsA("BasePart") and inst.Parent and inst:GetAttribute("Active") then
					local forCarry = inst:GetAttribute("ForCarry") or ""
					local labelText = inst:GetAttribute("Label")
					local ok = forCarry == "" or forCarry == carrying
					-- hide pickups of the kind you're already carrying
					if carrying ~= "" and (labelText == "Tape" or labelText == "Gas Can") then
						ok = false
					end
					if ok then
						local d = (inst.Position - hrp.Position).Magnitude
						if labelText == "Token" then
							table.insert(tokens, { inst, d })
						else
							table.insert(visible, { inst, d })
						end
					end
				end
			end
			table.sort(tokens, function(a, b)
				return a[2] < b[2]
			end)
			for i = 1, math.min(3, #tokens) do
				table.insert(visible, tokens[i])
			end
		end

		local seen = {}
		for _, entry in visible do
			local inst, d = entry[1], entry[2]
			seen[inst] = true
			local bb = getBoard(inst)
			local name = inst:GetAttribute("Label")
			bb.Enabled = true
			bb.Label.Text = ("%s %s\n%dm"):format(ICONS[name] or "❗", name, math.floor(d / 3.5))
			bb.Label.TextColor3 = COLORS[name] or Color3.fromRGB(120, 220, 255)
		end
		for inst, bb in boards do
			if not seen[inst] then
				if not inst.Parent then
					bb:Destroy()
					boards[inst] = nil
				else
					bb.Enabled = false
				end
			end
		end
	end)
end

return Markers
