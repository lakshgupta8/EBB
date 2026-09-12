# EBB — Design Document (v0.1)

Working title: **EBB**
Genre: Top-down 2D action roguelite with a story hub and permanent progression
Platform: Windows (PC), keyboard+mouse first, gamepad later
Engine: Godot 4.x (GDScript), pixel art at 16px tiles, 640x360 internal resolution scaled up

---

## 1. The Pitch (one paragraph)

Every night the sea around Marrow Rock pulls back impossibly far and exposes the drowned city of Saltmere.
You are the new Tidekeeper. You have until the tide comes back. Descend through the ruins, fight what
lives in them, rescue the echoes of the drowned, and find out why the sea is leaving. When the water
catches you, you wake up at the lighthouse and the night begins again. Each night the sea goes out a
little further, you get a little stronger, and the story goes a little deeper.

### The hook that makes it different
**The tide is the clock.** Water rises during the run. It is not a fixed timer: it is a physical
water line that creeps up the level. Flooded tiles slow you, some enemies become dangerous only
underwater, some paths close, some open. Dawdling is not "you lose", it is "the run changes shape".
Death is not the only way a run ends: being caught by the tide ends it too, but keeps more of your loot.

---

## 2. Story

### Setting
Marrow Rock: a lighthouse island off a cold coast. One village of about forty people. A lighthouse
with a Tidekeeper who "keeps the tide", which everyone thinks is a ceremonial title.

Saltmere: a city that drowned in a single night three hundred years ago. The tide has never gone out far
enough to show it. Until now.

### Premise
The old Tidekeeper, Maren, walked into the exposed ruins one night and didn't come back. You are her
apprentice, Tam (player, silent-ish, gender never specified). The village elder hands you the keeper's
lantern and says the words nobody believed were real: "Keep the tide."

### The truth (revealed in layers)
1. **Layer 1 (early runs):** The keepers were never ceremonial. Every keeper has walked into Saltmere.
   The lantern is not for light. It is a tether: it is what lets you return when the tide takes you.
2. **Layer 2 (mid):** Saltmere didn't drown by accident. Its people asked the thing beneath the sea, the
   Ebb, to keep them safe forever. It did. It held them still, underwater, exactly as they were.
   The "echoes" you rescue are those people, still safe, still waiting.
3. **Layer 3 (late):** The tide going out is not an attack. It is the Ebb losing its grip because the
   keeper line is ending. Maren went down to renew the bargain and take Saltmere's place: a keeper stands
   at the bottom and is the anchor. Every keeper before her is still down there. Alive. Held.
4. **Layer 4 (endings):** Maren is at the bottom, mid-bargain, and the choice is yours.

### Endings
- **Keep the tide.** Take Maren's place. The village is safe. The cycle continues. Quiet, bittersweet.
- **Break the tide.** Shatter the lantern. Saltmere's echoes are released, the Ebb lets go, the sea comes
  back for good and Marrow Rock's lower village floods. The villagers you've built relationships with have
  to leave, but they leave free. Requires having rescued enough echoes (they help you break it).
- **Secret: Walk out.** Rescue every echo, including Maren. The ruins empty. Nobody anchors. The sea
  simply forgets. Hardest ending, needs full completion.

### Tone
Melancholy but warm. Dialog is short and dry. No text walls. NPCs at the hub talk in two to four lines
and remember what you did. Think Hades' cadence with a Celtic coastal fishing-village flavour instead of
Greek myth.

### Hub NPCs (unlocked over time)
| NPC | Who | Unlock | Function |
|---|---|---|---|
| Elder Orla | Village elder, blunt, guilty | start | Story dispenser, meta-upgrades (the "Ledger") |
| Fen | Village kid, thinks you're a hero | start | Flavour, small side quests (bring me a shell from depth 2) |
| Bram the Drowned | First echo you rescue, a Saltmere blacksmith | rescue in biome 1 | Weapon unlocks and weapon upgrades |
| Sister Wren | Echo, Saltmere priestess | rescue in biome 2 | Boon pool control (bless/ban a tidemark), codex |
| The Cartographer | Echo, nameless | rescue in biome 2 | Map fragments: reveal room layouts, guaranteed room types |
| Maren | Old keeper | end of biome 3 | Endings |

---

## 3. Core Gameplay

### Controls
- WASD: move
- Mouse: aim
- LMB: attack (weapon-specific combo)
- RMB: weapon special (cooldown)
- Space: dash (short i-frames, 3 charges regenerating)
- E: interact
- Q: use active tidemark (if any)
- Esc: pause

### Combat feel targets
- Movement speed ~ 6 tiles/sec, dash covers 3 tiles in 0.15s
- Attacks have anticipation (2-4 frames), hit (1-2 frames), recovery. Cancel recovery into dash.
- Hitstop 50-80ms on hit, screen shake scaled by damage, hit flash white, knockback.
- Enemies telegraph every attack with a visible windup. No unavoidable damage.

### Weapons (start with 1, unlock via Bram)
| Weapon | Style | LMB | RMB special |
|---|---|---|---|
| Gaff Hook | default, mid-range melee | 3-hit combo, third hit pulls enemies in | Throw and yank yourself to the hook (mobility + i-frames) |
| Net & Knife | close/control | fast stabs | Throw net: roots enemies in an area for 2s |
| Harpoon Gun | ranged, slow | piercing bolt, reload | Tethered harpoon: enemy is dragged along your dashes |
| Storm Lantern | magic-ish, area | lantern swing arcs of light, low damage | Flare: big burst, blinds, sets "lit" status enemies take bonus damage from |

### Tidemarks (boons, per-run)
Offered at altars (3 choices), earned from elites, bought at shops. ~40 at launch, grouped into families:
- **Salt** (offense): +damage, bleed on third hit, crit on enemies in water
- **Brine** (defense): +max HP, damage reduction while dashing, shield on room clear
- **Current** (mobility): extra dash charge, dash leaves damaging wake, faster in water
- **Deep** (weird): enemies die into healing bubbles, tide rises slower, tide damage heals instead
- **Echo** (synergy): unlocked by rescued NPCs, combine two families
Tidemarks have 3 rarities and a few "duo" combos when two families are both present.

### Resources
- **HP**: no regen, healed by fountains, some tidemarks, and shop.
- **Salt** (run currency): dropped by enemies, spent at shops. Lost on run end.
- **Pearls** (meta currency): from bosses, elites, chests, first-time room discoveries. Kept always.
  Spent at Orla's Ledger for permanent upgrades.
- **Echo shards** (meta): rare, from rescuing echoes and story milestones. Unlock NPC features.

### The Tide (the signature system)
- A global **tide level** rises through the run. It starts at 0 and rises at a base rate per second,
  plus a jump every time you enter a new room. Some tidemarks slow it. The lantern's "hold" ability
  (rare) pauses it briefly.
- Each room has a **flood profile**: a height map. When tide > tile height, that tile is water.
  - Shallow water: player and most enemies move at 70%.
  - Deep water: player takes chip damage per second, some enemies become fast and aggressive (Drowned
    become "Swimmers"), some enemies drown (land-based).
  - Some doors close when flooded. Some shortcut doors open only when flooded (you swim over a wall).
- When tide reaches the player's tile at deep depth and HP hits zero from chip damage, the run ends by
  **being taken**: you keep 100% of pearls and 50% of salt converts to pearls. Dying to an enemy keeps
  pearls only. So slow play is a gamble, not a punishment.
- Bosses are fought on a rising tide that is scripted: phase changes are triggered by water levels.

### Run structure
```
Lighthouse (hub)
  -> Biome 1: The Flats       (7-9 rooms + boss)   tidal flats, wrecks, crabs, gulls
  -> Biome 2: Drowned Streets (8-10 rooms + boss)  Saltmere's streets, the frozen citizens, the Ebb's servants
  -> Biome 3: The Deep Hall   (6-8 rooms + boss)   cathedral of the Ebb, keepers standing like statues
  -> Maren / ending
```
Room types: combat, elite, shop, altar (tidemark), fountain (heal), echo (rescue, story), treasure,
challenge (survive rising tide without a door), boss.
Layout: rooms are hand-authored templates (about 12-15 per biome) assembled into a graph with
2-3 branches. You see door icons before choosing, so builds are decisions.

### Enemies (launch set)
Biome 1: Shellback (slow tank), Gull (dive bomber), Wrack Crab (charger), Tidewisp (ranged, flees).
Elite: The Netted (drowned fisherman, throws nets).
Biome 2: Still Citizen (statue until you're close, then fast), Lamplighter (buffs others), Bell Ringer
(summons), Swimmer (only exists when flooded). Elite: The Choir.
Biome 3: Keeper's Shade (mirrors your weapon), Anchor (pulls you toward water), Deep Maw.
Elite: Echo of Maren.
Bosses: The Wreck (a ship that fights), The Bell of Saltmere, The Ebb (final).

---

## 4. Progression (three layers)

1. **Per run**: weapon choice, tidemarks, salt purchases. Builds are meaningfully different by room 5.
2. **Permanent (the Ledger)**: +HP tiers, 4th dash charge, starting salt, keep one tidemark between runs,
   reroll altars, extra weapon special charge, "the tide is kinder" (slower base rise). ~25 nodes.
3. **Story and world**: rescue echoes -> new NPCs at the hub -> new shops and systems -> dialog reveals
   the truth -> endings become available. Codex fills with every enemy, tidemark, and room discovered.
   The hub itself visibly changes: more lanterns lit, the Drowned build a small dock.

A run takes 20-30 minutes. First win expected around run 8-15. Full content 15-25 hours (M0-M5); section 8 plans the expansion to 40-60 hours.

---

## 5. Technical Design

### Stack
- **Godot 4.x** (latest stable), GDScript. Reasons: full 2D toolset (tilemaps, physics, particles,
  audio, UI), scenes are text files so everything can be built from code, headless CLI for tests,
  one-command Windows export. No editor-clicking required for the build to progress.
- **Git** for version control (repo initialised in this folder).
- **Python 3** (already installed) for asset generation scripts (placeholder sprite sheets, palette tools).
- **VS Code** + godot-tools extension for editing and debugging.
- **GdUnit4** or GUT for automated tests of pure logic (tide math, room graph generation, tidemark
  stacking, save/load).
- Art: start with programmatically generated placeholder pixel art so the game is playable from week one,
  then swap in CC0 packs (Kenney, 0x72 dungeon tileset) or hand-drawn art. Aseprite optional.
- Audio: CC0 SFX, jsfxr-style generated effects, CC0 music. Wired in late.

### Architecture
```
res://
  project.godot
  src/
    core/        Game (autoload state machine: Hub -> Run -> Results), EventBus, SaveManager, RNG (seeded)
    run/         RunState, TideSystem, RoomGraph (generation), RoomLoader, LootTables
    player/      Player (CharacterBody2D), PlayerStateMachine, Weapons/ (one script per weapon), Dash
    enemies/     EnemyBase, per-enemy scripts, EnemyStateMachine, Spawner
    combat/      Hitbox, Hurtbox, DamageInfo, StatusEffects, Hitstop, Knockback
    tidemarks/   Tidemark resource type, registry, per-tidemark effects (data-driven .tres files)
    hub/         Hub scene, NPC, DialogRunner, Ledger (meta upgrades), Codex
    ui/          HUD, TideMeter, Pause, AltarChoice, Shop, RunResults, Settings
    world/       Room template scenes, FloodMap, Door, Props
  data/          tidemarks/*.tres, enemies/*.tres, weapons/*.tres, dialog/*.json, ledger.json
  assets/        sprites/, tiles/, audio/, fonts/
  tests/         unit tests
  tools/         Python asset generators
```
Principles:
- Data-driven content: enemies, weapons, tidemarks, dialog are resources/JSON, not hardcoded.
- Deterministic runs from a seed for reproducing bugs.
- Event bus for decoupling (enemy_died, room_cleared, tide_changed, damage_dealt).
- Save is JSON in user://, versioned, with migration stub.
- Fixed internal resolution 640x360, integer-scaled, pixel snap on.

### Tide implementation
Each room's TileMap has a "height" custom data layer (0-3). TideSystem broadcasts tide_level (float).
A FloodRenderer draws water over tiles with height < tide using a shader with animated edges.
Physics: an Area2D grid per height band toggles as tide crosses thresholds; bodies inside get a
"wet" flag that movement and enemy AI read. Cheap, no per-frame per-tile checks.

---

## 6. Milestones

| # | Milestone | Deliverable | Done when |
|---|---|---|---|
| M0 | Tooling | Godot, git repo, project skeleton, run script, one test passing | Headless test run is green; game window opens with a coloured square |
| M1 | Feel | Player move/dash/gaff hook, one test room, Shellback + Gull, hitstop/shake/knockback | You say "this feels good to control" |
| M2 | Loop | Room graph gen, doors, room types, tide system with flooding, run end (death and taken), results screen, return to hub | A full biome-1 run start to finish is playable |
| M3 | Progression | Hub scene, Orla + Ledger, pearls, save/load, altar + 12 tidemarks, shop | Runs feel different and the meta loop pulls you back (done) |
| M4 | Content | Biomes 2-3 (Drowned Streets, Deep Hall), 11 enemies, 3 bosses (Wreck, Bell, Ebb), 4 weapons, 42 tidemarks, echo rescues (Bram, Wren, Cartographer, Maren) with hub functions | Game is winnable (done: the Ebb falls and Maren comes home) |
| M5 | Story and polish | Full dialog, endings, codex, audio, real art pass, settings, gamepad, Windows export .exe | Shippable build (done: dialog for all six NPCs, lantern whispers, three endings, codex, five music loops, title screen, death animations, settings, gamepad, `tools/export.ps1`) |
| M6 | Spring Tides | Sunken Harbour biome, forks, challenge/vault/dive rooms, elite affixes, +8 enemies, +2 weapons, 12 aspects, 72 tidemarks, eight-tier tide ladder | A bot run takes 20 min and the ladder holds eight wins (see section 8). M6a done: the Harbour (tiles, decor, 11 rooms, Mooring, Barnacle Swarm, Deckhand, the Bosun, the Chainmother, music, whispers, codex), biomes 10/9/11/9 rooms, tide step scaled per biome |
| M7 | The Village | Four NPCs, seven echoes, journals, affinity dialog, quests and contracts, epilogues, 25-node Ledger, Keeper's Log | Something new in the hub after every one of the first 30 runs |
| M8 | Modes, options, tools | Daily Night, trials, seeds and history, rebinding, assists, save slots, balance harness, room editor | A fresh player can rebind, pick a slot and play a daily; balance table green |

Each milestone ends with you playtesting and giving notes; nothing is "done" until it plays right.

---

## 7. Open decisions (defaults chosen, overturn if you disagree)

1. Engine: Godot 4 + GDScript. Alternative is MonoGame (C#) if you strongly prefer pure code and .NET.
2. Perspective: top-down (Hades style), not side-scroller. Top-down makes the flooding readable.
3. Art: pixel art 16px, placeholder-first. If you'd rather hand-drawn or asset-pack from day one, say so.
4. Difficulty: no difficulty select at launch; the Ledger and tidemarks are the difficulty curve.
5. Name: EBB is a working title.

---

## 8. Expansion plan: the Long Night (M6-M8)

Goal: about **6 hours** of content for a skilled player who wastes no runs (today: about 1 hour),
40-60 hours for a normal player. Three modules, each shippable on its own, each touching story,
progression, gameplay, tools and options. Order: M6, then M7, then M8.

### Where the hours come from (skilled player, no wasted runs)
| Content | Today | After M6-M8 |
|---|---|---|
| One winning run | 12 min | 22 min (four biomes, 10/9/11/9 rooms, forks, challenge rooms) |
| Three endings | 1 h (4-5 runs) | 2 h (5-6 runs: seven echoes to bring home, nine journals) |
| Spring Tides ladder | - | 2.5 h (eight tiers, one win each, tiers cannot be skipped) |
| Weapon aspects, contracts, quests, Keeper's Log | - | 1 h of runs that do not overlap the above, 20 min in the hub |
| **Total** | **1 h** | **5.5-6.5 h** |

### M6 - Spring Tides (the run)
**Gameplay**
- New biome between the Flats and the Streets: **The Sunken Harbour** (9 rooms + boss). Where
  Saltmere's ships tried to leave. Hulls, chains, cranes, a drydock that floods in stages.
  Enemies: Mooring (chain lash, pulls you into water), Barnacle Swarm (splits), Deckhand (shield
  with a parry window), Pilot Gull. Elite: The Bosun (rallies). Boss: **The Chainmother**.
- Biome lengths 8/9/7 become 10/9/11/9 (Flats, Harbour, Streets, Hall).
- **Forks**: at mid-depth every biome offers a wet path (already flooded: swimmers, shortcuts,
  better loot) or a dry path. Door icons say which.
- Templates 14/13/11 become 20 per biome plus six flood variants each (same room, different heights).
- New room types: **Challenge** (survive 45 s of rising tide, no doors, chest), **Vault** (locked
  treasure, key dropped by the biome's named elite), **Dive** (deep water only, Deep family guaranteed).
- Elite affixes rolled at spawn: Salt-crusted (armour), Lit (fast), Anchored (pulls), Hollow (splits).
  One named elite per biome with a unique drop.
- Enemies +8 (four Harbour, one new per other biome, Swimmer variants).
- Weapons +2: **Keeper's Bell** (heavy hammer: slam waves, parry) and **Line & Sinker** (long whip:
  hook pulls, spin). **Aspects**: every weapon gets two aspects (Bram, paid in echo shards) that
  change the combo: 12 aspects.
- Tidemarks 42 become 72: five more per family, an **Echo** family (8, unlocked by NPCs), six duos
  (two families present), four legendaries, three **active** tidemarks on Q.
- **Spring Tides**: after the first win Orla offers a tide gauge before each run. Eight tiers, each a
  modifier (faster tide, crusted enemies, second-wind bosses, no fountains, salt tax, blind altars,
  drowned elites, the Ebb remembers). Tier n opens by winning at n-1. Rewards: pearl multiplier,
  shards, a whisper per tier, and at tier eight a fourth epilogue, **Riptide**.
- Bosses gain an extra phase from tier three.

**Story**: four Harbour whispers, the Chainmother explains why the ships never left, Bram has a line for every aspect.
**Progression**: echo shards (section 3) built for real: from cages, named elites and tide wins.
**Tools**: fork markers in gen_rooms, gen_sprites_m6 (Harbour tiles, 8 enemies, 2 weapons, aspect recolours), Harbour loop and a second boss loop in gen_music, a balance bot per weapon per tier writing `tools/balance.csv`.
**Options**: tier selector, door preview shows the path kind.
**Tests**: connectivity for 80 templates, fork graph, affix stacking, aspect combos, tier gating, bot wins at tier 0 and survives tier 4.
**Done when**: a bot run takes 20 minutes and the ladder holds eight wins.

### M7 - The Village (story and progression)
**Story**
- Four new NPCs: **Nessa the Fisher** (contracts, fish consumables), **Idris the Harbourmaster** (the
  dock: launch from biome two at a cost, keel modifiers, cosmetics), **The Choir** (the Streets elite,
  spared instead of killed: hymns, the hub music changes), **Keeper Aldous** (an old keeper's echo from
  the Hall: the keeper line, journals, aspects).
- Echoes 4 become 7: Bram, **Pell the Diver** (Harbour: Dive keys), Wren, the Cartographer, the Choir,
  Aldous, Maren. Break needs five home, Walk needs all seven.
- **Keeper journals**: nine pages hidden in vaults and dives, each a fragment of layer 3. All nine
  unlock Aldous's last dialog and the hint for Walk out.
- **Affinity**: gifts (salt-glass from dives, shells from Fen's chain) raise three levels per NPC.
  About 30 short dialog chains that remember what you did, one reward per level.
- **Quest log**: Fen's shell chain (six quests) and Nessa's contracts (about 30, three offered per run:
  kill X with Y, reach a depth untouched, finish under a tide level).
- **Epilogues**: every ending changes the hub for good (Keep: Maren's lamp lit, the keeper at the
  window; Break: the lower village flooded, a dock built by the Drowned; Walk: empty ruins, still sea).
  Every NPC has post-ending lines. "Another night" continues in that state and opens the ladder.

**Progression**
- Ledger 6 nodes become 25 in five branches (Keeper, Sea, Purse, Lantern, Memory) with prerequisites.
  Memory adds keep-one-tidemark, altar reroll, a second Q slot. Costs sized so completion is about
  12 wins of pearls for a skilled player and 40 for a normal one.
- **Keeper's Log**: 40 milestones with pearl, shard and cosmetic rewards (lantern colours, coats).
- Codex tabs for tidemarks, weapons, journals and contracts; enemy entries gain a second paragraph after 20 kills.
**Gameplay**: consumables from Nessa (heal, shield, tide pause), the hub visibly grows (lanterns, dock, Choir singing).
**Tools**: dialog moves to `data/dialog/*.json` with a lint test (length, duplicates), NPC portrait generator, contract table with a test that the bot can complete every contract.
**Options**: dialog speed, skip seen dialog, journal hints on or off.
**Tests**: affinity math, quest state machine, ledger prerequisites, epilogue state, save migration.
**Done when**: the hub has something new to do after every one of the first 30 runs.

### M8 - Modes, options, tools
**Modes**
- **Daily Night**: one seeded attempt per date, local scoreboard with the bot's ghost time as a bar.
- Custom seed and a run history (last 50: weapon, depth, tidemarks, time, cause of end).
- **Keeper's Trial** (four bosses on one rising tide), **Neap Night** (no tidemarks, big pearl reward),
  **Riptide** (tide at three times speed, counts for the ladder).
- Ghost of the last run on the same seed (optional, faint).
**Options**
- Full key and pad rebinding; assist sliders (tide speed, damage taken, aim assist) with a pearl
  multiplier so they are a trade rather than a cheat; colourblind water tints, HUD scale, text size,
  reduced motion; all strings in `data/strings.json` so a translation is a file.
- Three save slots on the title; replay a run from its seed and input log for bug reports.
**Tools**
- `tools/balance.ps1`: every weapon at every tier with the bot, reporting win rate, time and damage
  taken; fails if the tier-0 win rate drops under 80%.
- In-game room editor behind a dev flag: edit the ASCII template live, hot-reload, save back.
- `tools/content.ps1`: lists missing sprites, sounds and dialog against the content tables.
- Music: four more loops (Harbour, epilogues, title variation), stingers for rescues and boss phases, ambience layers per biome.
**Story**: Idris frames the modes ("the sea keeps time"); Log entries for each mode.
**Tests**: rebinding round trip, seed determinism (same seed, same graph and drops), mode gating, slot migration.
**Done when**: a fresh player can rebind, pick a slot and play a daily, and the balance table is green.
