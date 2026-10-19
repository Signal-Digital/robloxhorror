-- Animatronic stats + the one simple rule players must learn for each of them.
local Mascots = {
	Bruno = {
		DisplayName = "Bruno the Bear",
		Behavior = "Hunter",
		RoamSpeed = 9,
		ChaseSpeed = 17,
		Sight = 75,
		FOV = 0.25, -- cos of half view angle (~150° cone)
		ActivateDelay = 15,
		Spawn = "Stage",
		Rule = "Hunts by SIGHT. Break line of sight or hide in a locker.",
		Color = Color3.fromRGB(140, 85, 45),
	},
	Maple = {
		DisplayName = "Maple the Moose",
		Behavior = "Listener",
		RoamSpeed = 8,
		ChaseSpeed = 19,
		Hearing = 60,
		ActivateDelay = 30,
		Spawn = "Backstage",
		Rule = "BLIND. Hears running, repairs and capsules. Walk slowly near her.",
		Color = Color3.fromRGB(196, 150, 95),
	},
	Pip = {
		DisplayName = "Pip the Penguin",
		Behavior = "Watcher",
		RoamSpeed = 12,
		ChaseSpeed = 21,
		Sight = 120,
		ActivateDelay = 45,
		Spawn = "Stage",
		Rule = "Only moves in the DARK. Keep your flashlight on him to freeze him.",
		Color = Color3.fromRGB(35, 40, 60),
	},
	Jinx = {
		DisplayName = "Jinx the Jester",
		Behavior = "Stalker",
		RoamSpeed = 20,
		ChaseSpeed = 23,
		ActivateDelay = 2,
		Spawn = "GiftBox",
		Rule = "Wakes up when the MUSIC BOX stops. Wind it to send him back.",
		Color = Color3.fromRGB(120, 60, 170),
	},
}

Mascots.Order = { "Bruno", "Maple", "Pip", "Jinx" }

return Mascots
