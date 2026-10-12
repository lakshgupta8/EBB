# EBB — Map redesign roadmap

Started 2026-10-05 from the user's request: "The maps are the most unattractive part of this game,
redesign all maps and make even more." Same contract as ART_ROADMAP.md: one stage per explicit
"Proceed to Stage X", a representative sample before mass production, STYLE.md stays the
specification, progress goes in ART_PROGRESS.md under a "Maps" heading.

## Why the maps look bad (diagnosis, from in-game shots of all four biomes, 2026-10-05)

1. **Every room is the same box.** All 79 templates are 40x23 tiles, exactly one screen, and the
   camera never moves. Nothing is off-screen, nothing is discovered, no room feels bigger or
   smaller than another.
2. **The floor is wallpaper.** About 800 cells of one tile with a one-in-five variant. At this
   size the floor texture *is* the picture, and it has no large-scale structure.
3. **Greybox geometry.** Pools, plinths and walls are axis-aligned rectangles, usually
   mirror-symmetric (four boxes, two pools, one ring). It reads as a test arena.
4. **Hard edges everywhere.** Sand meets water, floor meets dais, floor meets wall on a straight
   tile seam. No transition tiles: no wet sand, kerbs, rubble spill, moss creep, broken edges.
5. **No set pieces.** Nothing large is drawn. The decor is 16 px crumbs spread evenly, so it
   reads as noise, not as places.
6. **The world stops at the screen edge.** The rim wall is one tile, half of it under the HUD;
   the void and far scenery are barely visible.
7. **Biomes differ only in floor colour.** The Streets have no houses or alleys, the Harbour
   no ships or piers over water, the Hall no nave, columns or altar.
8. **Light is only Tam's lantern.** The room itself has no lit composition.
9. **Layouts repeat.** About 12 combat plans per biome, many on the same symmetric skeleton.

## Decisions taken by the user (2026-10-05): A1, B1 + B3, C1

Mixed room sizes with a following camera; a chunk generator with hand-authored signature rooms;
a fifth biome; autotiled terrain, material patches and set pieces. The options as offered:

**A. Room size and camera**
- A1. Mixed sizes with a following camera: one-screen rooms stay for shops, altars and small
  fights; combat rooms range up to about 2x2 screens (80x46 tiles), corridors and L-shapes
  allowed. Biggest visual gain; touches tide, water, void, atmosphere, bot and editor code.
- A2. Keep one-screen rooms, redesign inside the box. Cheapest and safest; problems 1 and 6
  stay partly unsolved.
- A3. Every room large and scrolling. Most "explorable", but slower runs and a balance re-pass.

**B. How "more maps" are made**
- B1. Hybrid generator: hand-authored chunks and set pieces (per biome) stitched by rules into
  rooms, plus hand-authored signature rooms. Hundreds of distinct rooms; every output is
  validated (walkable, doors reachable, flood profile, fair spawns).
- B2. Hand-author more templates: about 79 -> 140 (35 per biome). Full control, finite variety.
- B3. A new fifth biome as well as either of the above (e.g. the Reef or the Lighthouse Stair).

**C. How the ground is drawn**
- C1. Autotiled terrain (blob/Wang transitions for every edge type per biome) + noise-driven
  material patches + multi-tile set-piece sprites. Works with any generated layout.
- C2. Hand-painted backdrop per room. Best single images, but cannot follow a generator and is
  79+ paintings.

## Stages

| # | Stage | Output | Gate |
|---|---|---|---|
| 01 | Map audit and target (**done 2026-10-05**) | Contact sheet of all 79 rooms rendered in game; each scored on the nine problems; a MAPS section in STYLE.md (shape language, edge types, density, composition rules per biome) | User approves the target |
| 02 | Room scale and camera (**done 2026-10-05**) | Variable room size in the template format, camera follow with limits and look-ahead, tide/water/void/atmosphere/HUD freed from 640x368, editor and bot follow | A big test room plays cleanly, 96+ tests pass |
| 03 | Terrain transitions (**done 2026-10-05**) | Autotile sets for every edge in four biomes (floor/low, floor/raised, floor/wall, water shoreline), organic non-rectangular shapes allowed in templates | Sample sheet approved |
| 04 | Ground at large scale (**done 2026-10-05**) | Material patches by noise (wet sand streaks, tide pools, worn cobble paths, moss, basalt veins), large decals, decor clustered not sprinkled | Sample sheet approved |
| 05 | Set pieces (**done and approved 2026-10-05**: 32 pieces, eight a look) | 8-10 multi-tile pieces per biome with collision and light (Flats: wreck hull, rock arch, tidepool; Streets: house fronts, well, market stall, collapsed tower; Harbour: pier, moored boat, crane, warehouse; Hall: nave columns, altar, organ, keeper statues) | Sample sheet approved |
| 06 | One sample room per biome (**done and approved 2026-10-05**, "1": draw the second batch first) | Four rooms built with 02-05, shot in play | **User approves before any mass production** |
| 07 | World light (**done and approved 2026-10-05**) | Fixed light sources per biome (lamps, candles, glowing kelp, braziers) composing each room; Tam's lantern stays the warmest | Shots approved |
| 08 | Layout grammar (if B1) (**done and approved 2026-10-05**) | Chunk format, the stitcher, the validator, a seed-to-room preview tool | 200 generated rooms pass the validator |
| 09 | Redesign the 79 rooms (**done and approved 2026-10-05**, 200f31a, for the 58 fighting and reward rooms; the 21 signature rooms are Stage 12) | Every existing room rebuilt to the new standard (combat, elite, challenge, dive, vault, treasure) | Contact sheet approved |
| 10 | More rooms (**done and approved 2026-10-05**: five shapes in RoomGen, ten chunks a look, 20 saved rooms of the new shapes, half the fights generated in play) | New rooms to the agreed count (B1 chunk library or B2 templates), new shapes: corridors, L, ring, split-level, flooded | Contact sheet approved |
| 11 | Fifth biome (B3) (concept **chosen 2026-10-05**: the Reef, an alternate road to the Harbour, `docs/BIOME5_CONCEPT.md`; 11a tiles and palette approved; 11b the Reef in the game approved; 11c set pieces, decor and light approved; 11d grammar and chunks approved; 11e the current approved; 11f its 19 rooms approved, 11a-11f committed; 11g the reef road approved; 11h the reef's three drowned approved; 11i the Reefwarden approved; 11j the Tidewall approved; 11k Hale the Mason approved; 11l music and lantern lines approved; the Reef is whole, 11g-11l committed) | Concept, palette and tiles, then its chunks and set pieces through 03-08; enemies, boss, music and story hooks as their own sub-stages | Concept approved before any art |
| 12 | Signature rooms (12a the rules and a sample, the Flats merchant, approved; 12b the Flats' altar, fountain, echo and the Wreck's beach, approved; 12c the Harbour's five, approved; 12a-12c committed; 12d the Streets in progress) | Shop, altar, fountain, echo, the five boss arenas (the Reef's Tidewall too) and the hub as distinct places, 27 rooms, each with two exits | Shots approved |
| 13 | Integration and release | Balance bot over the new rooms, perf at 2x2 rooms, room editor, codex, tests, setup exe 1.4.0 | Tests pass, bot gate holds, installer built |
