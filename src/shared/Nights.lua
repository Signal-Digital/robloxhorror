-- Night definitions: each night adds one new rule so players learn gradually.
local Nights = {}

Nights.List = {
	{
		Fuses = 3,
		Tokens = 6,
		Deliveries = {},
		MusicBox = false,
		Animatronics = { "Bruno" },
		SpeedMult = 1,
		Intro = "Fix the fuses, grab the party tokens, then escape!",
		Tip = "Bruno hunts by sight. Break line of sight or hide in a locker.",
	},
	{
		Fuses = 3,
		Tokens = 8,
		Deliveries = { { Kind = "Tape", Count = 1 } },
		MusicBox = false,
		Animatronics = { "Bruno", "Maple" },
		SpeedMult = 1.03,
		Intro = "Someone left a strange tape... bring it to the Security Office.",
		Tip = "Maple is blind but hears running. WALK when she's close.",
	},
	{
		Fuses = 4,
		Tokens = 8,
		Deliveries = { { Kind = "Gas", Count = 2 } },
		MusicBox = false,
		Animatronics = { "Bruno", "Maple", "Pip" },
		SpeedMult = 1.06,
		Intro = "The backup generator is empty. Refuel it with gas cans.",
		Tip = "Pip only moves in the dark. Keep your flashlight ON him.",
	},
	{
		Fuses = 4,
		Tokens = 10,
		Deliveries = { { Kind = "Tape", Count = 1 } },
		MusicBox = true,
		Animatronics = { "Bruno", "Maple", "Pip" },
		SpeedMult = 1.1,
		Intro = "Keep the music box wound... or Jinx comes out to play.",
		Tip = "Wind the music box in the Security Office before it stops!",
	},
	{
		Fuses = 5,
		Tokens = 12,
		Deliveries = { { Kind = "Tape", Count = 1 }, { Kind = "Gas", Count = 2 } },
		MusicBox = true,
		Animatronics = { "Bruno", "Maple", "Pip" },
		SpeedMult = 1.15,
		Intro = "The final night. Everything is awake.",
		Tip = "Work as a team: split up the tasks!",
	},
}

-- Night 6+ = "Nightmare" nights: night 5 rules, faster each time.
function Nights.Get(n: number)
	local def = Nights.List[math.min(n, #Nights.List)]
	local copy = table.clone(def)
	if n > #Nights.List then
		copy.SpeedMult = def.SpeedMult + 0.05 * (n - #Nights.List)
		copy.Intro = "NIGHTMARE MODE. They're faster than ever."
	end
	return copy
end

function Nights.Name(n: number): string
	if n > #Nights.List then
		return "NIGHTMARE " .. (n - #Nights.List)
	end
	return "NIGHT " .. n
end

return Nights
