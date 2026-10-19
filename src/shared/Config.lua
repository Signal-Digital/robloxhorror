--[[
	Config — every tunable value of the game lives here.

	MONETISATION / BADGES : remplace les 0 par tes vrais IDs créés sur
	https://create.roblox.com (Monetization > Passes / Developer Products, Badges).
	Un ID à 0 = l'offre apparaît "Bientôt" dans la boutique et n'est pas achetable.
]]

local Config = {}

Config.GameName = "Night Shift at Pip's"
Config.PizzeriaName = "PIP'S PARTY PALACE"

-- Rounds ---------------------------------------------------------------
Config.IntermissionTime = 25 -- seconds in the parking lot between nights
Config.ResultsTime = 8
Config.NightLength = 300 -- real seconds from 12 AM to 6 AM (5 minutes)
Config.MinPlayers = 1
Config.LateJoinWindow = 0.4 -- fraction of the night during which lobby players may still clock in

-- Movement -------------------------------------------------------------
Config.WalkSpeed = 14
Config.SprintSpeed = 22
Config.SodaBonus = 7
Config.GhostSpeed = 24
Config.StaminaMax = 100
Config.StaminaDrain = 22 -- per second while sprinting
Config.StaminaRegen = 14
Config.SprintNoiseSpeed = 18 -- server treats anyone moving faster than this as "running" (noise)

-- Flashlight -----------------------------------------------------------
Config.Flashlight = {
	Drain = 1.1, -- % per second
	ProDrain = 0.65, -- with the Pro Flashlight game pass
	Range = 55,
	Brightness = 3,
	Angle = 50,
	FreezeCone = 0.9, -- cos of the half-angle that "lights" Pip
}

-- Misc gameplay ---------------------------------------------------------
Config.HideMaxTime = 18
Config.GhostPingCooldown = 12
Config.GhostPingDuration = 5
Config.DecoyDuration = 8
Config.SodaDuration = 8
Config.CatchDistance = 4.5

-- Rewards (tickets = soft currency) --------------------------------------
Config.Rewards = {
	Token = 3,
	TicketPickupMin = 3,
	TicketPickupMax = 8,
	Objective = 15,
	SurviveBase = 30,
	SurvivePerNight = 10,
	Escape = 25,
	FriendBonus = 0.2, -- +20% when playing with a friend
	VIPMultiplier = 2,
}

Config.CapsuleCosts = { Basic = 100, Deluxe = 350 }
Config.DuplicateRefund = { Common = 20, Rare = 60, Epic = 150, Legendary = 400 }

Config.Daily = { Base = 50, PerStreak = 25, MaxStreak = 7, Cooldown = 20 * 3600, StreakBreak = 48 * 3600 }

-- Social ----------------------------------------------------------------
Config.GroupId = 0 -- ton groupe Roblox : bonus unique pour les membres
Config.GroupReward = 150

-- Monetisation ------------------------------------------------------------
Config.GamePasses = {
	VIP = 0, -- x2 tickets, golden name tag
	ProFlashlight = 0, -- battery lasts ~70% longer, brighter beam
	LuckyCharm = 0, -- better Prize Counter odds
}

Config.Products = {
	Revive = 0, -- instant revive while a ghost
	PowerSurge = 0, -- full battery + 1 soda for the WHOLE team (social purchase)
	Tickets500 = 0,
	Tickets2000 = 0,
}

Config.ProductRewards = {
	Tickets500 = 500,
	Tickets2000 = 2000,
}

-- Shop display (Robux prices are set on the website, these are just labels)
Config.ShopCatalog = {
	{ Kind = "Pass", Key = "VIP", Name = "VIP Guard", Price = 199, Desc = "x2 tickets forever + golden name tag" },
	{ Kind = "Pass", Key = "ProFlashlight", Name = "Pro Flashlight", Price = 149, Desc = "Battery lasts much longer, brighter beam" },
	{ Kind = "Pass", Key = "LuckyCharm", Name = "Lucky Charm", Price = 249, Desc = "Better odds at the Prize Counter" },
	{ Kind = "Product", Key = "Revive", Name = "Instant Revive", Price = 25, Desc = "Come back to life right now (as a ghost)" },
	{ Kind = "Product", Key = "PowerSurge", Name = "Power Surge", Price = 49, Desc = "Full battery + a soda for your WHOLE team" },
	{ Kind = "Product", Key = "Tickets500", Name = "500 Tickets", Price = 49, Desc = "A bag of prize tickets" },
	{ Kind = "Product", Key = "Tickets2000", Name = "2000 Tickets", Price = 149, Desc = "A bucket of prize tickets" },
}

-- Badges (0 = disabled)
Config.Badges = {
	Welcome = 0,
	Night1 = 0,
	Night3 = 0,
	Night5 = 0,
	Escape = 0,
	Legendary = 0,
}

-- Sounds: colle des IDs audio publics (Creator Store > Audio). Vide = muet.
Config.Sounds = {
	Jumpscare = "",
	Ambience = "",
	Chase = "",
	MusicBox = "",
	Pickup = "",
	Fuse = "",
	Capsule = "",
	Heartbeat = "",
	SixAM = "",
}

-- Data -------------------------------------------------------------------
Config.DataStoreName = "PipsNightShift_v1"
Config.LeaderboardStoreName = "PipsNightShift_Nights_v1"

return Config
