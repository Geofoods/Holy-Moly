extends Node


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
		"strategy": "Don't get caught flat-footed by its longer detection range. Swing early or dodge sideways as it closes in. Takes 4 hits to defeat.",
	},
	{
		"id": "ant",
		"name": "Ant",
		"icon": "res://scenes/ant_walk.webp",
		"icon_region": Rect2(0, 0, 576, 385),
		"category": "Enemy",
		"danger_level": 3,
		"description": "A light, fast scuttler that fires slowing projectiles and climbs walls to chase you.",
		"behavior": "Patrols the tunnel and turns to face you once it notices you. When it hits a wall, it sometimes scales straight up it to chase you onto higher ground. Every 5 seconds it fires an orange bullet toward you.",
		"attack_pattern": "Fires a slow-moving orange projectile every 5 seconds. If it hits you, you are slowed for 3 seconds. Also deals contact damage.",
		"strategy": "Dodge the orange bullets or break them with your shovel swing. A well-placed shovel hit can destroy the projectile before it hits you. Takes 3 shovel hits to take down.",
	},
	{
		"id": "slime",
		"name": "Poison Slime",
		"icon": "res://poison.webp",
		"icon_region": Rect2(),
		"category": "Enemy",
		"danger_level": 3,
		"description": "A toxic blob that leaps toward you.",
		"behavior": "Jumps toward your position. If it hits you, it deals contact damage and inflicts a poison effect over time.",
		"attack_pattern": "Leaps every few seconds. Deals poison damage.",
		"strategy": "Keep your distance and hit it when it lands.",
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
		"id": "holywater",
		"name": "Holy Water",
		"icon": "res://holywater.webp",
		"icon_region": Rect2(),
		"category": "Item",
		"danger_level": 0,
		"description": "A blessed flask of water that restores your health.",
		"behavior": "Select it from your inventory and use it to heal.",
		"attack_pattern": "Instantly heals you when consumed.",
		"strategy": "Save it for emergencies when your health is running low.",
	},
	{
		"id": "corrupted_heart",
		"name": "Corrupted Heart",
		"icon": "res://boss_bite.webp",
		"icon_region": Rect2(0, 0, 900, 600),
		"category": "Final Boss",
		"danger_level": 6,
		"description": "The corrupted source of darkness deep below the surface. A massive entity that has twisted the very tunnels around itself.",
		"behavior": "Emerges from the abyss when you reach the deepest level. It descends slowly while relentlessly attacking, spitting projectiles and spawning treasure chests.",
		"attack_pattern": "Fires projectiles in single or triple-spread patterns every 3 seconds. Spawns treasure chests periodically. Contact with the entity deals damage.",
		"strategy": "Crack open the chests he spawns for drills to deal massive damage to the boss, whilst avoiding his brutal onslaught. Or just use your shovel to wack him a lot, that works too...",
	},
]

const CONTROLS: Array[Dictionary] = [
	{
		"category": "Movement",
		"rows": [
			{"label": "Left / Right buttons (bottom-left)", "detail": "Move left / right."},
			{"label": "Up button (bottom-left)", "detail": "Jump."},
		],
	},
	{
		"category": "Digging",
		"rows": [
			{"label": "Burst button (bottom-right)", "detail": "Dig-dash. Tunnel straight through terrain in front of you."},
			{"label": "Tap (mid-dash)", "detail": "Cancel the dash into an attack, breaking out with a burst and a screen shake."},
		],
	},
	{
		"category": "Combat",
		"rows": [
			{"label": "Tap on enemies / tiles", "detail": "Swing your shovel. Breaks the tile under your finger and damages any enemy it hits."},
		],
	},
	{
		"category": "Inventory",
		"rows": [
			{"label": "Tap a slot", "detail": "Select an inventory slot. Tap the same slot again to deselect."},
			{"label": "Bomb / Drill", "detail": "While selected, tap to throw toward your finger. See the Bestiary tab for what each one does."},
			{"label": "Health Potion", "detail": "Tapping it instantly drinks it, restoring 1 heart."},
			{"label": "Speed Boots / Shield", "detail": "Tapping it instantly activates a temporary speed boost or invulnerability."},
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
			{"label": "Pause button (top-right)", "detail": "Pause the game. Resume, restart, or return to the main menu."},
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
