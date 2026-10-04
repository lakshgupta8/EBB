# EBB — Map audit (map Stage 01, 2026-10-05)

All 79 room templates, rendered through the real `Room` builder with the run's night tint and
low ground flooded (`src/dev/room_sheet.tscn`), and measured from their plans
(`tools/map_audit.py`). The contact sheets are `assets/reference/maps/sheet_flats.png`,
`sheet_harbour.png`, `sheet_streets.png` and `sheet_hall.png`; the numbers are in
`assets/reference/maps/audit.csv`. The problem numbers are MAP_ROADMAP.md's.

## Findings

1. **Nothing passes.** Scores run from 11 to 18 out of 18 (lower is better); the mean is
   14.7, and no biome is better than another (Flats 14.4, Harbour 14.5, Streets 14.8, Hall 15.1).
   Ten of the 18 points are the five problems that live in the renderer, not the plan: one
   screen, hard edges, no set pieces, the one-tile rim, no world light. Every room fails those.
2. **Eighteen rooms are copies.** The altar, challenge, dive, shop and vault plans are the same
   cell for cell in two to four biomes. Seven of these copies score the full 18. A player who
   reaches the Hall has seen its altar, challenge, dive, shop and vault rooms in the Flats.
3. **The floor is bare.** On average 80 % of the ground a player can walk on is the base tile
   with nothing on it. 44 rooms are at 85 % or more. 31 rooms hold an empty square of 12x12
   tiles or larger, which is a third of the screen's height.
4. **The plans are greybox.** The mean mirror symmetry is 0.92: 51 rooms are 90 % or more
   identical to their own reflection. 73 % of features are plain rectangles or rectangle
   outlines. Only `flats_06` (a diagonal coast) and `flats_07` (a winding channel) have a
   natural edge that is not a staircase or a box.
5. **The biomes reuse each other's plans.** Even where the plan is not a copy, the harbour's,
   the Streets' and the Hall's water rooms are the same long rectangle of channel
   (`harbour_07`, `hall_07`, `hall_06`, `harbour_09`: 0.60-0.63 alike). A plan does not say
   what biome it belongs to; only the floor tile does.
6. **What is worth keeping.** Twelve plans carry an idea for the chunk library (Stage 08); the
   last column of the table names it. Their geometry is still rebuilt to section 22.

## Scores

Measures: `plain` is the share of walkable ground that is bare base floor; `hole` is the side of
the largest bare square, in tiles; `sym` is the best mirror match; `rect` is the share of
features that are rectangles; `twin` is the same plan in another biome; `nearest` is the most
similar other room (Jaccard over feature cells). Scores (0 fine, 1 weak, 2 failing): 2 wallpaper,
3 greybox, 7 no biome identity, 9 repeats. `/18` adds 10 for problems 1, 4, 5, 6 and 8.

| room | plain | hole | sym | rect | twin | nearest | 2 | 3 | 7 | 9 | /18 | keep |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| biome1/altar_01 | 0.95 | 11 | 0.96 | 1.00 | biome2/altar_01 | biome2/altar_01 1.00 | 2 | 2 | 2 | 2 | 18 |  |
| biome1/boss_01 | 0.76 | 18 | 1.00 | 0.00 | - | biome2/boss_01 0.90 | 2 | 1 | 1 | 2 | 16 |  |
| biome1/challenge_01 | 0.78 | 8 | 0.96 | 0.80 | harbour/challenge_01 | harbour/challenge_01 1.00 | 0 | 2 | 2 | 2 | 16 |  |
| biome1/dive_01 | 0.14 | 2 | 0.91 | 0.33 | harbour/dive_01 | harbour/dive_01 1.00 | 0 | 1 | 2 | 2 | 15 |  |
| biome1/echo_01 | 0.96 | 11 | 0.89 | 0.88 | - | biome3/hall_02 0.08 | 2 | 1 | 1 | 0 | 14 |  |
| biome1/flats_01 | 0.92 | 17 | 0.89 | 0.67 | - | harbour/harbour_06 0.28 | 2 | 0 | 1 | 0 | 13 |  |
| biome1/flats_02 | 0.76 | 13 | 0.99 | 1.00 | - | biome2/echo_02 0.24 | 1 | 2 | 1 | 0 | 14 |  |
| biome1/flats_03 | 0.92 | 11 | 0.85 | 0.78 | - | harbour/harbour_06 0.15 | 2 | 0 | 1 | 0 | 13 |  |
| biome1/flats_04 | 0.77 | 9 | 0.76 | 0.50 | - | harbour/harbour_04 0.35 | 0 | 0 | 1 | 1 | 12 | moat ring round an island |
| biome1/flats_05 | 0.94 | 12 | 0.96 | 1.00 | - | biome3/hall_01 0.11 | 2 | 2 | 1 | 0 | 15 |  |
| biome1/flats_06 | 0.91 | 15 | 0.82 | 0.40 | - | biome1/flats_01 0.17 | 2 | 0 | 1 | 0 | 13 | the coast cuts the room on a diagonal |
| biome1/flats_07 | 0.89 | 14 | 0.83 | 0.40 | - | harbour/harbour_05 0.23 | 2 | 0 | 1 | 0 | 13 | a winding channel, the one organic water shape |
| biome1/flats_08 | 0.99 | 9 | 0.97 | 0.50 | - | harbour/harbour_03 0.26 | 2 | 1 | 1 | 0 | 14 |  |
| biome1/flats_09 | 0.88 | 9 | 0.95 | 0.44 | - | biome3/boss_01 0.17 | 1 | 1 | 1 | 0 | 13 |  |
| biome1/flats_10 | 0.91 | 9 | 0.96 | 0.00 | - | biome2/streets_10 0.23 | 2 | 1 | 1 | 0 | 14 |  |
| biome1/flats_11 | 0.90 | 13 | 0.93 | 0.90 | - | harbour/harbour_08 0.17 | 1 | 2 | 1 | 0 | 14 |  |
| biome1/flats_12 | 0.70 | 9 | 0.89 | 0.20 | - | biome2/echo_02 0.30 | 0 | 0 | 1 | 0 | 11 |  |
| biome1/fountain_01 | 0.92 | 13 | 0.85 | 0.00 | - | biome1/shop_01 0.52 | 2 | 0 | 1 | 2 | 15 |  |
| biome1/shop_01 | 0.95 | 12 | 0.86 | 0.67 | biome2/shop_01 | biome2/shop_01 1.00 | 2 | 0 | 2 | 2 | 16 |  |
| biome1/treasure_01 | 0.95 | 12 | 0.91 | 0.80 | - | biome1/flats_01 0.27 | 2 | 2 | 1 | 0 | 15 |  |
| biome1/vault_01 | 0.99 | 12 | 0.95 | 1.00 | harbour/vault_01 | harbour/vault_01 1.00 | 2 | 2 | 2 | 2 | 18 |  |
| harbour/altar_01 | 0.78 | 11 | 0.89 | 0.50 | - | harbour/harbour_06 0.47 | 1 | 0 | 1 | 1 | 13 |  |
| harbour/boss_01 | 0.39 | 6 | 1.00 | 0.00 | - | harbour/harbour_10 0.38 | 0 | 1 | 1 | 1 | 13 |  |
| harbour/challenge_01 | 0.78 | 8 | 0.96 | 0.80 | biome1/challenge_01 | biome1/challenge_01 1.00 | 0 | 2 | 2 | 2 | 16 |  |
| harbour/dive_01 | 0.14 | 2 | 0.91 | 0.33 | biome1/dive_01 | biome1/dive_01 1.00 | 0 | 1 | 2 | 2 | 15 |  |
| harbour/echo_01 | 0.91 | 11 | 0.79 | 1.00 | - | harbour/harbour_01 0.38 | 2 | 1 | 1 | 1 | 15 |  |
| harbour/fountain_01 | 0.90 | 13 | 0.96 | 0.80 | - | harbour/shop_01 0.48 | 1 | 2 | 1 | 1 | 15 |  |
| harbour/harbour_01 | 0.74 | 10 | 0.94 | 1.00 | - | harbour/harbour_09 0.46 | 0 | 2 | 1 | 1 | 14 |  |
| harbour/harbour_02 | 0.67 | 13 | 0.99 | 1.00 | - | biome2/echo_02 0.21 | 1 | 2 | 1 | 0 | 14 |  |
| harbour/harbour_03 | 0.99 | 12 | 0.96 | 1.00 | - | biome1/flats_08 0.26 | 2 | 2 | 1 | 0 | 15 | four warehouse bays opening on the deck |
| harbour/harbour_04 | 0.43 | 6 | 0.80 | 0.00 | - | biome1/dive_01 0.48 | 0 | 0 | 1 | 1 | 12 |  |
| harbour/harbour_05 | 0.88 | 13 | 0.97 | 1.00 | - | biome1/flats_07 0.23 | 1 | 2 | 1 | 0 | 14 |  |
| harbour/harbour_06 | 0.80 | 11 | 0.93 | 0.92 | - | harbour/altar_01 0.47 | 1 | 2 | 1 | 1 | 15 | a dock basin with quay ends |
| harbour/harbour_07 | 0.53 | 7 | 0.86 | 0.83 | - | biome3/hall_07 0.63 | 0 | 1 | 1 | 2 | 14 |  |
| harbour/harbour_08 | 0.82 | 9 | 0.97 | 0.60 | - | biome3/hall_01 0.28 | 1 | 1 | 1 | 0 | 13 |  |
| harbour/harbour_09 | 0.57 | 7 | 0.88 | 0.50 | - | harbour/harbour_07 0.62 | 0 | 0 | 1 | 2 | 13 | a pier across a channel |
| harbour/harbour_10 | 0.61 | 7 | 0.88 | 0.83 | - | biome3/hall_10 0.60 | 0 | 1 | 1 | 2 | 14 |  |
| harbour/shop_01 | 0.90 | 14 | 0.97 | 0.80 | - | harbour/fountain_01 0.48 | 2 | 2 | 1 | 1 | 16 |  |
| harbour/treasure_01 | 0.96 | 11 | 0.98 | 1.00 | - | biome1/vault_01 0.32 | 2 | 2 | 1 | 1 | 16 |  |
| harbour/vault_01 | 0.99 | 12 | 0.95 | 1.00 | biome1/vault_01 | biome1/vault_01 1.00 | 2 | 2 | 2 | 2 | 18 |  |
| biome2/altar_01 | 0.95 | 11 | 0.96 | 1.00 | biome1/altar_01 | biome1/altar_01 1.00 | 2 | 2 | 2 | 2 | 18 |  |
| biome2/boss_01 | 0.73 | 13 | 0.98 | 0.50 | - | biome1/boss_01 0.90 | 1 | 1 | 1 | 2 | 15 |  |
| biome2/challenge_01 | 0.78 | 8 | 0.96 | 0.80 | biome1/challenge_01 | biome1/challenge_01 1.00 | 0 | 2 | 2 | 2 | 16 |  |
| biome2/dive_01 | 0.14 | 2 | 0.91 | 0.33 | biome1/dive_01 | biome1/dive_01 1.00 | 0 | 1 | 2 | 2 | 15 |  |
| biome2/echo_01 | 0.99 | 10 | 0.95 | 0.00 | - | biome2/streets_09 0.13 | 2 | 1 | 1 | 0 | 14 |  |
| biome2/echo_02 | 0.41 | 12 | 0.99 | 0.00 | - | biome3/hall_04 0.56 | 1 | 1 | 1 | 2 | 15 |  |
| biome2/fountain_01 | 0.96 | 12 | 0.86 | 1.00 | - | biome3/fountain_01 0.54 | 2 | 1 | 1 | 2 | 16 |  |
| biome2/shop_01 | 0.95 | 12 | 0.86 | 0.67 | biome1/shop_01 | biome1/shop_01 1.00 | 2 | 0 | 2 | 2 | 16 |  |
| biome2/streets_01 | 0.83 | 9 | 0.77 | 0.75 | - | biome3/hall_02 0.34 | 1 | 0 | 1 | 1 | 13 | a raised terrace with shop fronts |
| biome2/streets_02 | 0.88 | 14 | 0.80 | 1.00 | - | biome1/flats_12 0.14 | 2 | 1 | 1 | 0 | 14 |  |
| biome2/streets_03 | 0.83 | 12 | 0.96 | 1.00 | - | harbour/boss_01 0.21 | 1 | 2 | 1 | 0 | 14 |  |
| biome2/streets_04 | 0.90 | 10 | 0.97 | 1.00 | - | biome1/flats_07 0.14 | 1 | 2 | 1 | 0 | 14 |  |
| biome2/streets_05 | 0.92 | 12 | 0.94 | 1.00 | - | biome1/flats_09 0.08 | 2 | 2 | 1 | 0 | 15 |  |
| biome2/streets_06 | 0.95 | 16 | 0.85 | 0.80 | - | biome1/flats_02 0.13 | 2 | 1 | 1 | 0 | 14 |  |
| biome2/streets_07 | 0.99 | 4 | 0.85 | 1.00 | - | biome1/flats_08 0.18 | 2 | 1 | 1 | 0 | 14 |  |
| biome2/streets_08 | 0.51 | 5 | 0.91 | 0.57 | - | biome1/dive_01 0.31 | 0 | 1 | 1 | 1 | 13 | flooded courtyards either side of a causeway |
| biome2/streets_09 | 0.95 | 9 | 0.98 | 0.50 | - | biome2/echo_01 0.13 | 2 | 1 | 1 | 0 | 14 |  |
| biome2/streets_10 | 0.80 | 8 | 0.93 | 0.91 | - | biome1/challenge_01 0.44 | 1 | 2 | 1 | 1 | 15 |  |
| biome2/treasure_01 | 0.99 | 10 | 0.86 | 1.00 | - | - 0.00 | 2 | 1 | 1 | 0 | 14 | the street collapses into the void |
| biome2/vault_01 | 0.99 | 12 | 0.95 | 1.00 | biome1/vault_01 | biome1/vault_01 1.00 | 2 | 2 | 2 | 2 | 18 |  |
| biome3/altar_01 | 0.95 | 11 | 0.96 | 1.00 | biome1/altar_01 | biome1/altar_01 1.00 | 2 | 2 | 2 | 2 | 18 |  |
| biome3/boss_01 | 0.69 | 8 | 0.98 | 0.67 | - | biome2/boss_01 0.81 | 0 | 1 | 1 | 2 | 14 |  |
| biome3/challenge_01 | 0.78 | 8 | 0.96 | 0.80 | biome1/challenge_01 | biome1/challenge_01 1.00 | 0 | 2 | 2 | 2 | 16 |  |
| biome3/dive_01 | 0.14 | 2 | 0.91 | 0.33 | biome1/dive_01 | biome1/dive_01 1.00 | 0 | 1 | 2 | 2 | 15 |  |
| biome3/echo_01 | 0.90 | 8 | 0.85 | 1.00 | - | biome3/hall_01 0.58 | 2 | 1 | 1 | 2 | 16 |  |
| biome3/fountain_01 | 0.96 | 12 | 0.82 | 1.00 | - | biome2/fountain_01 0.54 | 2 | 1 | 1 | 2 | 16 |  |
| biome3/hall_01 | 0.89 | 9 | 0.95 | 1.00 | - | biome3/echo_01 0.58 | 1 | 2 | 1 | 2 | 16 |  |
| biome3/hall_02 | 0.70 | 8 | 0.83 | 0.78 | - | biome2/streets_01 0.34 | 0 | 0 | 1 | 1 | 12 | stepped terraces down to a channel |
| biome3/hall_03 | 0.90 | 10 | 0.93 | 1.00 | - | harbour/harbour_04 0.15 | 1 | 2 | 1 | 0 | 14 |  |
| biome3/hall_04 | 0.61 | 8 | 0.94 | 0.83 | - | biome2/echo_02 0.56 | 0 | 2 | 1 | 2 | 15 |  |
| biome3/hall_05 | 0.94 | 16 | 0.86 | 1.00 | - | biome2/streets_03 0.10 | 2 | 1 | 1 | 0 | 14 |  |
| biome3/hall_06 | 0.57 | 6 | 0.96 | 0.94 | - | harbour/harbour_07 0.60 | 0 | 2 | 1 | 2 | 15 | a colonnade standing in the channel |
| biome3/hall_07 | 0.66 | 6 | 0.86 | 1.00 | - | harbour/harbour_07 0.63 | 0 | 1 | 1 | 2 | 14 |  |
| biome3/hall_08 | 0.90 | 9 | 1.00 | 1.00 | - | harbour/altar_01 0.08 | 2 | 2 | 1 | 0 | 15 |  |
| biome3/hall_09 | 0.79 | 8 | 1.00 | 0.50 | - | biome1/flats_12 0.29 | 0 | 1 | 1 | 0 | 12 |  |
| biome3/hall_10 | 0.60 | 6 | 0.95 | 0.80 | - | harbour/harbour_10 0.60 | 0 | 2 | 1 | 2 | 15 |  |
| biome3/shop_01 | 0.95 | 12 | 0.86 | 0.67 | biome1/shop_01 | biome1/shop_01 1.00 | 2 | 0 | 2 | 2 | 16 |  |
| biome3/treasure_01 | 1.00 | 17 | 0.95 | 1.00 | - | - 0.00 | 2 | 2 | 1 | 0 | 15 | a nave aisle with the void either side |
| biome3/vault_01 | 0.99 | 12 | 0.95 | 1.00 | biome1/vault_01 | biome1/vault_01 1.00 | 2 | 2 | 2 | 2 | 18 |  |
