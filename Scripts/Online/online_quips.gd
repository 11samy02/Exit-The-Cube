class_name OnlineQuips
extends RefCounted

## The commentary track for everything online. The lines are drawn through the
## Quips autoload so a pool never repeats itself until it has been all the way
## through, which is exactly what is wanted on a screen the player sits on while
## waiting for four friends to press ready

## Under the Host / Join question. Two thirds of a lobby going wrong happens
## here, so this is where the advice goes
const HOST_OR_JOIN := [
	"let the friend with the best PC host",
	"whoever hosts decides the maze. choose your dictator wisely",
	"hosting is free. the blame is not",
	"one of you hosts, the rest of you complain about the size",
	"the host picks the map. everyone else picks excuses",
	"someone has to press HOST. it is not going to be the one with wifi",
	"host if your download bar has ever finished on the first try",
	"joining is easier. hosting is legend",
	"the host builds the maze. the maze builds the argument",
	"pick HOST if you own a chair with wheels",
]

## Shown on the host button itself, one line under it
const HOST_HINT := [
	"build the maze, set the rules, take the blame",
	"you decide how big and how mean this gets",
	"twelve cubes, one exit, your maze",
	"your machine, your maze, your fault",
]

## Shown on the join button
const JOIN_HINT := [
	"find a lobby and hope they picked SMALL",
	"someone else already did the hard part",
	"walk into a maze you did not agree to",
	"show up, press ready, blame the host",
]

## The line at the top of the lobby while people are still trickling in
const LOBBY_WAITING := [
	"waiting on the one who is definitely getting a drink",
	"everybody ready? no. never. press it anyway",
	"twelve cubes fit in here. so far you have fewer",
	"the maze is already built in your head. relax",
	"nobody has died yet. enjoy this part",
	"ready up. the elevator does not wait, but the host does",
	"a lobby is just a queue with opinions",
	"last one ready picks the next difficulty. that is not a real rule",
]

## The line once the whole lobby is ready and only the host is holding it up
const LOBBY_ALL_READY := [
	"everyone is ready. the host is now the problem",
	"all green. press START before somebody changes their mind",
	"the lobby is ready. the maze is not sorry",
	"go. before the one at the back unreadies again",
]

## Shown to a member while the host is still fiddling with the settings
const LOBBY_MEMBER := [
	"the host is choosing. you are along for the ride",
	"you cannot change the size. you can only be disappointed by it",
	"press ready and pretend you looked at the difficulty",
	"whatever they pick, act like it was your idea",
]

## Goes up over the loading screen while the maze is being built
const RACE_START := [
	"same maze. same key. same exit. no excuses",
	"everyone got the identical maze. the wrong turns are all yours",
	"they are in there with you. sort of",
	"the ghosts running past you are real people making real mistakes",
	"first one out wins. fewest deaths wins harder",
]

## The line on the results panel when the player took first place outright
const RESULT_FIRST := [
	"first out, and you barely bled for it",
	"the maze lost. tell everyone",
	"put it on a shelf. there is no shelf. put it somewhere",
	"clean run. suspiciously clean run",
]

## When the player finished but somebody was ahead
const RESULT_MID := [
	"out alive. that already beats the ones still in there",
	"somebody was faster. somebody is always faster",
	"a respectable exit from a disrespectful maze",
	"you finished. that is more than the maze wanted",
]

## When the player came last of the ones who made it out
const RESULT_LAST := [
	"last out. the elevator waited, which is more than they did",
	"you took the scenic route. all of it",
	"the maze got its money's worth",
	"somebody has to be the control group",
]

## Under the standings while other players are still running
const RESULT_WAITING := [
	"the others are still in there. watch them suffer",
	"pick somebody and follow them. they will not know",
	"spectating is free. dignity is not",
	"they are still walking into blades. you may look",
]


## The three lines the results panel picks between, by where the player landed.
## Coming second out of two is not being last, it is being second, and a line
## about the elevator waiting reads as a joke at the wrong player
## Which pool a finishing place falls in, by name, so the text file can reach
## each of them on its own rather than all three under one heading
static func result_key(rank: int, finishers: int) -> String:
	if rank <= 1:
		return "online_result_first"

	if finishers >= 3 and rank >= finishers:
		return "online_result_last"

	return "online_result_mid"


static func result_pool(rank: int, finishers: int) -> Array:
	if rank <= 1:
		return RESULT_FIRST

	if finishers >= 3 and rank >= finishers:
		return RESULT_LAST

	return RESULT_MID
