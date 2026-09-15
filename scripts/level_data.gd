extends Node

const LEVELS: Dictionary = {
	"res://scenes/level1.tscn": {
		"number": 1,
		"name": "The Surface Tunnels",
		"tip": "Mushroom Casters lob exploding spores from a distance. Dodge or break them with a shovel swing, or close the gap fast.",
	},
	"res://scenes/level_02.tscn": {
		"number": 2,
		"name": "Ant Outskirts",
		"tip": "Ants can climb straight up walls to chase you. Getting to higher ground doesn't automatically lose them.",
	},
	"res://scenes/level_03.tscn": {
		"number": 3,
		"name": "Ant Nest",
		"tip": "This nest is packed with Ants. Fight in narrow spots so only one can reach you at a time.",
	},
	"res://scenes/level_04.tscn": {
		"number": 4,
		"name": "Goblin Outpost",
		"tip": "Goblins throw explosive mushrooms -- Right-Click to PARRY them back! Parried mushrooms explode and damage nearby enemies.",
	},
	"res://scenes/level_05.tscn": {
		"number": 5,
		"name": "Beetle Hollow",
		"tip": "Beetles can't change direction mid-charge. Sidestep the rush, then punish while they recover.",
	},
	"res://scenes/level_06.tscn": {
		"number": 6,
		"name": "The Tangled Depths",
		"tip": "Ants, Goblins, and Beetles all mix here. Deal with chargers first before they close the distance.",
	},
	"res://scenes/level_07.tscn": {
		"number": 7,
		"name": "The Slime Pits",
		"tip": "Slimes leave a poison puddle where they land. Don't linger there, it keeps hurting you for several seconds.",
	},
	"res://scenes/level_08.tscn": {
		"number": 8,
		"name": "Goblin Stronghold",
		"tip": "Poison puddles and charging Goblins both hit hard here. Keep moving and don't get cornered.",
	},
	"res://scenes/level_hive.tscn": {
		"number": 9,
		"name": "The Queen's Hive",
		"tip": "The Queen Bee summons her hornet children to fight alongside her. Dodge her sting dives and break the hornets before they box you in.",
	},
	"res://scenes/level_09.tscn": {
		"number": 9,
		"name": "The Corrupted Core",
		"tip": "Every enemy from your journey can appear here. Stay sharp and don't get surrounded.",
	},
}

func get_info(scene_path: String) -> Dictionary:
	return LEVELS.get(scene_path, {})
