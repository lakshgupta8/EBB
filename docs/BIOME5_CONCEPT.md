# EBB — The fifth biome: concept (map Stage 11, step 1)

**Decided 2026-10-05 by the user: Concept 3, the Reef, at P1 (an alternate to the Harbour).**
The Reef as it will be built is set out under "The Reef as chosen" at the end; the rest of the
brief is the comparison as it was offered.

Decision B3 (MAP_ROADMAP.md) adds a fifth biome. No art is made until a concept is approved.
This brief sets four concepts side by side, then where the biome goes in the run, then a
recommendation. Each concept says what makes it more than a new set of tiles: **a tide rule of
its own**, because the tide is the game's signature and every biome so far floods the same way.

The four biomes today, for contrast:

| Biome | Floor reads as | Shapes | Palette |
|---|---|---|---|
| The Flats | pale sand, open water | coast, pools, dunes | Sand, Bone, Sea |
| The Sunken Harbour | brown planks, straight channels | quays, piers | Wood, Rope, Iron, Sea |
| The Drowned Streets | blue-grey cobbles | squares, lanes, canal | Wet grey, Pale slate, Verdigris |
| The Deep Hall | dark slate, violet light | nave, aisles, crypt | Basalt, Slate, Deep violet |

---

## Concept 1 — The Salt Works

**Where it is.** Saltmere was named for its salt. Below the city's landward edge lie the pans
where seawater was let in, left to dry and boiled down in iron kettles: the city's wealth. The
salt-boilers knew the tide better than anyone. They were the first to hear the Ebb.

**Its tide rule: the crust dissolves.** Pans hold *salt crust*, a new ground. Dry crust stands
as a raised floor or a wall. Once the tide covers it, it dissolves over a few seconds and becomes
low ground. The room changes shape during the fight: crust walls go and open new routes, and the
crust ledges you climbed onto to stay dry dissolve under you. This is the "flood order is planned"
rule of STYLE.md 22, made visible.

**Plans.** A grid of evaporation pans (low, square, crusted) divided by raised clay walkways.
Boiling houses as solid blocks with chimneys, a brine channel with sluice gates, salt heaps
gathered by the walls, rail tracks for the salt carts. It is the only biome laid out in a grid,
and its shapes are built by people, not the sea.

**Set pieces (eight to ten).** The boiling kettle, an iron pan on a fire (the biome's warm
light); salt heaps; a wind pump; a sluice gate; drying racks; stacked sacks; a salt cart on its
rails; a chimney stack; the brine cistern; a weighing beam.

**Palette.** Crust in Salt white and Foam white, brine in Salt red. Real salt pans run pink, and
Salt red is already in the palette but barely used. Iron and Rust for the kettles, Bronze for the
pump fittings, Basalt for the clay walkways. It is the only pale-floored biome after the Flats,
and the only one with red water. Risk: the pale Drowned read poorly on white crust. The answer is
dark walkways where fights happen, with the crust as the hazard ground.

**Its people (later sub-stages).**
- **Enemies:** the Crusted, Drowned armoured in salt that sheds in water (the existing
  Salt-crusted affix as a whole family); the Boiler, which bursts into a cloud of steam; the Raker,
  which reaches with a long rake.
- **Elite:** the Foreman.
- **Boss:** the Pan-Mother, a colossus of crust. As the scripted tide rises it loses armour, but
  each flooded phase takes the arena's high ground with it.
- **Echo:** Agnes the Boiler. In the hub she renders salt, a new use for the run's currency.

**Cost.** One new terrain behaviour (crust that changes when flooded, in Room and the tide
code), a new tile set and set pieces, and its grammar. The grid plans suit the generator well.

---

## Concept 2 — The Lighthouse Stair

**Where it is.** Under Marrow Rock itself is the keepers' own way down: a stair cut through the
rock below the lighthouse, with landings, the keepers' cells and old lamp rooms. Every keeper
before Tam came this way.

**Its tide rule: it comes from below.** Rooms are tiers of a stairwell, and the tide steps up
them one tier at a time, from the well in the middle. To stay dry you keep climbing, and the
fights are on the stairs.

**Plans.** Concentric tiers round a well (the ring of Stage 10), landings, cells off a passage,
and switchback stairs.

**Set pieces.** A lamp housing, a keeper's cell door, a bell rope, a lens, shelves of logbooks,
a winch, an iron landing rail.

**Palette.** Basalt, wet black rock, Amber lamp glass, Bronze. This is close to the Deep Hall's
dark palette and the least distinct of the four.

**Its people.** Keepers' shades (Aldous's line), a lamp-moth swarm, a boss called the Lamp
That Went Out. It has the strongest story tie of the four, but it overlaps what Aldous and the
Hall already tell.

**Cost.** Highest. The tiers need more than the three ground heights the tide works with today
(low, floor, raised), which changes the tide, water, tile and editor code. A stairwell also reads
weakly from straight above.

---

## Concept 3 — The Reef

**Where it is.** Saltmere's outer sea wall, three hundred years under, now grown over with coral
and kelp: the edge where the deep begins.

**Its tide rule: currents.** Deep water runs in a direction and carries bodies with it. Coral
cuts anyone pushed into it. The tide does not just rise here; it pulls.

**Plans.** Organic coral masses, kelp stands that hide enemies, sand channels, the broken sea
wall.

**Set pieces.** Brain coral, a fan, a giant clam, a kelp stand, sea-wall stones, an anchor in
the coral.

**Palette.** Coral pinks and oranges, Deep violet. It needs new colours. It would be the brightest
biome, which pulls against the game's melancholy tone, and its organic shapes repeat the Flats.

**Cost.** Medium. Currents are a new force on every body, and the bot has to learn to fight
them.

---

## Concept 4 — The Drowned Wood

**Where it is.** The forest Saltmere stood in before the sea came: dead trunks standing in the
water, and the grove where the bargain was first spoken.

**Its tide rule: the roots are the high ground.** Fallen trunks and roots are the only raised
ground. Mist cuts how far you can see, so the lantern's reach matters.

**Plans.** Grids of trunks, root tangles, clearings, a woodcutter's hut, a bog.

**Palette.** Moss, Kelp, Wood. It is dark, and close to the Harbour's browns.

**Cost.** Medium to high. Mist is a new drawing system, and dense trunks crowd the camera and
the fights.

---

## Where it goes in the run

| | Placement | Run length | Story | Code |
|---|---|---|---|---|
| **P1** | An alternate to the Harbour: at the end of the Flats, two ways down (the harbour road or the salt road); both lead to the Streets | unchanged (about 22 min) | each road has its own echo; the secret ending needs both, across nights | a branch in the biome sequence (save, Spring Tides, Idris's launch, the codex, the bot) |
| **P2** | In sequence, between the Streets and the Hall | +9 rooms, about 27 min a winning night | the descent goes one step deeper before the Ebb | a fifth entry everywhere the four biomes are listed |
| **P3** | After the Hall, open after the first win | unchanged for the first win | a postscript; the story has already ended there | small, but the biome is seen late and by few |

---

## Recommendation: Concept 1 (the Salt Works) at P1 (an alternate to the Harbour)

- **The tide rule changes how a room plays, not only how it looks.** Dissolving crust uses the
  large rooms, the shapes and the generator just built, and the room is different at the end of
  a fight than at the start.
- **It is the most distinct to look at.** It has the only grid plans, the only red water, and
  pale crust against dark walkways, all in colours already in the palette.
- **Its story comes from the city's own name.** Saltmere was a salt town, and salt is already
  the run's currency.
- **As an alternate road it adds replay without making a winning night longer.** The game
  already has its first fork, the wet and dry paths.

**Runner-up:** the Lighthouse Stair at P2. It has the best story, but it costs the most and
looks too much like the Hall.

## After approval

The chosen concept goes through the art stages in order, with a sheet to approve at each step:
- palette and tiles (as Stage 03);
- floor patches (as Stage 04);
- set pieces (as Stage 05);
- light (as Stage 07);
- its grammar and chunks (as Stage 08);
- its rooms (as Stages 09 and 10).

Its own rule (for the Salt Works, the dissolving crust) is built and shown in one sample room
before any mass production. Enemies, elite, boss, echo, music and whispers come after, as their
own sub-stages.

---

## The Reef as chosen

**Where it is.** At the end of the Flats there are two ways down. One is the harbour road, the
other is the reef road along the outside of Saltmere's sea wall. Both come out in the Drowned
Streets. The reef road has nine rooms and a boss, and its own echo.

**Why it is pale.** When the Ebb held Saltmere still, it held the reef too: three hundred years
without a current. The coral bleached and died standing. This answers the brief's tone risk: the
Reef is a dead, cool, pale place, not a bright one.

**Why the water moves.** The tide going out is the Ebb losing its grip (story layer 3). On the
reef, the held water has begun to move again. The **currents** are that slipping grip, and colour
comes back only where they run: living coral grows by the channels.

**Shapes, apart from the Flats.**
- *The sea wall:* the city's wall, laid in straight courses and broken by breaches, so a Reef
  room has hard straight lines that the Flats never have.
- *Coral heads:* lumpy raised platforms that stay dry longest.
- *Channels:* low sand runs where the current flows.
- *The floor:* cool grey-green coral rubble, not warm sand.

**Palette (all already in the master palette, nothing added).**

| Use | Colours |
|---|---|
| Floor rubble | Drowned shade, Drowned skin |
| Coral heads | Drowned skin |
| Channel beds | Oilskin light, Oilskin |
| Sea wall | Stone, Stone dark, Basalt |
| Living coral, only by the water | Salt red, Violet light, Amber deep |

**The tide rule (built in its own sub-stage, one sample room first).** Water in a channel carries
a direction. Shallow water pushes a body along it gently. Deep water pushes hard, and the pull
grows as the tide rises. Living coral by the channels cuts anyone carried into it. Enemies feel
the pull too: the Reef's own kinds swim with it, and the others are carried.

**Its people (later sub-stages, to be drawn up then).**
- *Enemies:* a Coral Crab that hides in a coral head; a Ray that rides the current; a Polyp
  Swarm that grows out of the living patches.
- *Elite:* the Reefwarden, a drowned diver of the wall.
- *Boss:* the Tidewall, the breach in the sea wall itself. Each phase opens another breach and
  turns the current through the arena.
- *Echo:* a wall-mason of Saltmere.

**Order of work.**
- 11a: tiles and palette (this sheet).
- 11b: the Reef in the game, as a look: void, obstacles, atmosphere and patches placed by reason.
- 11c: set pieces and light.
- 11d: grammar and chunks.
- 11e: the current rule and a sample room.
- 11f: its rooms.
- 11g: the second road in the run (done: `Run.BIOMES` `step`/`next`/`road`; the Wreck's arena has two signed ways down; until 11h the Reef borrows the Harbour's signature plans, the Chainmother, and stand-in drowned).
- 11h: the three drowned (done: the Coral Crab, the Reef Ray, the Polyp Swarm; `tools/gen_reef_enemies.py`).
- 11i: the elite (done: the Reefwarden, a wall-diver with a maul and a surge; lead boots, so the current cannot move him).
- 11j: the boss (done: the Tidewall; it turns the current, and its second breach opens a second channel).
- 11k: the echo (done: Hale the Mason; everyone home now needs a night down each road).
- 11l: music and lantern lines (done: `music_reef`, `amb_reef`, three lines; the Tidewall's arena raised under the wall). The Reef is whole.
- Map Stage 12f: the Reef's own signature rooms (the merchant on a coral head in a wreck's ribs, the altar on a bastion off the sea wall, the fountain in a ring of circling water, Hale's cage at a breach's foot) and the Tidewall's arena dressed with its lines kept.
