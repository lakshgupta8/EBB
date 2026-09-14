# EBB

Top-down action roguelite. Keep the tide. See [DESIGN.md](DESIGN.md).

## Requirements
- Godot 4.7.2 (`winget install GodotEngine.GodotEngine`)
- Python 3 + Pillow + numpy/scipy (asset generation only)

## Commands
| What | Command |
|---|---|
| Run the game | `.\tools\run.ps1` (title screen; `.\tools\run.ps1 src/hub/hub.tscn` skips it) |
| Build the Windows .exe | `.\tools\export.ps1` (fetches the 4.7.2 export templates once, ~1 GB) -> `dist\EBB.exe` |
| Build the installer | `.\tools\installer.ps1` (builds the exe first; fetches Inno Setup once) -> `dist\EBB-Setup-<version>.exe`. See [Installing](#installing) |
| Balance table | `.\tools\balance.ps1 [-Seeds 3] [-Tiers 0,4,8] [-Fast 4]`: the bot plays every weapon at each spring tide on several seeds, writes `tools/balance.csv` and the pace the daily board uses (`data/par.json`). It plays a fresh keeper with nothing bought, so it measures the hardest case. Red when the tier-0 average drops under eight rooms, a run ends before room four, a room wedges, or anything throws a script error |
| Content check | `.\tools\content.ps1`: every sound, loop, sprite, line and room type the game asks for against what is on disk |
| Room editor | `.\tools\edit_room.ps1 [-Room data/rooms/biome1/flats_01.txt]`: paint a template, watch the room rebuild, save it back |
| Jump to a biome / its boss | `.\tools\run.ps1 -- --biome=1` (streets), `--biome=2` (hall), add `--boss` |
| Run tests (headless) | `.\tools\test.ps1` |
| Bot playtest (headless) | `.\tools\sim.ps1 -Ticks 40000 -Seed 5 -Weapon harpoon [-Fresh]` (gaff, net, harpoon, lantern, bell, line); `tests/sim_run.tscn -- --take-wet --fish --tier=N --mode=daily --fast=4` (`--fast` runs the night up to eight times faster) |
| Replay a night | `.\tools\run.ps1 src/run/run.tscn -- --replay` (the newest) or `--replay=user://replays/replay_<seed>_<when>.json` |
| Regenerate sprites / rooms / audio | `python tools\gen_sprites.py --preview`, `python tools\gen_rooms.py`, `python tools\gen_audio.py` |
| Open Godot editor | `.\tools\editor.ps1` |

## Installing
`.\tools\installer.ps1` builds the game and wraps it in one file to hand over or
double-click: `dist\EBB-Setup-<version>.exe`. Nobody needs Godot or admin rights to run it.

What it puts on the machine, and so what the uninstaller takes back off:

| Where | What |
|---|---|
| the folder you pick (default `%LOCALAPPDATA%\Programs\EBB`) | `EBB.exe`, the whole game, and `unins000.exe` beside it |
| Desktop | `EBB` shortcut, ticked by default on the last page |
| Start menu | `EBB` and `Uninstall EBB` |
| Apps & features | an `EBB <version>` entry |

- **Where it lands.** The folder page comes up on a first install, so the game can go on
  whatever drive has room (`D:\Games\EBB`, say). No admin prompt: it installs for you.
- **Updating.** Build a new installer and run it. It recognises the old install by its ID,
  keeps the folder the last one chose, skips the folder question and writes over the game.
  If EBB is running it offers to close it. Shortcuts and saves survive.
- **Uninstalling.** `unins000.exe` next to the game, the Start menu entry, or Apps &
  features: any of the three, same uninstaller. It removes the files, the shortcuts, the
  registry entry and the folder.
- **Saves.** Keepers, settings and replays live in `%APPDATA%\Godot\app_userdata\EBB`,
  which the installer never wrote, so the uninstaller asks before deleting them and keeps
  them if you just press Enter. Reinstalling later finds them again.
- **The version** on the setup file, in the exe's file properties, in Apps & features and
  on the title screen is one number: `Game.VERSION` in `src/core/game.gd`. Raise it there
  before building a release.
- Tools fetched once, both per-user and silent: Godot's export templates (~1 GB) and
  [Inno Setup](https://jrsoftware.org/isinfo.php), which compiles `installer/ebb.iss`.
  `.\tools\installer.ps1 -SelfTest` installs to a temp folder and uninstalls again to prove
  both halves still work; it skips itself if EBB is already installed, since the test and a
  real install share one entry in Apps & features.

## Controls
| Input | Action |
|---|---|
| WASD / mouse | move / aim |
| LMB | attack (weapon combo; hold to keep going) |
| LMB hold (gaff) | keep holding to charge; when the hook rings, release for a heavy sweep that cracks shells (double damage for 3 s). Release early: nothing happens |
| Space, then LMB | lunge out of the dash |
| Space through an attack | riptide: slow-mo, dash refunded, next hit crits |
| RMB | weapon special: hook throw (gaff) or net throw (knife) |
| Q | lantern flare when the glow meter is full (hits charge it): stuns and damages everything nearby |
| R | the active tidemark in hand (one per family at altars: Salt Storm, Breakwater, Keeper's Step, Slack Call); the HUD shows its cooldown |
| F | eat the first fish in the bag (Nessa sells them: heal, a shield, a held tide, more health) |
| L | the Keeper's Log: milestones, Fen's shells, Nessa's board |
| E | interact (fountains, chests, cages, people, results screen; let the Choir finish when its note falters) |
| Esc / F11 | pause / fullscreen toggle. The pause menu has Codex [C], Settings [S], Rest here [R], Give up [Q] / Back to the title [T], Quit game [X] |
| R (paused) | rest: once a room is cleared and its doors are open, the night is saved and you go back up. The shore continues it next time, once; the tide, your health, salt and tidemarks are exactly as you left them |
| C | the codex: the drowned, tidemarks, people and places you have met |
| 1-9 or click | pick in any menu; arrows / WASD move a highlight, Enter picks it; E / Esc / right-click leaves |

Every one of these can be moved: Settings -> Play -> Controls and bindings. Pick a row, press
the key, mouse button or pad button you want. Whatever already held that input takes the one
you just replaced, so a swap leaves both with a key, and every prompt in the game says the key
you actually use. Esc always backs out of a menu and cannot be taken. The sticks and triggers
stay as they are.

### Gamepad
Left stick moves, right stick aims (tilt further to throw further; without it you aim where you walk).
A dash, X or right trigger attack, Y or left trigger special, LB flare, B use / talk / leave, Start pause,
Back codex. Menus: d-pad or stick to highlight, A picks, B leaves. Prompts switch to pad buttons the
moment a pad is used.

### Settings
From the pause menu or the title, on two pages ([Tab] turns them). Saved to `user://settings.json`,
which belongs to the machine, not to a keeper.

**Screen and sound**: master / music / sound volume, screen shake (off, low, full), screen flashes,
fullscreen, HUD size and text size (normal, large, largest), and reduced motion, which takes away
shake, flashes, slow time and the coloured pulses at the edge of the screen.

**Play**: dialogue speed, skip dialogue seen before, hints, the colour of water (sea, amber for
colourblind eyes, or high contrast), three assists, the ghost of your last night on this seed, and
the controls page.

**Assists** are a trade, not a cheat. The tide can rise at three quarters or half speed, damage taken
can be cut the same way, and aim help leans your aim toward what is nearest. Each one takes a bite out
of the pearls the night pays (the settings page and the results card both say how much), and a night
played with assists is marked on the daily board.

### Keepers (save slots)
Three of them, from the title. Each row says what the slot holds before you pick it: the night it is
on, wins, pearls, who is home, whether a night waits at the shore. The one in use can be wiped, and
wiping asks twice. An old single-slot profile is slot 1, untouched.

Knocking an enemy into a wall deals bonus damage. Enemies flash white and ring right
before they strike: dash on the flash for a riptide.

## Weapons (M4)
| Weapon | LMB | RMB |
|---|---|---|
| Gaff Hook (start) | 3-hit combo, third hit pulls; hold until it rings, then release for a heavy sweep | throw: light enemies are dragged to you, heavy ones drag you to them |
| Net & Knife (Bram's gift) | four fast stabs, the fourth cuts deep and bleeds; you stay mobile | throw a net at the cursor: everything under it is rooted for 2 s and takes +25% |
| Harpoon Gun (25 pearls) | piercing bolts, three then a reload; hold to keep firing | tether an enemy: every dash you make drags it along; bosses barely move |
| Storm Lantern (40 pearls) | wide quick arcs of light; everything hit is LIT (+30% damage from anything) and charges the flare fast | beacon: a pool of light at the cursor that lits and slows what stands in it |
| Keeper's Bell (55 pearls, M6c) | a wide swing, then an overhead slam whose ring stuns what it reaches | toll: ring the bell; for a moment nothing hurts you, everything near staggers, and whatever strikes you while it rings is PARRIED (stunned 2 s, you heal) |
| Line & Sinker (45 pearls, M6c) | three cracks of the line out to nearly three tiles; the third hauls what it catches to you | sinker: throw the weight to the cursor; it hits everything under it and weighs them down (slow) |

**Aspects (M6c).** Every weapon has two aspects at Bram's forge, bought once for 4 echo shards each
and switched freely after. Shards come from freeing an echo (3), each biome's named
elite (the Netted, the Bosun, the Choir, the Echo of Maren) and every boss (1 each). A weapon's aspect changes one thing about it: Maren's Gaff
charges faster and cracks bosses, the Cartographer's Net is wider, the Bosun's Gun holds five, and
so on. The hub shows the aspect in hand.

Pick and forge weapons at Bram's forge on Marrow Rock. The HUD shows the harpoon's ammo next to the special bar.

## The night (M4)
Hub (lighthouse) -> The Flats (10 rooms + The Wreck) -> The Sunken Harbour (9 rooms + The
Chainmother) -> The Drowned Streets (11 rooms + The Bell of Saltmere) -> The Deep Hall (9 rooms +
The Ebb), with slack water after every boss.
Beating the Ebb wins the night and brings Maren home to the lighthouse, where she holds the endings.
A night can be rested at any cleared room (pause, Rest here) and continued from the shore later.

Halfway down every biome the second door is marked WET: the same fight, already under water,
with the drowned mixed in, half again the salt, and a pearl for clearing it. Three room kinds
joined the graph in M6b: the **Challenge** (no way out for 45 s while the floor floods and four
waves come; two chests when the tide turns), the **Vault** (a locked strongroom: elites drop
keys, and a key buys five pearls, salt and a tidemark pick) and the **Dive** (deep water from
the door, an altar with something from the Deep on a dry island, a chest on another).
Elites now carry an affix: Salt-crusted (takes less), Lit (fast, glows), Anchored (cannot be
moved; its hits drag you in) or Hollow (splits in two when it dies).
Bot check of the same: `.\tools\sim.ps1 -RestAt 3` rests at depth 3, resumes, and compares every field.

## How the night talks to you
Everything a run says goes through `src/ui/announcer.gd`, in four voices that never overlap:
- **Cards** (top, upper case on a dark band): the name of a place, a boss, a turn of the night,
  with one plain line under it saying what it means for you ("Ten rooms down, then the Wreck. The
  water follows you in."). Bosses get letterbox bars, a breath of slow time and a bigger card; the
  boss breaking gets a flash and the same.
- **Toasts** (under the cards, small): what just happened. A mark taken (name and what it does), a
  journal page, the doors opening, the water crossing a mark on the staff.
- **Whispers** (bottom strip): the lantern's lines, typed out. Lore only.
- **Hints** (small warm pill under the HUD, top left): plain words about how a thing works, the first time you meet
  it, once per profile: moving, the goal, salt, pearls, the tide, altars, the merchant, fountains,
  forks, cages, challenges, vaults, dives, bosses, elites, low health, the flare, a riptide, keys.
  Off in Settings if you know it all.

The HUD names its bars (hp, dash, special, lantern, marks, salt, pearls), the tide staff says in a
word how high the water is (out, pools, flooded, deep) and flashes when it crosses a mark, the edge
of the screen pulses blue with it and beats red when you are nearly out. Tidemark cards say what they do in a sentence.

## The other ways down (M8)
"The sea keeps time," Idris says. From the title, the second row:

| Way | What it is |
|---|---|
| Daily Night | one attempt a day on a seed made from the date, so every keeper plays the same night. The board keeps each one and draws your time against the bot's pace |
| Seeded Night | type a number or a phrase; the same seed is the same night, room for room, card for card |
| Keeper's Trial | the four bosses back to back on one tide that never slackens. Opens once the Ebb is broken |
| Neap Night | every altar is bare stone with a chest left on it: no tidemarks all night, and pearls pay double. Opens after a win |
| Riptide | the water rises three times as fast, and it still counts for the spring-tide ladder. Opens after a win |

The same menu keeps a **history** of the last fifty nights: date, way down, weapon, seed, how far you
got, how many marks you held, how long it took and how it ended.

Every night writes its inputs to `user://replays/` (the newest ten). Playing one back is
`--replay`, which is how a bug travels: send the file. The keeper from the last night on the same
seed walks that night again beside you, faint, as a ghost.

## Story (M5)
- **The lantern whispers.** One-time lines during a run, at the first night, the first cage, each
  boss and each biome, and on the results card the first time you die or are taken. They tell the
  truth in layers. Lines live in `src/story/story.gd`, with everything anyone says at the hub.
  In a run they are typed out on a strip at the bottom, tagged with who is speaking, and they
  never carry instructions: those come as hints (below).
- **Endings.** Talk to Maren after the Ebb falls. *Keep the tide* is always open. *Break the tide*
  needs Bram, Wren and the Cartographer on the rock. *Walk out* appears once everyone is home and
  opens after three nights won. Each plays out over black with the sea rising or falling behind the
  words, is remembered on the profile, and can be chosen again; the people on the rock change what
  they say afterwards.
- **Codex.** C, or from the pause menu. Enemies fill in when first seen, tidemarks when first offered,
  people as they come home, places as you reach them. Every entry has a line of lore.
- **Fen** stands on the rock too: the village kid, only ever has something to say.

To watch an ending without earning it: `.	ools
un.ps1 src/hub/hub.tscn -- --screenshot --sim-save --ending=break`
(the `--sim-save` profile, never yours).

- The tide meter on the right rises with time and every room; low ground floods first, then the
  rest. Shallow water slows you, deep water hurts. It falls back to slack water after a boss.
- Door signboards show what is behind each exit: combat, elite, fountain, chest, merchant, altar,
  echo (a cage), boss.
- **Echo rooms** hold one of the drowned in a cage. Clear the guards, open the cage with E, and they
  go ahead of you to the lighthouse. Rescues are kept even if the run ends.
- Dying keeps pearls; being taken by the tide also converts half your salt to pearls.

### Who you can bring back
| Echo | Found | At the lighthouse |
|---|---|---|
| Bram the Drowned | The Flats, an echo room | forge: choose your weapon; aspects |
| Pell the Diver | The Sunken Harbour, an echo room | salt-glass; a word about the deep |
| Sister Wren | The Drowned Streets | bless a tidemark family: every altar offers one from it |
| The Cartographer | The Drowned Streets (after Wren) | chart a room: fountain, chest or merchant guaranteed two rooms into every biome |
| The Choir | The Drowned Streets: bring the named elite to a quarter health and press E when its note falters | hymns; the hub music changes |
| Keeper Aldous | The Deep Hall, an echo room | reads his journal pages; knows the way out |
| Maren | under the Ebb | the endings: keep, break, or walk out |

Break the tide needs five echoes home (Bram, Wren and the Cartographer among them); Walk out needs all seven.

## The village (M7)
- **Nessa the Fisher** comes down to the rock after two nights. Her board holds three **contracts** a
  night (36 in all: kill counts, reach a room untouched, bosses, wet rooms, a night without the
  merchant...), judged when the night ends and paid in pearls, sometimes shards or a fish. She sells
  **fish**: smoked eel (heal 30), shell broth (absorb a hit), still fish (the tide holds 8 s), salt cod
  (+15 max health). Three fit in the bag; F eats the first.
- **Idris the Harbourmaster** arrives once the Chainmother has fallen. At the dock: **launch from the
  harbour** (the night starts past the flats, 15 pearls a night), four **keels** (one on the boat at a
  time: iron, salt, lamp, deep, each a trade), and the chest of **lanterns and coats** the Log and
  the village open.
- **Keeper Aldous's journal**: nine pages hidden in vaults (one each) and dive chests (half the time).
  Each is a fragment of what the lantern is. Aldous reads what you have found; with all nine he tells
  you the way out. Pages are kept even if the night is lost.
- **Gifts and affinity**: salt-glass (every dive chest) and shells (Fen's chain) are gifts. Give one
  to anyone on the rock and they talk (a short chain, typed out at the speed in Settings) and pay:
  pearls at the first level, shards at the second, a permanent perk at the third (Orla: +5 health,
  Bram: the lantern starts half charged, Aldous: +8% damage, Pell: deep water bites half as often,
  Idris: launching is free, Nessa: a fourth fish, and so on). Thirty-three chains in
  `data/dialog/affinity.json`; idle lines for the new people in `data/dialog/npcs.json`, both linted
  by the tests.
- **Fen's shells**: six small asks in order (past the second room, break the Wreck, the wet way,
  salt-glass, Wren home, win a night). Each hands over a shell and pearls.
- **The Keeper's Log** (L): forty milestones claimed the moment you step onto the rock; pearls, shards
  and lantern colours (cold, sea green, violet, white). Lantern posts light along the rock, one for
  every eight.
- **The Ledger** is twenty-five nodes in five branches (Keeper, Sea, Purse, Lantern, Memory); each
  node needs the one before it, the Lantern branch needs Bram home, Memory needs a win. Memory holds
  Long Memory (last night's first tidemark returns), Second Look (an altar reroll), Two Hands (a
  second active tidemark), Kept Count, Deep Memory.
- **Epilogues**: the rock keeps the shape of the last ending. Keep: Maren's lamp lit on the tower.
  Break: the lower village under water, a dock built by the Drowned. Walk: still sea, faint echoes,
  a quiet loop. Everyone has post-ending lines; another night continues in that state.
- **Codex** gains Weapons (with their aspects), Journal and Contracts tabs (1-7), and every enemy
  entry earns a second paragraph after twenty kills.
- **Wet forks are shortcuts**: the wet door's room counts for two, unless that would skip a cage.
- Settings: dialogue speed (slow, normal, fast, at once), skip dialogue seen before, hints (how things work).

Screenshots of any of it: `.\tools\run.ps1 src/hub/hub.tscn -- --screenshot --sim-save --nessa`
(`--idris --aldous --pell --choir --log --quests --contracts --gift --cosmetics --codex=5`), with
`python tools\sim_profile.py village|epilogue-break|epilogue-walk|keep|fresh` to shape the sim profile.

### Flats and Hall additions (M6e)
| Enemy | Tell | Answer |
|---|---|---|
| Tidewisp | hangs at a distance, swells, flash | a slow bead of cold light: walk out of it. Close on it and it runs |
| The Netted (flats elite) | net held over the head, flash | the net roots you where it lands: move, or dash to tear free |
| The Choir (streets elite) | arms up, mouth open, flash | a ring opens out of it and wakes every other drowned thing: be near it or far, not in the ring |
| Tallow (hall) | swells, flash | a pool of burning wax where you were standing; it burns for six seconds |

### Harbour enemies (M6a)
| Enemy | Tell | Answer |
|---|---|---|
| Mooring | keeps a chain's length off, the chain uncoils toward you, flash | sidestep the line; caught, you are dragged a step toward him |
| Barnacle Swarm | short scuttles, rises, flash | dash the bite; it splits into two small swarms when it dies |
| Deckhand | shield up, walks in; blade raised, flash | the shield turns front hits: hit him from behind, or wait for OPEN after the swing |
| The Bosun (elite) | a bigger Deckhand | same rules, more of it |
| The Chainmother (boss) | chain sweep (dash through it), orange rings (anchors fall there), chain to you (dash), barnacles off the hull | at half health she stirs: faster, two anchors, and the tide jumps |

### Streets enemies
Still Citizen (statue until you are close, then fast), Lamplighter (kindles the others; throws its
lantern when alone; kill first), Bell Ringer (long tell, shockwave, calls the drowned up out of
the water), Swimmer (fast in water, slow on stone). The Bell of Saltmere tolls a ring of sound,
swings, and peals three times; at half health the statues in the square wake.

### Hall enemies
Keeper's Shade (fights with a dark copy of whatever weapon you carry, then slips away), Anchor
(throws a chain from a way off: dash through it or be hauled in for the slam), Deep Maw (a mouth
in the floor; opens when you are near, hangs open and vulnerable after it bites). Elites here are
Echoes of Maren. The Ebb sends walls of water with one gap, hauls you in and slams, calls shades,
and rises twice.

## Music and art (M5)
Five procedural loops in `tools/gen_music.py` (hub, flats, streets, hall, boss), on their own bus.
The title screen, enemy bodies that squash and fade, and the keeper falling when the night ends
are the M5 polish pass; every sprite is still drawn by `tools/gen_sprites*.py`.

## Progression
- Tidemarks: 72 per-run boons in five families (salt = offence, brine = defence, current = mobility,
  deep = weird, echo = what the rescued lend you). Echo marks need their person freed, duos need a
  mark from each of two families in hand, legendaries only turn up past the fifth room. Defined in
  `src/tidemarks/tidemarks.gd`; they write into `Player.mods`.
- Spring tides (M6d): once the Ebb has fallen, Orla's Ledger grows a gauge ([T] or click). Eight
  tiers, each keeping the ones below: faster tide, crusted enemies, second-wind bosses, dry wells,
  salt tax, blind altars, drowned elites, the Ebb remembers. A win at tier n opens n+1. Pearls pay
  +15% per tier and a win pays echo shards. Bot: `tests/sim_run.tscn -- --tier=N`.
- Ledger: permanent tiers bought from Orla with pearls, 25 nodes in five branches. Defined in `src/hub/ledger.gd`.
- Save: `user://save.json`, version 2 (pearls, echo shards, ledger, story flags, weapons forged, aspects,
  blessing, chart, spring tide reached, a night rested at the shore, affinity, gifts, journal pages,
  contracts, the Log, kill counts, fish, keel, cosmetics, epilogue). Version 1 profiles migrate.

Sandbox arena for feel tuning: `.\tools\run.ps1 src/sandbox.tscn`

## Layout
See the Architecture section of DESIGN.md. Short version: `src/` is code and scenes,
`data/` is content, `assets/` is art and audio, `tests/` is headless tests, `tools/` is scripts.
Room templates are ASCII in `tools/gen_rooms*.py` (legend at the top); every open cell must be
reachable from the spawn, and the test suite checks it.
