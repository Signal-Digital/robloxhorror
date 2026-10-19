-- Permanent cosmetics won at the Prize Counter (persisted in the DataStore).
local Cosmetics = {}

Cosmetics.Rarities = {
	Common = { Order = 1, Color = Color3.fromRGB(190, 190, 190) },
	Rare = { Order = 2, Color = Color3.fromRGB(70, 150, 255) },
	Epic = { Order = 3, Color = Color3.fromRGB(180, 80, 255) },
	Legendary = { Order = 4, Color = Color3.fromRGB(255, 190, 40) },
}
Cosmetics.RarityOrder = { "Common", "Rare", "Epic", "Legendary" }

local function seq(...)
	local colors = { ... }
	if #colors == 1 then
		return ColorSequence.new(colors[1])
	end
	local kps = {}
	for i, c in colors do
		table.insert(kps, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), c))
	end
	return ColorSequence.new(kps)
end

Cosmetics.Items = {
	-- Flashlight beams
	{ Id = "Light_Default", Name = "Standard Beam", Type = "Light", Rarity = "Common", Color = Color3.fromRGB(255, 240, 205) },
	{ Id = "Light_Ice", Name = "Icy Beam", Type = "Light", Rarity = "Common", Color = Color3.fromRGB(170, 220, 255) },
	{ Id = "Light_Mint", Name = "Mint Beam", Type = "Light", Rarity = "Common", Color = Color3.fromRGB(170, 255, 205) },
	{ Id = "Light_Rose", Name = "Bubblegum Beam", Type = "Light", Rarity = "Rare", Color = Color3.fromRGB(255, 150, 200) },
	{ Id = "Light_Toxic", Name = "Toxic Beam", Type = "Light", Rarity = "Rare", Color = Color3.fromRGB(150, 255, 60) },
	{ Id = "Light_Violet", Name = "Phantom Beam", Type = "Light", Rarity = "Epic", Color = Color3.fromRGB(170, 100, 255) },
	{ Id = "Light_Blood", Name = "Blood Moon Beam", Type = "Light", Rarity = "Epic", Color = Color3.fromRGB(255, 50, 50) },
	{ Id = "Light_Gold", Name = "Golden Pip Beam", Type = "Light", Rarity = "Legendary", Color = Color3.fromRGB(255, 205, 70) },

	-- Trails
	{ Id = "Trail_Confetti", Name = "Confetti Trail", Type = "Trail", Rarity = "Common",
		Colors = seq(Color3.fromRGB(255, 90, 90), Color3.fromRGB(255, 220, 80), Color3.fromRGB(90, 200, 255)) },
	{ Id = "Trail_Pizza", Name = "Pizza Trail", Type = "Trail", Rarity = "Common",
		Colors = seq(Color3.fromRGB(255, 170, 40), Color3.fromRGB(230, 60, 30)) },
	{ Id = "Trail_Ghost", Name = "Ghostly Trail", Type = "Trail", Rarity = "Rare", Colors = seq(Color3.fromRGB(230, 240, 255)) },
	{ Id = "Trail_Neon", Name = "Arcade Neon Trail", Type = "Trail", Rarity = "Rare",
		Colors = seq(Color3.fromRGB(0, 255, 240), Color3.fromRGB(255, 0, 200)) },
	{ Id = "Trail_Shadow", Name = "Shadow Trail", Type = "Trail", Rarity = "Epic",
		Colors = seq(Color3.fromRGB(20, 0, 40), Color3.fromRGB(150, 0, 255)) },
	{ Id = "Trail_Rainbow", Name = "Party Rainbow", Type = "Trail", Rarity = "Legendary",
		Colors = seq(Color3.fromRGB(255, 0, 0), Color3.fromRGB(255, 200, 0), Color3.fromRGB(0, 255, 0),
			Color3.fromRGB(0, 160, 255), Color3.fromRGB(200, 0, 255)) },

	-- Titles (shown above your head)
	{ Id = "Title_Rookie", Name = "Rookie Guard", Type = "Title", Rarity = "Common", Color = Color3.fromRGB(220, 220, 220) },
	{ Id = "Title_Pizza", Name = "Pizza Lover", Type = "Title", Rarity = "Common", Color = Color3.fromRGB(255, 170, 60) },
	{ Id = "Title_Brave", Name = "Brave Soul", Type = "Title", Rarity = "Rare", Color = Color3.fromRGB(90, 170, 255) },
	{ Id = "Title_Survivor", Name = "Night Survivor", Type = "Title", Rarity = "Rare", Color = Color3.fromRGB(120, 255, 150) },
	{ Id = "Title_Nightmare", Name = "Nightmare Walker", Type = "Title", Rarity = "Epic", Color = Color3.fromRGB(200, 90, 255) },
	{ Id = "Title_Legend", Name = "Legend of Pip's", Type = "Title", Rarity = "Legendary", Color = Color3.fromRGB(255, 205, 60) },
}

Cosmetics.ById = {}
for _, item in Cosmetics.Items do
	Cosmetics.ById[item.Id] = item
end

-- Weights (%) per capsule tier
Cosmetics.CapsuleOdds = {
	Basic = { Common = 70, Rare = 24, Epic = 5.5, Legendary = 0.5 },
	Deluxe = { Common = 35, Rare = 42, Epic = 18, Legendary = 5 },
}
-- Lucky Charm game pass multiplies Epic/Legendary weights
Cosmetics.LuckyMultiplier = 2

function Cosmetics.RollRarity(tier: string, lucky: boolean, rng: Random): string
	local odds = Cosmetics.CapsuleOdds[tier] or Cosmetics.CapsuleOdds.Basic
	local weights = {}
	local total = 0
	for _, rarity in Cosmetics.RarityOrder do
		local w = odds[rarity]
		if lucky and (rarity == "Epic" or rarity == "Legendary") then
			w *= Cosmetics.LuckyMultiplier
		end
		weights[rarity] = w
		total += w
	end
	local roll = rng:NextNumber() * total
	for _, rarity in Cosmetics.RarityOrder do
		roll -= weights[rarity]
		if roll <= 0 then
			return rarity
		end
	end
	return "Common"
end

function Cosmetics.RandomOfRarity(rarity: string, rng: Random)
	local pool = {}
	for _, item in Cosmetics.Items do
		if item.Rarity == rarity and item.Id ~= "Light_Default" then
			table.insert(pool, item)
		end
	end
	return pool[rng:NextInteger(1, #pool)]
end

return Cosmetics
