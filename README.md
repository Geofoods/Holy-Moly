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
test, and the campaign hotbar sits along the bottom edge so you can see what an
authored pickup looks like once it is collected. Both are gone again once you
return to editing with ESC, and the hotbar's contents are handed back exactly as
they were.

The palette switches between three tabs. BLOCKS is every solid tile in the
game's tileset. ENEMIES holds the campaign's creatures. ITEMS holds a Portal,
which is the level's way out: drop one wherever the level should end and, in a
playtest, the mole walking into it finishes the level -- the run stops with a
LEVEL COMPLETE banner and the editor comes back. A portal the mole is already
standing on when the test starts (because the start marker was moved onto it) is
ignored until the mole steps out and back in. The same tab holds a Chest, which
rolls its own loot exactly like the ones in the campaign, and the four items the
merchant actually stocks -- Drill, Bomb, Ice Bomb and Holy Water -- each placed as
a floating pickup that hovers where you put it until the mole walks into it.
Weapons are not on the shelf: they are the shop's business, earned by purchase
rather than found in a level. Whatever a playtest changes -- dug tiles, opened
chests, collected items, coins a previewed enemy dropped -- is put back when you
stop.

A Respawn Station is a checkpoint. Stand beside it in a playtest, press E to bank
it, and the pad lights up; dying after that puts the mole back on the pad, healed,
instead of ending the test. Falling into the pit under the level counts as a
death for this, and with no station banked the mole comes back to the start
marker. The checkpoint belongs to the playtest alone: it is never written into
the campaign's save, so setting one while testing a level cannot move the
checkpoint of the level the player is really playing. A station dropped into a
campaign level still banks into Progress exactly as before.

Goblin Gilbert is his stall. In a playtest the mole can walk up, press E, and
browse his stock, paying with the coins it has picked up in that same test.
Everything it buys, sells or spends is handed back when the test ends.

RECT FILL, or the R key, turns a drag into a filled rectangle: press at one
corner, drag to the opposite one and let go, and every cell between is painted at
once. It is how a floor or a wall goes down without a board of single clicks, and
the outline previews the rectangle while you drag. A drag that never moves is a
plain one-block click.

The same drag clears a rectangle, and the preview turns red to say so. With the
ERASE tool selected it sweeps the blocks away, and a right-button drag does it
whatever tool is selected, which is how a hole gets carved out. A sweep takes
blocks only: enemies, chests, items, the portal, the station and the merchant keep
coming out one at a time, so a rectangle cannot empty the level of its contents by
accident, and a click that never moved erases the single thing under the cursor
exactly as it always has.

LEFT CLICK: Paint the selected block, or place the selected enemy, portal, chest, station, merchant or item
RIGHT CLICK: Erase a block, enemy, portal, chest, station, merchant or item; with rectangle filling on, drag to clear the blocks in a rectangle
MIDDLE MOUSE DRAG / WASD: Pan the view
MOUSE WHEEL: Zoom
R: Toggle rectangle filling
CTRL+Z / CTRL+Y: Undo / redo
G: Toggle the grid

The WORLD panel on the right sets the level's look. Pick one of the three
parallax backdrops (Teal, Purple, Red), then drag the VIGNETTE slider to choose
how hard the filter bites: 0% leaves the screen clean, 100% blacks the corners
out completely. Both settings are previewed live and saved with the level.

Levels are saved under the game's user data folder as small JSON files, and the
editor autosaves a working copy after every edit, so a playtest never costs you
your work. EXIT saves the level and leaves through the same circle wipe the
campaign's own scenes use, so the editor reads as part of the game rather than a
detour.

ART AND VISUAL ASSETS WERE MADE BY BRYAN TANG

Programming, level design, writing: Nimansh Chauhan

Programming, level design, VFX, abilities: George Sun

Programming, VFX, SFX, game design: Javis Tsai

Art, programming, game design: Bryan Tang
