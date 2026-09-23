extends Node

## Tutorial event bus: fires when the player completes each small task that a
## tutorial dialogue area instructs, so the NPC mole dialogue can close itself.

signal block_broken
signal chest_opened
signal enemy_attacked
signal item_used
signal dig_dash_started
signal ground_pound_done