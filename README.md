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
- Online level publishing and browsing
- Community Level Browser with likes and download counts
  
CONTROLS:

WASD/ARROW KEYS: Movement

1 2 3 4: Change between hotbar/inventory items

SPACE/UP ARROW: Jump/Walljump

SHIFT: Dig Dash/Groundpound

ESC: Pause Game

M: Map

LEFT CLICK: Attack/Use item held or interact with HUD

HOLD LEFT CLICK: Aim a throwable and preview its path; release to throw

QUIT: Close the game (downloadable version only; the browser version hides this button)

LEVEL BROWSER:

The LEVEL BROWSER button on the title screen lists every level published to the
community service. Each entry shows its author, description, likes and download
count, and NEWEST, MOST DOWNLOADED and MOST LIKED reorder the whole catalogue.
LIKE adds or removes your own like; the game remembers your choice per
installation, so one copy of the game counts once. EDIT downloads the level and
opens it in Level Forge for changing, while PLAY launches it as a normal game
level: the campaign HUD, pause menu and game over screen are all there, and the
exit portal returns you to the browser when you finish. Community runs borrow
their authored weapons and music for that run only, use their own checkpoint,
and never overwrite campaign progress, shop unlocks or the level you were
building in Level Forge.

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
rather than found in a level. The WORLD panel's PLAYER WEAPONS button can set
which weapons a level unlocks for the player, or leave their own shop unlocks
alone. Whatever a playtest changes -- dug tiles, opened chests, collected items,
coins a previewed enemy dropped, borrowed weapons -- is put back when you stop.

A Respawn Station is a checkpoint. Stand beside it in a playtest, press E to bank
it, and the pad lights up; dying after that puts the mole back on the pad, healed,
instead of ending the test. Falling into the pit under the level counts as a
death for this, and with no station banked the mole comes back to the start
marker. The checkpoint belongs to the playtest alone: it is never written into
the campaign's save, so setting one while testing a level cannot move the
checkpoint of the level the player is really playing. A station dropped into a
campaign level still banks into Progress exactly as before.

RECT FILL, or the R key, turns a drag into a filled rectangle: press at one
corner, drag to the opposite one and let go, and every cell between is painted at
once. It is how a floor or a wall goes down without a board of single clicks, and
the outline previews the rectangle while you drag. A drag that never moves is a
plain one-block click.

The same drag clears a rectangle, and the preview turns red to say so. With the
ERASE tool selected it sweeps the blocks away, and a right-button drag does it
whatever tool is selected, which is how a hole gets carved out. A sweep takes
blocks only: enemies, chests, items, the portal and the station keep coming out
one at a time, so a rectangle cannot empty the level of its contents by
accident, and a click that never moved erases the single thing under the cursor
exactly as it always has.

LEFT CLICK: Paint the selected block, or place the selected enemy, portal, chest, station or item
RIGHT CLICK: Erase a block, enemy, portal, chest, station or item; with rectangle filling on, drag to clear the blocks in a rectangle
MIDDLE MOUSE DRAG / WASD: Pan the view
MOUSE WHEEL: Zoom
R: Toggle rectangle filling
CTRL+Z / CTRL+Y: Undo / redo
G: Toggle the grid

The WORLD panel on the right sets the level's look, sound and starting weapons.
Pick one of the three parallax backdrops (Teal, Purple, Red), then drag the
VIGNETTE slider to choose how hard the filter bites: 0% leaves the screen clean,
100% blacks the corners out completely. The FIREFLIES button turns the drifting
fireflies on or off; they preview live around the editor camera and follow the
mole during a playtest. The MUSIC button opens a panel of the campaign's
background tracks -- Grotto, Mole Village, Slime Valley, The Mines, Corrupted
Heart, Sealed Vessel and The Arena. Picking one auditions it immediately, and it
loops under the level in every playtest and when the level is published. Levels
saved before music selection existed use Grotto. All these settings are saved
with the level.

The WEAPONS button opens a panel where you choose which weapons the level
unlocks: Shovel (always), Golden Shovel, Pickaxe and Wizard Staff. Leave USE
PLAYER'S OWN UNLOCKS on to use each player's own shop progress, or turn it
off to give the level a fixed starting set. Every playtest starts with the
shovel in hand; the weapon slot lists the level's other unlocked weapons, so a
pickaxe or staff is one click away. The choice is saved with the level and
applies to playtests, so it can be tested exactly as a player will get it.

Levels are saved under the game's user data folder as small JSON files, and the
editor autosaves a working copy after every edit, so a playtest never costs you
your work. EXIT saves the level and leaves through the same circle wipe the
campaign's own scenes use, so the editor reads as part of the game rather than a
detour.

ONLINE LEVELS:

The ONLINE button opens the community panel. PUBLISH uploads the level currently
open in the editor with its name, author and a short description. BROWSE lists
everything published to the same server, including each level's likes and
downloads; LIKE uses the same installation-wide like as the title-screen Level
Browser, and LOAD downloads a level into user://levels and opens it in the
editor, ready for PLAY or SAVE.

The panel always talks to the hosted service at
https://holy-moley-levels.onrender.com. That address is fixed in
scripts/level_share.gd, and there is no server field in the editor. For local
testing, temporarily change SERVICE_URL there to http://127.0.0.1:8787 and run:

python server/level_server.py --port 8787 --data-dir server/data

The browser build needs the service to be served over HTTPS as well, since a page
cannot call an http:// address.

The server stores everything in server/data/levels.json by default, or in a free
Upstash Redis database when its REST URL and token are configured. It enables
CORS for the Web export, caps uploads at 1 MB, and rejects malformed level JSON.
It is deliberately small and has no accounts or moderation, so a public
deployment should add those or be treated as a community service for a game jam.
A free Render + Upstash deployment is preconfigured in render.yaml; see
server/README.md for the Render, Docker and other deployment notes.

ART AND VISUAL ASSETS WERE MADE BY BRYAN TANG

Programming, level design, writing: Nimansh Chauhan

Programming, level design, VFX, abilities: George Sun

Programming, VFX, SFX, game design: Javis Tsai

Art, programming, game design: Bryan Tang
