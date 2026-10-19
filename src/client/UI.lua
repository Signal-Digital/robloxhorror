--[[
	UI — every screen element, built from code.
	HUD: night/clock, task list, battery/stamina, inventory, action buttons, toasts.
	Panels: Guard Shop (Robux), Prize Counter (tickets gacha), Wardrobe, Mascot guide,
	tutorial, daily reward, results.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Items = require(Shared.Items)
local Cosmetics = require(Shared.Cosmetics)
local Mascots = require(Shared.Mascots)

local player = Players.LocalPlayer

local UI = {}
UI.Callbacks = {
	Flashlight = function() end,
	SprintToggle = function() end,
	UseItem = function(_item: string) end,
	Ping = function() end,
}
UI.Profile = nil
UI.State = nil
UI.IsTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local C = Color3.fromRGB
local THEME = {
	Panel = C(22, 18, 32),
	Panel2 = C(36, 30, 52),
	Accent = C(255, 80, 170),
	Accent2 = C(0, 220, 255),
	Gold = C(255, 205, 60),
	Good = C(90, 230, 120),
	Bad = C(255, 70, 70),
	Text = C(245, 240, 255),
	Muted = C(170, 160, 190),
}
local TITLE_FONT = Enum.Font.FredokaOne
local BODY_FONT = Enum.Font.GothamMedium

------------------------------------------------------------------------------
-- tiny UI toolkit
------------------------------------------------------------------------------
local function new(class: string, props: { [string]: any }, children: { Instance }?)
	local inst = Instance.new(class)
	for k, v in props do
		if k ~= "Parent" then
			(inst :: any)[k] = v
		end
	end
	if children then
		for _, c in children do
			c.Parent = inst
		end
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function corner(r: number?)
	return new("UICorner", { CornerRadius = UDim.new(0, r or 12) })
end

local function stroke(color: Color3?, thickness: number?)
	return new("UIStroke", { Color = color or C(255, 255, 255), Thickness = thickness or 2, Transparency = 0.6, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local function label(props)
	local defaults = {
		BackgroundTransparency = 1,
		TextColor3 = THEME.Text,
		Font = BODY_FONT,
		TextScaled = true,
		Text = "",
	}
	for k, v in props do
		defaults[k] = v
	end
	return new("TextLabel", defaults)
end

local function button(props, onClick: () -> ())
	local defaults = {
		BackgroundColor3 = THEME.Accent,
		TextColor3 = THEME.Text,
		Font = TITLE_FONT,
		TextScaled = true,
		AutoButtonColor = true,
		Text = "",
	}
	for k, v in props do
		defaults[k] = v
	end
	local b = new("TextButton", defaults, { corner(10), new("UIPadding", {
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 4),
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
	}) })
	b.MouseButton1Click:Connect(onClick)
	return b
end

local function bar(parent, pos: UDim2, size: UDim2, color: Color3, name: string)
	local frame = new("Frame", {
		Name = name,
		Parent = parent,
		Position = pos,
		Size = size,
		BackgroundColor3 = C(15, 12, 22),
		BackgroundTransparency = 0.2,
	}, { corner(8), stroke(C(255, 255, 255), 1.5) })
	local fill = new("Frame", { Name = "Fill", Parent = frame, Size = UDim2.fromScale(1, 1), BackgroundColor3 = color }, { corner(8) })
	return frame, fill
end

local function tween(obj, time, props)
	local t = TweenService:Create(obj, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

local function formatNumber(n: number): string
	local s = tostring(math.floor(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if formatted:sub(1, 1) == "," then
		formatted = formatted:sub(2)
	end
	return formatted
end

------------------------------------------------------------------------------
-- Build
------------------------------------------------------------------------------
local gui: ScreenGui
local root: Frame
local scaleObj: UIScale
local hud = {}
local panels = {}
local toastHolder: Frame

local function updateScale()
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local vp = cam.ViewportSize
	local s = math.clamp(math.min(vp.X / 1280, vp.Y / 760), 0.55, 1.25)
	scaleObj.Scale = s
	root.Size = UDim2.fromScale(1 / s, 1 / s)
end

local function makePanel(name: string, title: string, size: Vector2)
	local panel = new("Frame", {
		Name = name,
		Parent = root,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundColor3 = THEME.Panel,
		Visible = false,
		ZIndex = 20,
	}, { corner(18), stroke(THEME.Accent, 3) })
	label({
		Parent = panel,
		Position = UDim2.fromOffset(20, 10),
		Size = UDim2.new(1, -90, 0, 44),
		Text = title,
		Font = TITLE_FONT,
		TextColor3 = THEME.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 21,
	})
	button({
		Parent = panel,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.fromOffset(44, 44),
		Text = "X",
		BackgroundColor3 = THEME.Bad,
		ZIndex = 22,
	}, function()
		panel.Visible = false
	end)
	local body = new("Frame", {
		Name = "Body",
		Parent = panel,
		Position = UDim2.fromOffset(16, 64),
		Size = UDim2.new(1, -32, 1, -80),
		BackgroundTransparency = 1,
		ZIndex = 21,
	})
	panels[name] = panel
	return panel, body
end

function UI.Open(name: string)
	for n, p in panels do
		p.Visible = (n == name)
	end
	if UI.OnOpen then
		UI.OnOpen(name)
	end
end

function UI.CloseAll()
	for _, p in panels do
		p.Visible = false
	end
end

------------------------------------------------------------------------------
-- HUD
------------------------------------------------------------------------------
local function buildHud()
	-- Top bar
	local top = new("Frame", {
		Name = "TopBar",
		Parent = root,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(380, 92),
		BackgroundColor3 = THEME.Panel,
		BackgroundTransparency = 0.15,
	}, { corner(16), stroke(THEME.Accent, 2) })
	hud.Night = label({ Parent = top, Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 26), Font = TITLE_FONT, TextColor3 = THEME.Accent, Text = "NIGHT 1" })
	hud.Clock = label({ Parent = top, Position = UDim2.fromOffset(10, 28), Size = UDim2.new(1, -20, 0, 36), Font = TITLE_FONT, Text = "12 AM" })
	hud.Sub = label({ Parent = top, Position = UDim2.fromOffset(10, 64), Size = UDim2.new(1, -20, 0, 22), TextColor3 = THEME.Muted, Text = "" })

	-- Ticket counter (top right)
	local tickets = new("Frame", {
		Parent = root,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 60),
		Size = UDim2.fromOffset(190, 50),
		BackgroundColor3 = THEME.Panel,
		BackgroundTransparency = 0.15,
	}, { corner(14), stroke(THEME.Gold, 2) })
	hud.Tickets = label({ Parent = tickets, Position = UDim2.fromOffset(8, 6), Size = UDim2.new(1, -16, 1, -12), Font = TITLE_FONT, TextColor3 = THEME.Gold, Text = "🎟 0" })

	-- Task list (left)
	local quests = new("Frame", {
		Name = "Quests",
		Parent = root,
		Position = UDim2.fromOffset(12, 120),
		Size = UDim2.fromOffset(330, 60),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = THEME.Panel,
		BackgroundTransparency = 0.2,
		Visible = false,
	}, {
		corner(14),
		stroke(THEME.Accent2, 2),
		new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
		new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 10) }),
	})
	label({ Parent = quests, LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 26), Font = TITLE_FONT, TextColor3 = THEME.Accent2, Text = "📋 TONIGHT'S TASKS", TextXAlignment = Enum.TextXAlignment.Left })
	hud.Quests = quests
	hud.QuestRows = {}

	-- Music box meter
	local mb, mbFill = bar(root, UDim2.fromOffset(12, 0), UDim2.fromOffset(330, 26), THEME.Accent, "MusicBox")
	mb.Visible = false
	hud.MusicBox, hud.MusicBoxFill = mb, mbFill
	hud.MusicBoxLabel = label({ Parent = mb, Size = UDim2.fromScale(1, 1), Font = TITLE_FONT, Text = "🎵 MUSIC BOX", ZIndex = 3 })

	-- Battery + stamina (bottom center)
	local bottom = new("Frame", {
		Name = "Bottom",
		Parent = root,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.fromOffset(300, 140),
		BackgroundTransparency = 1,
	})
	hud.Bottom = bottom
	local bat, batFill = bar(bottom, UDim2.new(0, 0, 1, -40), UDim2.new(1, 0, 0, 24), THEME.Good, "Battery")
	hud.BatteryFill = batFill
	hud.BatteryLabel = label({ Parent = bat, Size = UDim2.fromScale(1, 1), Font = TITLE_FONT, Text = "🔦 100%", ZIndex = 3 })
	local _, stamFill = bar(bottom, UDim2.new(0.1, 0, 1, -12), UDim2.new(0.8, 0, 0, 10), THEME.Accent2, "Stamina")
	hud.StaminaFill = stamFill
	-- inventory slots
	hud.Slots = {}
	for i, item in Items.Order do
		local def = Items.Defs[item]
		local slot = button({
			Parent = bottom,
			Position = UDim2.new(0, (i - 1) * 104 + 8, 0, 4),
			Size = UDim2.fromOffset(84, 84),
			BackgroundColor3 = THEME.Panel,
			BackgroundTransparency = 0.15,
			Text = "",
		}, function()
			UI.Callbacks.UseItem(item)
		end)
		stroke(THEME.Muted, 2).Parent = slot
		label({ Parent = slot, Size = UDim2.new(1, 0, 0.62, 0), Text = def.Icon })
		local count = label({ Parent = slot, Position = UDim2.fromScale(0, 0.6), Size = UDim2.fromScale(1, 0.4), Font = TITLE_FONT, Text = "x0" })
		label({ Parent = slot, Position = UDim2.fromOffset(4, 2), Size = UDim2.fromOffset(18, 18), Font = TITLE_FONT, TextColor3 = THEME.Gold, Text = tostring(i), Visible = not UI.IsTouch })
		hud.Slots[item] = { Button = slot, Count = count }
	end

	-- Action buttons (bottom right)
	local actions = new("Frame", {
		Parent = root,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.fromOffset(200, 200),
		BackgroundTransparency = 1,
	})
	hud.Actions = actions
	local function roundBtn(pos: UDim2, text: string, hint: string, color: Color3, cb)
		local b = button({ Parent = actions, Position = pos, Size = UDim2.fromOffset(92, 92), BackgroundColor3 = color, Text = text, BackgroundTransparency = 0.1 }, cb)
		b:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(1, 0)
		if hint ~= "" and not UI.IsTouch then
			label({ Parent = b, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, -4), Size = UDim2.fromOffset(60, 20), Font = TITLE_FONT, Text = hint })
		end
		return b
	end
	hud.FlashBtn = roundBtn(UDim2.fromOffset(104, 104), "🔦", "[F]", C(255, 200, 60), function()
		UI.Callbacks.Flashlight()
	end)
	hud.SprintBtn = roundBtn(UDim2.fromOffset(0, 104), "🏃", "", THEME.Accent2, function()
		UI.Callbacks.SprintToggle()
	end)
	hud.SprintBtn.Visible = UI.IsTouch
	hud.PingBtn = roundBtn(UDim2.fromOffset(104, 0), "👻", "[Q]", C(150, 200, 255), function()
		UI.Callbacks.Ping()
	end)
	hud.PingBtn.Visible = false

	-- impulse purchase right when you get caught
	hud.ReviveBtn = button({
		Parent = root,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 148),
		Size = UDim2.fromOffset(260, 50),
		BackgroundColor3 = C(255, 90, 130),
		Text = "💖 REVIVE NOW",
		Visible = false,
	}, function()
		if Config.Products.Revive ~= 0 then
			MarketplaceService:PromptProductPurchase(player, Config.Products.Revive)
		end
	end)

	-- Lobby menu (left)
	local menu = new("Frame", {
		Name = "Menu",
		Parent = root,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 20),
		Size = UDim2.fromOffset(150, 380),
		BackgroundTransparency = 1,
	}, { new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
	hud.Menu = menu
	local entries = {
		{ "🛒 Shop", THEME.Good, function() UI.Open("Shop") end },
		{ "🎁 Prizes", THEME.Accent, function() UI.Open("Prizes") end },
		{ "👕 Wardrobe", THEME.Accent2, function() UI.Open("Wardrobe") end },
		{ "📖 Mascots", C(255, 170, 60), function() UI.Open("Guide") end },
		{ "✉️ Invite", C(140, 120, 255), function()
			pcall(function()
				SocialService:PromptGameInvite(player)
			end)
		end },
	}
	for i, e in entries do
		button({ Parent = menu, LayoutOrder = i, Size = UDim2.fromOffset(150, 54), BackgroundColor3 = e[2], Text = e[1] }, e[3])
	end
	hud.DailyBtn = button({ Parent = menu, LayoutOrder = 10, Size = UDim2.fromOffset(150, 54), BackgroundColor3 = THEME.Gold, TextColor3 = C(40, 20, 0), Text = "🎁 DAILY!", Visible = false }, function()
		Remotes.ClaimDaily:FireServer()
		hud.DailyBtn.Visible = false
	end)

	-- Join shift button
	hud.JoinBtn = button({
		Parent = root,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -170),
		Size = UDim2.fromOffset(300, 64),
		BackgroundColor3 = THEME.Good,
		Text = "🕛 CLOCK IN NOW!",
		Visible = false,
	}, function()
		Remotes.JoinShift:FireServer()
	end)

	-- Status banner (ghost / hidden / chased)
	hud.Banner = label({
		Parent = root,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 108),
		Size = UDim2.fromOffset(620, 34),
		Font = TITLE_FONT,
		TextStrokeTransparency = 0.2,
		Text = "",
		Visible = false,
	})

	-- Big title
	hud.Title = label({ Parent = root, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.36), Size = UDim2.fromOffset(800, 90), Font = TITLE_FONT, TextColor3 = THEME.Accent, TextStrokeTransparency = 0, TextTransparency = 1, TextStrokeColor3 = C(40, 0, 30) })
	hud.Subtitle = label({ Parent = root, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.44), Size = UDim2.fromOffset(800, 40), Font = TITLE_FONT, TextStrokeTransparency = 0.2, TextTransparency = 1 })

	-- Toasts
	toastHolder = new("Frame", {
		Parent = root,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 124),
		Size = UDim2.fromOffset(360, 400),
		BackgroundTransparency = 1,
	}, { new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Right }) })
end

------------------------------------------------------------------------------
-- Notifications
------------------------------------------------------------------------------
local toastOrder = 0
function UI.Toast(text: string, color: Color3?)
	toastOrder += 1
	local t = new("TextLabel", {
		Parent = toastHolder,
		LayoutOrder = toastOrder,
		Size = UDim2.fromOffset(360, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = THEME.Panel,
		BackgroundTransparency = 0.15,
		TextColor3 = color or THEME.Text,
		Font = BODY_FONT,
		TextSize = 18,
		TextWrapped = true,
		Text = text,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, { corner(10), new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }) })
	local kids = {}
	for _, k in toastHolder:GetChildren() do
		if k:IsA("TextLabel") then
			table.insert(kids, k)
		end
	end
	if #kids > 5 then
		table.sort(kids, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		kids[1]:Destroy()
	end
	task.delay(4.5, function()
		if t.Parent then
			tween(t, 0.5, { TextTransparency = 1, BackgroundTransparency = 1 })
			task.wait(0.5)
			t:Destroy()
		end
	end)
end

local titleToken = 0
function UI.BigTitle(title: string, subtitle: string?, color: Color3?)
	titleToken += 1
	local my = titleToken
	hud.Title.Text = title
	hud.Title.TextColor3 = color or THEME.Accent
	hud.Subtitle.Text = subtitle or ""
	hud.Title.TextTransparency = 1
	hud.Subtitle.TextTransparency = 1
	tween(hud.Title, 0.4, { TextTransparency = 0 })
	tween(hud.Subtitle, 0.6, { TextTransparency = 0 })
	task.delay(4.5, function()
		if my == titleToken then
			tween(hud.Title, 0.8, { TextTransparency = 1 })
			tween(hud.Subtitle, 0.8, { TextTransparency = 1 })
		end
	end)
end

function UI.Notify(text: string, kind: string?)
	if kind == "Title" then
		local a, b = string.match(text, "^(.-)|(.*)$")
		UI.BigTitle(a or text, b)
	elseif kind == "Big" then
		UI.BigTitle(text, nil, THEME.Gold)
		UI.Toast(text, THEME.Gold)
	elseif kind == "Good" then
		UI.Toast(text, THEME.Good)
	elseif kind == "Bad" then
		UI.Toast(text, THEME.Bad)
	elseif kind == "Ticket" then
		UI.Toast(text, THEME.Gold)
	else
		UI.Toast(text)
	end
end

------------------------------------------------------------------------------
-- Reward card / results
------------------------------------------------------------------------------
local rewardCard: Frame
local function buildRewardCard()
	rewardCard = new("Frame", {
		Parent = root,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(380, 220),
		BackgroundColor3 = THEME.Panel,
		Visible = false,
		ZIndex = 40,
	}, { corner(20), stroke(THEME.Gold, 4) })
	label({ Name = "Rarity", Parent = rewardCard, Position = UDim2.fromOffset(10, 12), Size = UDim2.new(1, -20, 0, 34), Font = TITLE_FONT, ZIndex = 41 })
	label({ Name = "Title", Parent = rewardCard, Position = UDim2.fromOffset(10, 56), Size = UDim2.new(1, -20, 0, 70), Font = TITLE_FONT, ZIndex = 41 })
	label({ Name = "Text", Parent = rewardCard, Position = UDim2.fromOffset(16, 134), Size = UDim2.new(1, -32, 0, 60), TextColor3 = THEME.Muted, ZIndex = 41, TextWrapped = true })
end

local rewardToken = 0
function UI.ShowReward(reward)
	rewardToken += 1
	local my = rewardToken
	local rarity = Cosmetics.Rarities[reward.Rarity] or Cosmetics.Rarities.Common
	rewardCard.UIStroke.Color = rarity.Color
	rewardCard.Rarity.Text = string.upper(reward.Rarity or "Common")
	rewardCard.Rarity.TextColor3 = rarity.Color
	rewardCard.Title.Text = reward.Title or ""
	rewardCard.Text.Text = reward.Text or ""
	rewardCard.Size = UDim2.fromOffset(40, 20)
	rewardCard.Visible = true
	tween(rewardCard, 0.35, { Size = UDim2.fromOffset(380, 220) })
	task.delay(3.5, function()
		if my == rewardToken then
			rewardCard.Visible = false
		end
	end)
end

function UI.ShowResults(res)
	local panel = panels.Results
	local body = panel.Body
	body.Head.Text = res.Survived and (res.Escaped and "🏃 YOU ESCAPED!" or "☀️ SHIFT COMPLETE!") or "💀 YOU GOT CAUGHT"
	body.Head.TextColor3 = res.Survived and THEME.Good or THEME.Bad
	local lines = { res.NightName .. (res.Success and " — the team made it!" or " — the mascots won this time...") }
	for _, l in res.Lines do
		table.insert(lines, l)
	end
	table.insert(lines, ("Tickets earned tonight: %d 🎟"):format(res.Tickets))
	body.Lines.Text = table.concat(lines, "\n")
	UI.Open("Results")
	task.delay(Config.ResultsTime - 0.5, function()
		panel.Visible = false
	end)
end

------------------------------------------------------------------------------
-- Panels
------------------------------------------------------------------------------
local wardrobeRefresh: () -> ()
local shopRefresh: () -> ()

local function buildShop()
	local _, body = makePanel("Shop", "🛒 GUARD SHOP", Vector2.new(600, 460))
	local list = new("ScrollingFrame", {
		Parent = body,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ZIndex = 21,
	}, { new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local rows = {}
	for i, entry in Config.ShopCatalog do
		local row = new("Frame", { Parent = list, LayoutOrder = i, Size = UDim2.new(1, -10, 0, 74), BackgroundColor3 = THEME.Panel2, ZIndex = 21 }, { corner(12) })
		label({ Parent = row, Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -170, 0, 30), Font = TITLE_FONT, Text = entry.Name, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22,
			TextColor3 = entry.Kind == "Pass" and THEME.Gold or THEME.Text })
		label({ Parent = row, Position = UDim2.fromOffset(12, 38), Size = UDim2.new(1, -170, 0, 26), Text = entry.Desc, TextColor3 = THEME.Muted, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22 })
		local buy = button({ Parent = row, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(140, 50), BackgroundColor3 = THEME.Good, Text = "R$ " .. entry.Price, ZIndex = 22 }, function()
			local id = entry.Kind == "Pass" and Config.GamePasses[entry.Key] or Config.Products[entry.Key]
			if not id or id == 0 then
				UI.Toast("Coming soon! (set the ID in Config.lua)", THEME.Muted)
				return
			end
			if entry.Kind == "Pass" then
				MarketplaceService:PromptGamePassPurchase(player, id)
			else
				MarketplaceService:PromptProductPurchase(player, id)
			end
		end)
		rows[entry] = buy
	end
	shopRefresh = function()
		local passes = UI.Profile and UI.Profile.Passes or {}
		for entry, buy in rows do
			if entry.Kind == "Pass" and passes[entry.Key] then
				buy.Text = "OWNED ✓"
				buy.BackgroundColor3 = THEME.Muted
				buy.Active = false
			end
		end
	end
end

local function buildPrizes()
	local _, body = makePanel("Prizes", "🎁 PRIZE COUNTER", Vector2.new(600, 440))
	label({ Parent = body, Size = UDim2.new(1, 0, 0, 30), Text = "Spend your tickets on capsules to win permanent cosmetics!", TextColor3 = THEME.Muted, ZIndex = 21 })
	local result = label({ Parent = body, Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 0, 90), Font = TITLE_FONT, Text = "?", TextColor3 = THEME.Gold, ZIndex = 21 })
	local sub = label({ Parent = body, Position = UDim2.fromOffset(0, 130), Size = UDim2.new(1, 0, 0, 30), Text = "", TextColor3 = THEME.Muted, ZIndex = 21 })
	local busy = false
	local function odds(tier)
		local o = Cosmetics.CapsuleOdds[tier]
		return ("Common %g%% · Rare %g%% · Epic %g%% · Legendary %g%%"):format(o.Common, o.Rare, o.Epic, o.Legendary)
	end
	local function roll(tier)
		if busy then
			return
		end
		busy = true
		sub.Text = "Rolling..."
		local res = Remotes.RollCapsule:InvokeServer(tier)
		if not res or not res.Ok then
			result.Text = "✖"
			result.TextColor3 = THEME.Bad
			sub.Text = res and res.Error or "Error"
			busy = false
			return
		end
		-- slot machine effect
		for i = 1, 16 do
			local it = Cosmetics.Items[math.random(1, #Cosmetics.Items)]
			result.Text = it.Name
			result.TextColor3 = Cosmetics.Rarities[it.Rarity].Color
			task.wait(0.04 + i * 0.008)
		end
		local rarity = Cosmetics.Rarities[res.Rarity]
		result.Text = res.Name
		result.TextColor3 = rarity.Color
		sub.Text = res.Duplicate and ("%s duplicate — refunded %d 🎟"):format(res.Rarity, res.Refund)
			or ("NEW %s %s! Equip it in the Wardrobe."):format(string.upper(res.Rarity), res.Type:lower())
		UI.ShowReward({ Rarity = res.Rarity, Title = res.Name, Text = sub.Text })
		busy = false
	end
	for i, tier in { "Basic", "Deluxe" } do
		local x = (i - 1) * 0.5
		button({
			Parent = body,
			Position = UDim2.new(x, 8, 0, 180),
			Size = UDim2.new(0.5, -16, 0, 90),
			BackgroundColor3 = tier == "Basic" and THEME.Accent2 or THEME.Accent,
			Text = ("%s Capsule\n%d 🎟"):format(tier, Config.CapsuleCosts[tier]),
			ZIndex = 21,
		}, function()
			roll(tier)
		end)
		label({ Parent = body, Position = UDim2.new(x, 8, 0, 276), Size = UDim2.new(0.5, -16, 0, 40), Text = odds(tier), TextColor3 = THEME.Muted, TextWrapped = true, ZIndex = 21 })
	end
	label({ Parent = body, Position = UDim2.fromOffset(0, 326), Size = UDim2.new(1, 0, 0, 28), Text = "🍀 Lucky Charm pass doubles Epic & Legendary odds!", TextColor3 = THEME.Gold, ZIndex = 21 })
end

local function buildWardrobe()
	local _, body = makePanel("Wardrobe", "👕 WARDROBE", Vector2.new(640, 480))
	local tabs = new("Frame", { Parent = body, Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, ZIndex = 21 }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }),
	})
	local grid = new("ScrollingFrame", {
		Parent = body,
		Position = UDim2.fromOffset(0, 54),
		Size = UDim2.new(1, 0, 1, -54),
		BackgroundTransparency = 1,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ZIndex = 21,
	}, { new("UIGridLayout", { CellSize = UDim2.fromOffset(140, 100), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local current = "Light"
	wardrobeRefresh = function()
		for _, c in grid:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local profile = UI.Profile
		if not profile then
			return
		end
		local equipped = profile.Equipped[current]
		if current ~= "Light" then
			button({ Parent = grid, LayoutOrder = 0, BackgroundColor3 = equipped == nil and THEME.Good or THEME.Panel2, Text = "None", ZIndex = 22 }, function()
				Remotes.Equip:FireServer(current, nil)
			end)
		end
		for i, item in Cosmetics.Items do
			if item.Type == current then
				local owned = profile.Owned[item.Id]
				local rarity = Cosmetics.Rarities[item.Rarity]
				local b = button({
					Parent = grid,
					LayoutOrder = rarity.Order * 100 + i,
					BackgroundColor3 = equipped == item.Id and THEME.Good or THEME.Panel2,
					Text = owned and item.Name or "🔒 ???",
					TextColor3 = owned and THEME.Text or THEME.Muted,
					ZIndex = 22,
				}, function()
					if owned then
						Remotes.Equip:FireServer(current, item.Id)
					else
						UI.Toast("Win it at the Prize Counter!", THEME.Muted)
					end
				end)
				local s = stroke(rarity.Color, 3)
				s.Transparency = 0
				s.Parent = b
			end
		end
	end
	for _, tab in { { "Light", "🔦 Beams" }, { "Trail", "✨ Trails" }, { "Title", "🏷 Titles" } } do
		button({ Parent = tabs, Size = UDim2.fromOffset(150, 40), BackgroundColor3 = THEME.Accent2, Text = tab[2], ZIndex = 22 }, function()
			current = tab[1]
			wardrobeRefresh()
		end)
	end
end

local function buildGuide()
	local _, body = makePanel("Guide", "📖 MEET THE MASCOTS", Vector2.new(680, 500))
	local list = new("ScrollingFrame", {
		Parent = body,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ZIndex = 21,
	}, { new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local how = new("Frame", { Parent = list, LayoutOrder = 0, Size = UDim2.new(1, -10, 0, 150), BackgroundColor3 = THEME.Panel2, ZIndex = 21 }, { corner(12) })
	label({ Parent = how, Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 1, -12), TextWrapped = true, TextScaled = false, TextSize = 17, ZIndex = 22,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
		Text = "HOW TO PLAY\n• Do the tasks on the left: fuses, tokens, deliveries.\n• All tasks done = the front doors open. ESCAPE!\n• Or simply survive until 6 AM.\n• Caught? You become a ghost: press Q to reveal the mascots.\n• Each completed task revives every ghost." })
	for i, name in Mascots.Order do
		local def = Mascots[name]
		local card = new("Frame", { Parent = list, LayoutOrder = i, Size = UDim2.new(1, -10, 0, 86), BackgroundColor3 = THEME.Panel2, ZIndex = 21 }, { corner(12) })
		new("Frame", { Parent = card, Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(66, 66), BackgroundColor3 = def.Color, ZIndex = 22 }, { corner(33) })
		label({ Parent = card, Position = UDim2.fromOffset(90, 6), Size = UDim2.new(1, -100, 0, 32), Font = TITLE_FONT, Text = def.DisplayName, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = THEME.Gold, ZIndex = 22 })
		label({ Parent = card, Position = UDim2.fromOffset(90, 40), Size = UDim2.new(1, -100, 0, 40), Text = def.Rule, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22 })
	end
end

local function buildResults()
	local _, body = makePanel("Results", "🌙 SHIFT REPORT", Vector2.new(520, 340))
	label({ Name = "Head", Parent = body, Size = UDim2.new(1, 0, 0, 60), Font = TITLE_FONT, ZIndex = 21 })
	label({ Name = "Lines", Parent = body, Position = UDim2.fromOffset(0, 70), Size = UDim2.new(1, 0, 1, -70), TextScaled = false, TextSize = 20, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 21 })
end

local function buildTutorial()
	local panel, body = makePanel("Tutorial", "🍕 WELCOME, NEW GUARD!", Vector2.new(600, 400))
	local pages = {
		"You've been hired as the night guard at PIP'S PARTY PALACE.\nThe mascots come alive at night... and they want to play.",
		(UI.IsTouch and "Use the 🔦 button for your flashlight, 🏃 to run, and tap items to use them." or "F = flashlight   SHIFT = run   1/2/3 = items   E = interact")
			.. "\nRunning makes noise. Batteries are precious!",
		"Each night, do the TASKS on the left of your screen.\nWhen everything is done the front doors open: ESCAPE for a bonus!",
		"Every mascot has ONE rule. Read them at the 📖 Mascots board.\nFind loot & Prize Capsules, then spend tickets at the Prize Counter. Good luck!",
	}
	local text = label({ Parent = body, Size = UDim2.new(1, 0, 1, -80), TextWrapped = true, ZIndex = 21 })
	local page = 1
	local nextBtn
	local function render()
		text.Text = pages[page]
		nextBtn.Text = page < #pages and "NEXT ➜" or "LET'S GO! (+50 🎟)"
	end
	nextBtn = button({ Parent = body, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), Size = UDim2.fromOffset(280, 60), BackgroundColor3 = THEME.Good, ZIndex = 21 }, function()
		if page < #pages then
			page += 1
			render()
		else
			panel.Visible = false
			Remotes.TutorialDone:FireServer()
		end
	end)
	render()
end

------------------------------------------------------------------------------
-- State updates
------------------------------------------------------------------------------
function UI.SetProfile(profile)
	local first = UI.Profile == nil
	UI.Profile = profile
	hud.Tickets.Text = "🎟 " .. formatNumber(profile.Tickets)
	hud.DailyBtn.Visible = profile.DailyAvailable and not player:GetAttribute("InNight")
	if wardrobeRefresh and panels.Wardrobe.Visible then
		wardrobeRefresh()
	end
	if shopRefresh then
		shopRefresh()
	end
	if first and not profile.Tutorial then
		UI.Open("Tutorial")
	elseif first and profile.DailyAvailable then
		UI.Toast("🎁 Your daily reward is ready! Click DAILY on the left.", THEME.Gold)
	end
end

local function hourText(h: number): string
	if h <= 0 then
		return "12 AM"
	end
	return ("%d AM"):format(h)
end

function UI.SetState(s)
	UI.State = s
	local inNight = player:GetAttribute("InNight") == true
	hud.Night.Text = s.NightName
	if s.Phase == "Night" then
		hud.Clock.Text = (s.Hour >= 6) and "6 AM" or hourText(s.Hour)
		hud.Sub.Text = ("👥 %d/%d guards alive"):format(s.Alive, s.Total)
	elseif s.Phase == "Intermission" then
		hud.Clock.Text = ("Shift starts in %d"):format(s.TimeLeft)
		hud.Sub.Text = s.Message ~= "" and s.Message or "Get ready in the parking lot..."
	else
		hud.Clock.Text = "Shift over"
		hud.Sub.Text = s.Message
	end

	-- tasks
	local showQuests = s.Phase == "Night" and (inNight or player:GetAttribute("Ghost") == true)
	hud.Quests.Visible = showQuests
	for _, row in hud.QuestRows do
		row:Destroy()
	end
	table.clear(hud.QuestRows)
	if showQuests then
		for i, o in s.Objectives do
			local text = (o.Done and "✅ " or "⬜ ") .. o.Text
			if o.Goal > 1 then
				text ..= (" (%d/%d)"):format(o.Progress, o.Goal)
			end
			local row = label({
				Parent = hud.Quests,
				LayoutOrder = i,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				TextScaled = false,
				TextSize = 17,
				TextWrapped = true,
				Text = text,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = o.Done and THEME.Good or (o.Id == "Escape" and THEME.Gold or THEME.Text),
			})
			table.insert(hud.QuestRows, row)
		end
		local survive = label({ Parent = hud.Quests, LayoutOrder = 99, Size = UDim2.new(1, 0, 0, 22), TextScaled = false, TextSize = 16, Text = "⏰ ...or survive until 6 AM", TextColor3 = THEME.Muted, TextXAlignment = Enum.TextXAlignment.Left })
		table.insert(hud.QuestRows, survive)
	end
	-- music box
	hud.MusicBox.Visible = showQuests and s.MusicBox ~= nil
	if s.MusicBox then
		hud.MusicBoxFill.Size = UDim2.fromScale(math.clamp(s.MusicBox / 100, 0, 1), 1)
		hud.MusicBoxFill.BackgroundColor3 = s.MusicBox < 30 and THEME.Bad or THEME.Accent
		hud.MusicBoxLabel.Text = ("🎵 MUSIC BOX %d%%"):format(s.MusicBox)
		hud.MusicBox.Position = UDim2.fromOffset(12, 120 + hud.Quests.AbsoluteSize.Y / scaleObj.Scale + 8)
	end
	hud.JoinBtn.Visible = s.CanJoin and not inNight
end

-- called every frame by Controls
function UI.UpdatePlayer(stamina: number)
	local inNight = player:GetAttribute("InNight") == true
	local ghost = player:GetAttribute("Ghost") == true
	local hidden = player:GetAttribute("Hidden") == true
	local alive = inNight and not ghost
	hud.Bottom.Visible = alive
	hud.FlashBtn.Visible = alive
	hud.SprintBtn.Visible = UI.IsTouch and alive
	hud.PingBtn.Visible = ghost and inNight
	hud.ReviveBtn.Visible = ghost and inNight and Config.Products.Revive ~= 0
	hud.Menu.Visible = not inNight and not ghost
	if alive then
		local b = player:GetAttribute("Battery") or 0
		hud.BatteryFill.Size = UDim2.fromScale(math.clamp(b / 100, 0, 1), 1)
		hud.BatteryFill.BackgroundColor3 = b < 20 and THEME.Bad or (b < 50 and THEME.Gold or THEME.Good)
		hud.BatteryLabel.Text = ("🔦 %d%%"):format(b)
		hud.StaminaFill.Size = UDim2.fromScale(math.clamp(stamina / Config.StaminaMax, 0, 1), 1)
		for item, slot in hud.Slots do
			local n = player:GetAttribute("Inv_" .. item) or 0
			slot.Count.Text = "x" .. n
			slot.Button.BackgroundTransparency = n > 0 and 0.15 or 0.6
		end
		hud.FlashBtn.BackgroundColor3 = player:GetAttribute("FlashlightOn") and C(255, 230, 120) or C(120, 110, 90)
	end
	-- banner
	local banner = hud.Banner
	if ghost and inNight then
		banner.Visible = true
		banner.TextColor3 = C(170, 220, 255)
		banner.Text = UI.IsTouch and "👻 YOU'RE A GHOST — tap 👻 to reveal the mascots" or "👻 YOU'RE A GHOST — press Q to reveal the mascots"
	elseif hidden then
		local left = math.max(0, math.ceil((player:GetAttribute("HideUntil") or 0) - workspace:GetServerTimeNow()))
		banner.Visible = true
		banner.TextColor3 = THEME.Gold
		banner.Text = ("🤫 Hiding... %ds of breath left (interact to leave)"):format(left)
	elseif UI.Chased then
		banner.Visible = true
		banner.TextColor3 = THEME.Bad
		banner.Text = "⚠️ " .. UI.Chased .. " IS CHASING YOU — RUN!"
	elseif (player:GetAttribute("Carrying") or "") ~= "" then
		banner.Visible = true
		banner.TextColor3 = THEME.Accent2
		banner.Text = player:GetAttribute("Carrying") == "Tape" and "📼 Carrying the tape → Security Office VCR" or "⛽ Carrying gas → Generator (Parts & Service)"
	else
		banner.Visible = false
	end
end

function UI.Init()
	gui = new("ScreenGui", {
		Name = "PipsHUD",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	root = new("Frame", { Name = "Root", Parent = gui, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
	scaleObj = new("UIScale", { Parent = root })
	updateScale()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)

	buildHud()
	buildRewardCard()
	buildShop()
	buildPrizes()
	buildWardrobe()
	buildGuide()
	buildResults()
	buildTutorial()

	UI.OnOpen = function(name)
		if name == "Wardrobe" and wardrobeRefresh then
			wardrobeRefresh()
		end
	end

	Remotes.Notify.OnClientEvent:Connect(UI.Notify)
	Remotes.Reward.OnClientEvent:Connect(UI.ShowReward)
	Remotes.Results.OnClientEvent:Connect(UI.ShowResults)
	Remotes.ProfileUpdate.OnClientEvent:Connect(UI.SetProfile)
	Remotes.GameState.OnClientEvent:Connect(UI.SetState)
	Remotes.OpenUI.OnClientEvent:Connect(function(name)
		if typeof(name) == "string" and panels[name] then
			UI.Open(name)
		end
	end)
	return gui
end

return UI
