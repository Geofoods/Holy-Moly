extends Node

## Single source of truth for the in-game encyclopedia (Info popup).
## To add a new enemy/hazard/item, append one dictionary to ENTRIES below.
## The Info popup picks it up automatically.

const ENTRIES: Array[Dictionary] = [
	{
		"id": "beetle",
		"name": "Beetle",
		"icon": "res://beetle.webp",
		"icon_region": Rect2(0, 0, 900, 600),
		"category": "Enemy",
		"danger_level": 3,
		"description": "A hard-shelled burrow dweller that patrols the tunnels in short stretches.",
		"behavior": "Paces back and forth until it spots you, then locks on and rushes straight at you at high speed before pulling back to cool down.",
		"attack_pattern": "550 px/s charge for about 1.2 seconds, dealing contact damage, followed by a roughly 2.5 second cooldown before it can charge again.",
		"strategy": "Time your shovel swing (Left-click) for the moment it commits to a charge, since it can't change direction mid-rush. Or just jump over it. Takes 4 hits to defeat.",
	},
	{
		"id": "goblin",
		"name": "Goblin",
		"icon": "res://golblin.webp",
		"icon_region": Rect2(0, 0, 620, 414),
		"category": "Enemy",
		"danger_level": 3,
		"description": "A scrappy raider that's more aggressive and alert than the average tunnel pest.",
		"behavior": "Detects you from further away than a Beetle and charges almost immediately, slowing to a stop afterward before resuming its patrol.",
		"attack_pattern": "Fast 400 px/s charge dealing contact damage, with a short cooldown before it can charge again.",
		"strategy": "Don't get caught flat-footed by its longer detection range. Swing early or dodge sideways as it closes in. It's recommended to parry (Right-click) the mushroom projectiles it throws—deflecting them back deals damage and keeps you safe. Takes 4 hits to defeat.",
	},
	{
		"id": "ant",
		"name": "Ant",
		"icon": "res://scenes/ant_walk.webp",
		"icon_region": Rect2(0, 0, 576, 385),
		"category": "Enemy",
		"danger_level": 2,
		"description": "A light, fast scuttler that isn't afraid to follow you off the ground.",
		"behavior": "Patrols the tunnel and turns to face you once it notices you. When it hits a wall, it sometimes scales straight up it to chase you onto higher ground.",
		"attack_pattern": "Deals contact damage. The main threat is being cornered when it climbs up to your platform.",
		"strategy": "The weakest enemy in the burrow. A couple of shovel swings (3 hits) puts it down, or just outrun it.",
	},
	{
		"id": "bomb",
		"name": "Bomb",
		"icon": "res://scenes/bomb.webp",
		"icon_region": Rect2(),
		"category": "Item",
		"danger_level": 2,
		"description": "A thrown explosive for clearing tough terrain and groups of enemies at once.",
		"behavior": "Select it from your inventory (number key) and Left-click to throw it toward your cursor. It arms on impact and counts down before detonating.",
		"attack_pattern": "About a 2.5 second fuse, then a 200px-radius blast that destroys nearby tiles and instantly defeats any enemy caught inside it.",
		"strategy": "Throw it from a safe distance. The blast damages you too if you're still standing in the radius when it goes off. Great for blasting through blocked tunnels.",
	},
	{
		"id": "drill",
		"name": "Bomb Drill",
		"icon": "res://drill.webp",
		"icon_region": Rect2(),
		"category": "Item",
		"danger_level": 1,
		"description": "A spinning drill head that bores straight through rock and enemies alike.",
		"behavior": "Select it from your inventory and Left-click to launch it toward your cursor. It travels in a straight line, tunneling through tiles as it goes.",
		"attack_pattern": "Travels for about 2 seconds, instantly defeating any enemy it touches along its path. Unlike the Bomb, it never damages you.",
		"strategy": "Aim it straight down a corridor to clear a path and any enemies lined up in it in one shot. Completely safe to use up close.",
	},
]

## Controls / mechanics reference for the Info popup's "Controls" tab.
## Each entry: a category heading and a list of {label, detail} rows.
const CONTROLS: Array[Dictionary] = [
	{
		"category": "Movement",
		"rows": [
			{"label": "A / D or ◄ ►", "detail": "Move left / right."},
			{"label": "W / ▲ / SPACE", "detail": "Jump. Hold a direction while airborne to lock in a sideways jump arc."},
		],
	},
	{
		"category": "Digging",
		"rows": [
			{"label": "SHIFT", "detail": "Dig-dash. Tunnel straight through terrain in front of you."},
			{"label": "Left-click (mid-dash)", "detail": "Cancel the dash into an attack, breaking out with a burst and a screen shake."},
		],
	},
	{
		"category": "Combat",
		"rows": [
			{"label": "Left-click", "detail": "Swing your shovel. Breaks the tile under your cursor and damages any enemy it hits."},
			{"label": "Right-click", "detail": "Parry. Raise your shovel as a guard for a couple of seconds, deflecting anything it blocks back toward your cursor. Has a short cooldown after use."},
		],
	},
	{
		"category": "Inventory",
		"rows": [
			{"label": "1 / 2 / 3", "detail": "Select an inventory slot. Press the same key again to deselect."},
			{"label": "Bomb / Drill", "detail": "While selected, Left-click to throw toward your cursor. See the Bestiary tab for what each one does."},
			{"label": "Health Potion", "detail": "Selecting it instantly drinks it, restoring 1 heart."},
			{"label": "Speed Boots / Shield", "detail": "Selecting it instantly activates a temporary speed boost or invulnerability."},
		],
	},
	{
		"category": "Health & Objective",
		"rows": [
			{"label": "Hearts (top-left)", "detail": "You have 6 hearts. Taking damage costs hearts and grants a brief moment of invulnerability."},
			{"label": "Depth meter", "detail": "Shows how far underground you've dug, near the bottom of the screen."},
			{"label": "Losing", "detail": "Running out of hearts sends you to the Game Over screen."},
			{"label": "Winning a level", "detail": "Reach the glowing level exit to move on. There are 9 levels in total."},
		],
	},
	{
		"category": "Menus",
		"rows": [
			{"label": "ESC", "detail": "Pause the game. Resume, return to the main menu, or quit."},
			{"label": "Info button (bottom-right)", "detail": "Opens this screen any time, in a level or from the main menu."},
		],
	},
]

func get_entries() -> Array[Dictionary]:
	return ENTRIES

func get_entry(id: String) -> Dictionary:
	for entry in ENTRIES:
		if entry["id"] == id:
			return entry
	return {}

func get_controls() -> Array[Dictionary]:
	return CONTROLS
