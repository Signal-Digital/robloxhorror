-- Consumable items found in the pizzeria during a night (lost when the night ends).
local Items = {}

Items.Defs = {
	Battery = { Name = "Battery", Icon = "🔋", Max = 3, Key = "One", Desc = "Recharge your flashlight" },
	Soda = { Name = "Fizzy Soda", Icon = "🥤", Max = 3, Key = "Two", Desc = "Run faster for a few seconds" },
	Decoy = { Name = "Decoy Plush", Icon = "🧸", Max = 2, Key = "Three", Desc = "Squeaky plush that distracts animatronics" },
}
Items.Order = { "Battery", "Soda", "Decoy" }

-- Loot table of the Prize Capsules hidden in the pizzeria
Items.CapsuleLoot = {
	{ Kind = "Item", Item = "Battery", Weight = 28, Rarity = "Common" },
	{ Kind = "Item", Item = "Soda", Weight = 24, Rarity = "Common" },
	{ Kind = "Item", Item = "Decoy", Weight = 16, Rarity = "Rare" },
	{ Kind = "Tickets", Amount = 25, Weight = 20, Rarity = "Common" },
	{ Kind = "Tickets", Amount = 75, Weight = 8, Rarity = "Rare" },
	{ Kind = "Tickets", Amount = 200, Weight = 3, Rarity = "Epic" },
	{ Kind = "Cosmetic", Weight = 1, Rarity = "Legendary" },
}

function Items.RollCapsule(rng: Random)
	local total = 0
	for _, entry in Items.CapsuleLoot do
		total += entry.Weight
	end
	local roll = rng:NextNumber() * total
	for _, entry in Items.CapsuleLoot do
		roll -= entry.Weight
		if roll <= 0 then
			return entry
		end
	end
	return Items.CapsuleLoot[1]
end

return Items
