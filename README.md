RECOMMENDED TO PLAY THE EXE VERSION AS THE BROWSER VERSION MIGHT GET A BIT LAGGY SOMETIMES

Holy Moly is just a game about a cute little mole! ...Or is it? The mole travels through the depths of hell, fighting enemies along the way. There are 9 layers of hell, each with more corrupted and horrid creatures than the next. Can you make it to the end, or will the corruption engulf you?

Features:

- 14 different levels
- Map and Quick Travel
- Health System
- Economy and Shop system
- Side quests
- Story
- Two boss fights
- Mole
- Chest System
- 4 different items
- Many Characters
- In-game Level Editor
  
CONTROLS:

WASD/ARROW KEYS: Movement

1 2 3 4: Change between hotbar/inventory items

SPACE/UP ARROW: Jump/Walljump

SHIFT: Dig Dash/Groundpound

ESC: Pause Game

M: Map

LEFT CLICK: Attack/Use item held or interact with HUD

MULTIPLAYER (PVP ARENA):

The MULTIPLAYER button on the title screen opens a lobby. One player presses HOST;
anyone else presses JOIN with the host's address and the same port (27015 by
default). The host presses START MATCH once everyone is in. The first player to
five kills wins.

WASD: Movement

SPACE: Jump

LEFT CLICK: Swing

ESC: Leave the match

Playing over the internet needs the host's port (UDP 27015) forwarded, or both
players on the same LAN. Netplay uses Godot's built-in ENet, which needs a real
UDP socket that a web page does not have, so the browser build does not offer the
mode.

LEVEL EDITOR:

The LEVEL EDITOR button on the title screen opens Level Forge. Paint blocks
straight out of the game's own tileset, drop in enemies, chests and items from
the campaign, then press PLAY to test the level in place with the real mole. A
health bar in the bottom-left tracks the mole's hearts for the duration of the
test, and is gone again once you return to editing with ESC.

The palette switches between three tabs. BLOCKS is every solid tile in the
game's tileset. ENEMIES holds the campaign's creatures. ITEMS holds a Chest,
which rolls its own loot exactly like the ones in the campaign, the four items
the merchant actually stocks -- Drill, Bomb, Ice Bomb and Holy Water -- and the
four weapons: Shovel, Golden Shovel, Pickaxe and Wizard Staff. An item is placed
as a floating pickup that hovers where you put it until the mole walks into it;
a weapon is placed as a pickup that hands the weapon over, and puts it in hand,
the moment the mole touches it. A weapon the player already owns is left lying
there. Whatever a playtest changes -- dug tiles, opened chests, collected items,
weapons found in the preview, coins a previewed enemy dropped -- is put back when
you stop.

LEFT CLICK: Paint the selected block, or place the selected enemy, chest or item
RIGHT CLICK: Erase a block, enemy, chest or item
MIDDLE MOUSE DRAG / WASD: Pan the view
MOUSE WHEEL: Zoom
CTRL+Z / CTRL+Y: Undo / redo
G: Toggle the grid

The WORLD panel on the right sets the level's look. Pick one of the three
parallax backdrops (Teal, Purple, Red), then drag the VIGNETTE slider to choose
how hard the filter bites: 0% leaves the screen clean, 100% blacks the corners
out completely. Both settings are previewed live and saved with the level.

Levels are saved under the game's user data folder as small JSON files, and the
editor autosaves a working copy after every edit, so a playtest that ends in a
game over never costs you your work.

ART AND VISUAL ASSETS WERE MADE BY BRYAN TANG

Programming, level design, writing: Nimansh Chauhan

Programming, level design, VFX, abilities: George Sun

Programming, VFX, SFX, game design: Javis Tsai

Art, programming, game design: Bryan Tang
