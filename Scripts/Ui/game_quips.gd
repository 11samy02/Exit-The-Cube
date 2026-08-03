class_name GameQuips

## Everything the game says while it is being played. Only the tables live here,
## drawing a line out of them is the job of the Quips autoload, which is also
## what keeps a line from coming up twice before the rest of its pool has been
## through

## Seconds under which a death counts as instant
const QUICK_DEATH_TIME := 3.0

## Deaths from which the really unhinged lines join in
const EXTREME_FROM := 500

## How often one of them actually comes up from there on, they are meant to be
## rare enough to be a surprise
const EXTREME_CHANCE := 0.12

## Ten lines per item, filed under the file name the level picks the item by.
## Each of them says what the item does, the item is never explained anywhere
## else, and each of them is allowed to be rude about it
const ITEMS := {
	"arrow": [
		"Arrow. It points at what you need next. Walking there is still your problem.",
		"A floating compass with opinions. It knows the key, it knows nothing about walls.",
		"Straight line to the target. The maze never agreed to that line.",
		"The arrow says that way. The corridor says have fun.",
		"Direction, not directions. Big difference in here.",
		"It aims at the key, then at the exit. It never aims at the saws.",
		"Now you know where. Where was the easy half.",
		"The arrow is honest. It is just useless about corners.",
		"Point and pray. Mostly point.",
		"It never lies about the target. It lies about how close it feels.",
	],
	"echo": [
		"Echo. It calls out, the maze answers, and the answer is your route.",
		"Waves run the corridors ahead of you. Follow the light, not your gut.",
		"This is the smarter cousin of the arrow. It walks the walls for you.",
		"Every few seconds it draws the actual way through. Try to keep up.",
		"Sonar for cubes. The maze cannot keep a secret from noise.",
		"The rings go where you should go. Radical idea: go there.",
		"It maps the shortest path. Shortest is not the same as safest.",
		"Listen to the walls. They are surprisingly chatty.",
		"The echo already solved this level. It is waiting for you now.",
		"Free navigation, no subscription, mild existential dread.",
	],
	"freeze": [
		"Freeze. Every blade stops. Every blade still cuts.",
		"The saws hold still. They did not become furniture.",
		"Time out for the blades. Touch one anyway and it still ends you.",
		"Frozen saws are a maze of standing knives. Walk it, do not sprint it.",
		"You stopped the machine. You did not switch it off.",
		"The level holds its breath. Use the pause, not the confidence.",
		"Standing saws are the polite kind. Still lethal, just punctual.",
		"Everything stopped except you and your bad decisions.",
		"The blades are frozen. Your hitbox, sadly, is not.",
		"Stillness is a window, not a shield. Climb through it.",
	],
	"rush": [
		"Rush. Much faster, much brighter, much harder to steer.",
		"You are a rainbow now. A rainbow that meets walls at speed.",
		"Maximum pace. The corners were not consulted.",
		"Speed with a colour scheme. The saws still do not care.",
		"This is the fast one. This is also the one that kills you fast.",
		"Momentum is a gift and a trap. You get both.",
		"Go, go, go. Braking is a skill issue you can solve later.",
		"You glow, you fly, you overshoot the turn.",
		"The corridors just got shorter. Your reaction time did not.",
		"Chaos, but colourful. Try to end up somewhere useful.",
	],
	"saw_paths": [
		"Saw paths. Every blade shows the route it patrols.",
		"The maze just handed you the timetable. Read it.",
		"Now you can see where the blades will be. Standing there is optional.",
		"Lines on the floor mean danger with a schedule.",
		"Knowledge is power. Knowledge is also a lot of glowing lines.",
		"The saws lost their privacy. Use that.",
		"Every route drawn out. Now walk the gaps between them.",
		"You can finally plan instead of flinch.",
		"The blades kept a routine. This one leaks it.",
		"Look at the lines, then at the exit, then breathe.",
	],
	"shield": [
		"Shield. One blade breaks on you instead of the other way round.",
		"A heart, a saw, one trade. Pick the saw carefully.",
		"You are the harder object now. For exactly one collision.",
		"Ram a saw. It loses. You keep going.",
		"It does not tick down. It waits until you need it.",
		"One free mistake, in a place that usually charges full price.",
		"The next blade you touch stops existing. Only the next one.",
		"Armour with a single use and a lot of attitude.",
		"Break something for once instead of being the broken thing.",
		"The wreck stays on the floor. Consider it a receipt.",
	],
	"speed": [
		"Speed. You run harder, the blades take it easier.",
		"Both dials move. Yours up, theirs down.",
		"Faster you, slower saws. Rare moment of fairness in here.",
		"It does not protect you. It rewrites the timing.",
		"The gaps between the blades got wider. Go through them.",
		"Controlled pace, unlike some other items in this maze.",
		"The level slowed down and nobody told the saws why.",
		"You are quicker and the maze is politer. Briefly.",
		"This one is for planning, not for panic.",
		"Tempo. Spend it before it forgets it was ever here.",
	],
}

## Said when an item is taken out of the slot, whichever item that was
const ITEM_USED := [
	"Spent. There are no refunds in here.",
	"Used it. Now make it worth something.",
	"Item burned. The clock is running.",
	"That is gone. Do not waste the window.",
	"You pressed the button. Bold.",
	"Effect is up. Move before it is not.",
	"Slot is empty again. Go find another sphere.",
	"Good call. Probably.",
	"Cashed in. Let us see the plan now.",
	"Active. Try to end up closer to the exit this time.",
	"One item, one chance, one countdown.",
	"That was the item doing its part. Your turn.",
	"Used. The maze noticed.",
	"The timer is ticking and nothing in here waits for you.",
]

const KEY := [
	"Key. Now find the elevator without dying, which is the hard half.",
	"Got it. The exit just unlocked and every saw got the memo.",
	"That is the easy part done. Allegedly.",
	"Key in hand. The maze suddenly feels longer, does it not.",
	"You carry the only thing in here that matters. Do not explode with it.",
	"Key collected. Turn around and start running.",
	"One key, one exit, several hundred ways to lose both.",
	"The elevator is waiting. It has been waiting a while.",
	"Key. Every blade between you and the door is personal now.",
	"Halfway. The worse half is next.",
	"You have the key. The maze has everything else.",
	"Win condition unlocked. Now do the walking.",
	"Key acquired. Try to keep the cube in one piece for once.",
	"There is an open door out there. Go and prove it.",
]

## The everyday death, said on the attempt that comes after it
const DEATHS := [
	"That is one way to stop moving.",
	"The blade did not even slow down for you.",
	"Cube: zero. Saw: everything.",
	"You found the sharp part. Congratulations.",
	"Respawning. Try being somewhere else this time.",
	"The maze is not personal. The saw might be.",
	"You had a plan. The plan had a saw in it.",
	"Physics remains undefeated.",
	"Beautiful run, terrible ending.",
	"That corner was a trap and you shook its hand.",
	"New attempt, same walls, slightly worse mood.",
	"You were so close. Statistically. In some universe.",
	"Turns out the cube is a consumable.",
	"You have been divided by a spinning thing.",
	"That was avoidable. Most of them are.",
	"Somewhere a saw is telling this story to its friends.",
	"Pieces of you are level decoration now.",
	"Back to the start. The walls missed you.",
	"You ran straight in. Confident. Wrong.",
	"The blade was doing its job. You were doing yours badly.",
	"Turned into confetti again.",
	"Reload. The maze forgot you already.",
	"You met the one thing in here that is faster than you.",
	"Bold route. Short route. Final route.",
	"The exit was that way. You went the other way. Loudly.",
	"Timing is everything and you had none of it.",
	"Every death teaches something. That one taught patience.",
	"Cube deleted. Cube re-issued. Try harder.",
	"That was not a shortcut.",
	"The saw did not read your plan either.",
	"You walked into that with your eyes fully open.",
	"Paint the walls one more time, why not.",
	"Another wreck for the collection.",
	"You will get it. Not that time, obviously.",
	"The blade appreciated the offering.",
	"Do not worry, the maze is exactly the same. So is the saw.",
	"That was a rhythm problem, not a maze problem.",
	"Stopped by something that never stops.",
	"Try waiting half a second. Once. As an experiment.",
	"The corridor won again.",
	"Reassembling the cube. Please stop feeding it to blades.",
	"That death had style. Very little else, but style.",
	"You are getting good at the dying part.",
	"The saws have a rhythm. You have a habit.",
	"That was not bad luck, that was a decision.",
	"Cube goes in, cube does not come out.",
	"Another data point for the same mistake.",
	"The elevator is still waiting. It is very patient.",
	"You are learning this level slowly, painfully and loudly.",
	"Nothing lost but time, dignity and structural integrity.",
]

## Died before the level was even properly on screen
const QUICK_DEATHS := [
	"Oh, is this a bug, or are you just bad?",
	"Three seconds. That has to be a personal record.",
	"You did not even see the maze yet.",
	"Blink and you missed your entire run.",
	"Speedrun, any percent, death category. Nice.",
	"The level had barely finished loading. Rude.",
	"Straight off the spawn. Impressive commitment.",
	"You lasted less time than this sentence.",
	"Did you press start or surrender?",
	"Not even a warm up lap.",
	"That saw was right there. It was RIGHT there.",
	"New attempt. Consider looking around first.",
]

## Said once, exactly on that death, and never again in the same run
const MILESTONES := {
	10: [
		"Ten deaths. The maze is keeping score now.",
		"Ten. That was the warm up, right?",
		"Double digits already. Pace yourself.",
	],
	25: [
		"Twenty five. The saws are starting to recognise your shape.",
		"Twenty five deaths. The walls are running out of clean spots.",
		"A quarter of a hundred. Still confident?",
	],
	50: [
		"Are you good? You died 50 times. Take a break.",
		"Fifty deaths. Water, chair, window. In that order.",
		"Fifty. That is not persistence any more, that is a hobby.",
	],
	75: [
		"Seventy five. At some point this stops being the fault of the game.",
		"Seventy five deaths and the maze has not moved once.",
		"Three quarters of a hundred. The blades are getting bored.",
	],
	100: [
		"You should probably see a therapist if you keep playing this.",
		"One hundred deaths. That is a number people write papers about.",
		"A full century of failure. Genuinely impressive.",
	],
	150: [
		"One fifty. The cube factory opened a second shift for you.",
		"A hundred and fifty. Do you still remember why you started?",
		"150 deaths. Somewhere out there someone cleared this level once.",
	],
	200: [
		"Two hundred. This is your life now.",
		"200 deaths. The saws have unionised and you are the reason.",
		"Two hundred. Please tell somebody that you are fine.",
	],
	250: [
		"250. There is a version of you who quit at ten and is happier.",
		"Two hundred and fifty deaths. The maze has stopped counting.",
		"At this point the respawn is the game.",
	],
	300: [
		"Three hundred. Nobody is coming to save you.",
		"300 deaths. You have spent more time exploding than walking.",
		"Three hundred. The blades would like to know if you are okay.",
	],
	400: [
		"Four hundred. Science would like a word.",
		"400 deaths. This is not gameplay any more, it is a ritual.",
		"Four hundred and still going. Genuinely terrifying.",
	],
	500: [
		"Five hundred deaths. Whatever you are looking for is not in this maze.",
		"500. You have died more often than this level has corners.",
		"Five hundred. Blink twice if you need help.",
	],
	666: [
		"Six hundred and sixty six. The saws would like to congratulate you personally.",
		"That number was on purpose, was it not.",
	],
	750: [
		"750 deaths. The elevator filed a missing person report.",
		"Seven fifty. You and this maze are legally married now.",
	],
	1000: [
		"One thousand deaths. Please take the loss and log off.",
		"1000. There is no achievement for this. There is only concern.",
	],
}

## Only from EXTREME_FROM on, and only now and then even there
const EXTREME := [
	"You have died more times than most people will ever play this game.",
	"The saws hold a meeting every night. You are the only item on the agenda.",
	"Somewhere a developer is watching this counter and quietly closing the laptop.",
	"This is not a maze any more. This is a relationship, and it is unhealthy.",
	"The cube stopped screaming a while ago. It only sighs now.",
	"Statistically a random number generator would have finished this by accident.",
	"Every wall in here carries your colour. Every single one.",
	"If you clear this level the achievement will simply say 'why'.",
	"The maze has learned nothing about you and you have learned nothing about it.",
	"You are not stuck in the maze. The maze is stuck with you.",
	"There is a real world outside. It has fewer blades. Mostly.",
	"By now the elevator is a story old cubes tell the new ones.",
]
