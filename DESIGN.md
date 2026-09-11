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

A run takes 20-30 minutes. First win expected around run 8-15. Full content 15-25 hours.

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
| M3 | Progression | Hub scene, Orla + Ledger, pearls, save/load, altar + 12 tidemarks, shop, Bram + 2nd weapon | Runs feel different and the meta loop pulls you back |
| M4 | Content | Biomes 2-3, all enemies, 3 bosses, 4 weapons, 40 tidemarks, echo rescues, all NPCs | Game is winnable |
| M5 | Story and polish | Full dialog, endings, codex, audio, real art pass, settings, gamepad, Windows export .exe | Shippable build |

Each milestone ends with you playtesting and giving notes; nothing is "done" until it plays right.

---

## 7. Open decisions (defaults chosen, overturn if you disagree)

1. Engine: Godot 4 + GDScript. Alternative is MonoGame (C#) if you strongly prefer pure code and .NET.
2. Perspective: top-down (Hades style), not side-scroller. Top-down makes the flooding readable.
3. Art: pixel art 16px, placeholder-first. If you'd rather hand-drawn or asset-pack from day one, say so.
4. Difficulty: no difficulty select at launch; the Ledger and tidemarks are the difficulty curve.
5. Name: EBB is a working title.
