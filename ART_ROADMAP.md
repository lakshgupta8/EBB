# EBB — Art direction brief and 23-stage roadmap (verbatim, from the user)

Saved 2026-09-19 so the brief survives context loss. This is the contract. STYLE.md is the specification; ART_PROGRESS.md is the log. One stage per explicit "Proceed to Stage X."

---

You are the ART DIRECTOR and TECHNICAL ARTIST for EBB.

Your task is to redesign and progressively implement the complete 2D visual identity of the game inside the existing Godot project.

IMPORTANT:

The existing art is PLACEHOLDER ART.

Do not treat the current sprites, proportions, colors, compositions, or visual treatment as something that must be preserved.

The existing art is useful only for:
- understanding what assets exist
- understanding gameplay readability
- understanding technical dimensions
- understanding the current implementation
- understanding how assets are used

The final result should look like a deliberately art-directed indie 2D game, not upgraded placeholder pixel art.

==================================================
EXECUTION CONTROL
==================================================

You have a multi-stage visual redesign roadmap below.

IMPORTANT:

Do NOT automatically execute all stages in one run.

At the beginning of the project, execute ONLY STAGE 01.

After completing a stage:

1. Update ART_PROGRESS.md.
2. Summarize what you changed.
3. Explain what I should visually inspect.
4. STOP and wait for my approval.

Only proceed to the next stage when I explicitly say:

"Proceed to Stage X."

Never interpret silence as approval.

For stages involving visual design, create a small representative
sample before mass-producing assets.

Do not generate the complete asset library until the visual
anchors have been approved.

If a later stage depends on an unresolved visual decision,
STOP and request approval rather than guessing.

Do NOT attempt to redesign the entire game in one pass.

Work through the stages below sequentially.

After every major stage:
1. Implement the stage.
2. Run the game.
3. Inspect the result.
4. Compare it against the art direction.
5. Identify inconsistencies.
6. Fix the most important problems.
7. Only then proceed.

Do not move forward simply because the assets technically work.

==================================================
PROJECT CONTEXT
==================================================

Game:

EBB is a top-down 2D action roguelite.

Every night, the sea around Marrow Rock pulls impossibly far back and exposes Saltmere, a city that drowned 300 years ago.

The player, Tam, is the new Tidekeeper.

The player descends through drowned ruins, fights what lives there, rescues echoes of drowned people, gathers resources, becomes stronger, and eventually gets caught by the returning tide.

The tide is the central mechanic.

Water physically rises during a run.

Dry ground becomes shallow water and eventually deep water.

The tide changes:
- movement
- routes
- enemy behavior
- danger
- room accessibility
- visual composition

The game should communicate this visually.

The emotional tone is:

MELANCHOLY BUT WARM.

Not horror.
Not gothic fantasy.
Not grimdark.
Not cartoon comedy.

Think:

cold northern coastal fishing village
+
wet stone
+
salt
+
rope
+
iron
+
oilskins
+
lamplight
+
quiet melancholy
+
a sea that feels subtly wrong.

The world should feel like a place inhabited by ordinary people whose lives were interrupted by something supernatural.

The drowned are PEOPLE.

They are not zombies.
They are not skeletons.
They are not rotting corpses.

They are preserved, pale, damp echoes of people who should have died but somehow remained.

Their visual treatment should communicate:
- sadness
- stillness
- gentleness
- unnatural preservation

rather than gore or horror.

==================================================
EXISTING TECHNICAL CONSTRAINTS
==================================================

These constraints are fixed unless the existing project demonstrates that a change is absolutely necessary.

Internal resolution:
640 × 360

Display:
integer scaling.

Base tile:
16 × 16 px

Character cells:
24 × 24 px

Player and normal enemies use 24 × 24 cells.

Bosses may use 48 × 48 or 72 × 72 presentation while preserving the same visual language.

Sprites:
pixel art.

PNG with alpha.

No anti-aliasing against transparency.

Sprite sheets use fixed cells.

Sprites generally face right and are mirrored horizontally in engine.

The player aims in 360 degrees.

The body and weapon are separate visual elements.

Lighting:
cold blue nighttime environment with a warm lantern carried by the player.

The lantern should feel physically warm but subtly supernatural.

The scene must remain readable at 640 × 360 with:
- player
- approximately ten enemies
- water
- foam
- projectiles
- particles
- HUD

on screen simultaneously.

READABILITY ALWAYS BEATS DETAIL.

==================================================
CORE VISUAL PRINCIPLE
==================================================

The target is:

"small, expressive, atmospheric pixel art with exceptional silhouette and lighting discipline."

Do NOT simply increase sprite detail.

Do NOT make every pixel noisy.

Do NOT use gradients everywhere.

Do NOT create pseudo-HD pixel art.

Do NOT make assets look like generic AI pixel art.

Do NOT randomly add highlights.

Do NOT give every object the same outline.

Do NOT use excessive black outlines.

Do NOT make every biome use the same dominant color.

Do NOT make the game visually muddy.

Every pixel should serve:
- silhouette
- material
- lighting
- depth
- gameplay readability
- atmosphere

==================================================
STAGE 01 — AUDIT THE EXISTING GAME
==================================================

Before changing art:

Inspect the entire existing Godot project.

Identify:

- every sprite
- every sprite sheet
- every tile
- every prop
- every enemy
- every NPC
- every boss
- every weapon
- every projectile
- every effect
- every UI element
- every shader
- every lighting system
- every parallax layer
- every place where art is procedurally drawn
- every hardcoded visual assumption

Create:

ART_ASSET_AUDIT.md

Document:

asset
current dimensions
where it is used
animation frames
technical dependencies
whether it should be:
- redesigned
- retained
- replaced
- procedurally generated

Do not redesign anything yet.

==================================================
STAGE 02 — CREATE THE VISUAL STYLE BIBLE
==================================================

Create:

STYLE.md

This is the most important document in the entire visual redesign.

Define the final visual language.

It must include:

1. Pixel density
2. Pixel clusters
3. Outline rules
4. Shadow rules
5. Highlight rules
6. Material rendering
7. Character proportions
8. Environment detail density
9. Color palette
10. Biome palettes
11. Lighting
12. Water
13. Fog/atmosphere
14. Effects
15. UI
16. Typography
17. Animation
18. Drowned-person visual treatment
19. Boss visual hierarchy
20. Rules for visual readability

Every future asset must follow STYLE.md.

When generating a new asset, treat STYLE.md as a hard visual specification.

==================================================
STAGE 03 — DEFINE THE COLOR SYSTEM
==================================================

Create a limited master palette.

Do not simply pick colors independently for every sprite.

The palette should have a shared foundation.

Base world colors:

- cold slate
- deep blue
- desaturated blue-green
- wet grey
- muted stone
- dark iron
- weathered brown
- muted moss
- salt white

Warm light:

- pale cream
- warm yellow
- muted amber

The warm colors should be relatively rare.

The warm lantern should therefore immediately attract attention.

Create separate but related palettes for:

MARROW ROCK
THE FLATS
THE DROWNED STREETS
THE DEEP HALL

Each biome must feel distinct without looking like a completely different game.

Create a palette reference asset and document the colors in STYLE.md.

==================================================
STAGE 04 — DEFINE PIXEL-ART RULES
==================================================

Establish exact rules for:

- pixel clusters
- anti-aliasing
- outlines
- one-pixel accents
- highlights
- shadows
- dithering
- texture
- diagonal lines
- curves
- circular forms
- water
- light

Prefer intentional pixel clusters over noisy single-pixel decoration.

Characters should have extremely readable silhouettes.

Environmental assets can contain more texture but should remain subordinate to gameplay entities.

Use detail density based on importance.

HIGHEST DETAIL:
player
bosses
important NPCs
interactive objects

MEDIUM DETAIL:
normal enemies
major props

LOW DETAIL:
background decoration
floor texture
distant scenery

==================================================
STAGE 05 — CREATE VISUAL ANCHORS
==================================================

Do NOT generate the entire asset library yet.

Create a small set of canonical reference assets.

Create:

1. Tam
2. one Drowned NPC
3. one Flats enemy
4. one Streets enemy
5. one Deep Hall enemy
6. one boss
7. one Flats floor tile
8. one Streets floor tile
9. one Hall floor tile
10. one water tile
11. one major environmental prop
12. one UI panel

These are STYLE ANCHORS.

Every future asset must visually relate to them.

If the anchors do not look coherent together:

STOP.

Fix them before continuing.

==================================================
STAGE 06 — CHARACTER DESIGN
==================================================

Redesign Tam first.

Tam should read immediately as:

young coastal fisher
+
Tidekeeper
+
working person
+
not a fantasy warrior

Important visual characteristics:

hooded oilskin coat
boots
keeper's lantern
practical clothing
simple silhouette
weathered materials

Avoid:
armor
heroic fantasy clothing
ornate costumes
oversized weapons
generic RPG protagonist design

The lantern is extremely important.

It should look like a believable working lantern at first glance.

But there should be something subtly wrong about it.

Do not make it obviously magical.

Then redesign Maren.

Maren should share Tam's visual language and silhouette.

She is what Tam may eventually become.

Then design the drowned treatment.

Drowned characters:

pale
wet
quiet
slightly translucent or cold-lit if appropriate
subtle blue-green cast
occasional weed/sea residue
calm facial expressions

NEVER:
rotting flesh
exposed bones
blood
zombie anatomy
gore

==================================================
STAGE 07 — ENEMY DESIGN
==================================================

Every enemy must be identifiable at 1x scale.

Silhouette is more important than surface detail.

Design enemies around their gameplay behavior.

SHELLBACK:
slow heavy silhouette
large barnacled shell
clear slam posture

GULL:
light
fast
airborne
clear dive silhouette

WRACK CRAB:
low horizontal silhouette
large red claws
aggressive posture

STILL CITIZEN:
human silhouette
initially still
arms down
later arms raised
moss and stone treatment

LAMPLIGHTER:
clear pole/light silhouette

BELL RINGER:
small hunched silhouette
bell clearly visible

SWIMMER:
must clearly belong in water
strong horizontal swimming silhouette

KEEPER'S SHADE:
recognizably derived from Tam
but darker
colder
more unnatural

ANCHOR:
heavy iron mass
chain must be readable

DEEP MAW:
floor-based
strong circular/opening silhouette

TIDEWISP:
small ranged entity
fleeing silhouette
pale movement trail

Do not simply recolor existing enemies to create elites.

Elites require deliberate silhouette or costume modifications.

==================================================
STAGE 08 — BOSS DESIGN
==================================================

Redesign the bosses independently.

Do NOT scale up normal enemies.

THE WRECK:

It is a ship that fights.

Visual concepts:
- hull
- ribs
- chains
- broken mast/structure
- figurehead
- barnacles
- wet timber
- iron

It should feel like a ship animated by the tide.

THE BELL OF SALTMERE:

It is the town bell.

It should feel like an architectural object brought to life.

Its visual phases should react to the water level.

THE EBB:

Do NOT make it a generic monster.

The Ebb agreed to keep Saltmere safe.

It is holding people in place because it was asked to.

It should therefore feel:

ancient
calm
sad
powerful
ambiguous

The player should not immediately know whether The Ebb is evil.

Its visual language should connect:

water
lantern light
drowned people
depth
stillness

Boss designs must remain readable at 640 × 360.

==================================================
STAGE 09 — ENVIRONMENT DESIGN
==================================================

Create distinct visual identities.

-----------------------------
MARROW ROCK
-----------------------------

Warmest environment.

Wet rock
lighthouse
small fishing-village details
rope
kelp
shells
driftwood
lanterns
wet sand

The hub should gradually become warmer and more alive as NPCs are rescued.

The visual progression should communicate:

empty → inhabited → hopeful

without becoming bright or cheerful.

-----------------------------
THE FLATS
-----------------------------

Most natural biome.

Materials:

sand
wet sand
standing water
rock
kelp
rope
nets
barnacles
driftwood
shells
crab holes
bones
shipwreck remnants

Open visual composition.

-----------------------------
THE DROWNED STREETS
-----------------------------

Preserved drowned fishing town.

Materials:

cobbles
weathered stone
collapsed brick
wood
moss
verdigris
salt crust
weed
old street furniture
lampposts
market objects

The streets should feel like a real town that was interrupted rather than a fantasy dungeon.

-----------------------------
THE DEEP HALL
-----------------------------

Most oppressive environment.

Basalt
dark stone
channels
water
pews
chains
dead lamps
candles
raised dais
Tidekeeper statues

Vertical visual feeling.

Sparse warm points of light.

==================================================
STAGE 10 — TILE AND WATER SYSTEM
==================================================

This is a critical stage.

Design the visual language of the tide.

The player must immediately understand:

DRY
LOW GROUND
SHALLOW WATER
DEEP WATER

without relying solely on UI.

Water is runtime-generated and must work as an overlay over arbitrary floors.

Do not paint the flood state directly into individual floor textures.

Create:

- dry floor
- low-ground treatment
- shallow-water overlay
- deep-water overlay
- foam edge
- ripple
- splash
- bubble
- flooded doorway
- water-closed doorway
- water-open shortcut

Water should feel physically integrated with the environment.

Avoid a generic blue transparent rectangle.

The water should contain subtle:

movement
depth
surface variation
foam
reflections
color shift

while remaining readable at 1x.

The water overlay must work with:

sand
cobble
basalt
and future environments.

==================================================
STAGE 11 — LIGHTING
==================================================

Lighting is a major part of EBB's identity.

The world is cold.

The lantern is warm.

This contrast should define the game.

Use:

cold ambient night lighting

+

localized warm light

+

subtle environmental reflections

The player's lantern should illuminate:

Tam
nearby floor
nearby props
nearby enemies

The transition should be soft enough to feel atmospheric but strong enough to communicate gameplay.

Do not overuse bloom.

Do not turn the game into neon pixel art.

Warm light should be precious.

Candles, lighthouse light, lamps and other warm sources should follow the same visual language.

==================================================
STAGE 12 — PARALLAX AND DEPTH
==================================================

Introduce depth without compromising the top-down perspective.

Use layered environmental elements where appropriate.

Foreground:
stronger silhouettes

Gameplay layer:
highest readability

Midground:
moderate contrast

Background:
lower contrast and detail

The player must never disappear into scenery.

Use depth to make the world feel larger than the 640 × 360 playfield.

==================================================
STAGE 13 — ANIMATION
==================================================

Redesign animations after static assets are approved.

Animation should communicate weight and personality.

Avoid robotic frame-to-frame movement.

Use:

anticipation
contact
follow-through
recovery

For example:

enemy attack:

idle
→ anticipation
→ windup
→ strike
→ recovery

Do not simply interpolate sprites.

For Tam:

idle
walk
hurt
dash
death

For enemies:

idle
walk
windup
attack
hurt

Increase frame counts where necessary if additional frames materially improve quality.

Animation quality is more important than preserving the original frame count.

==================================================
STAGE 14 — WEAPONS
==================================================

Weapons must feel like objects from the same world.

GAFF HOOK:
working fisher's tool first
weapon second

NET:
real rope/net construction

HARPOON:
industrial/coastal fishing equipment

STORM LANTERN:
same visual language as Tam's lantern

Avoid generic fantasy weapon design.

Weapons should be immediately readable when rotated around Tam.

==================================================
STAGE 15 — VFX
==================================================

Create a unified effects language.

Melee:
sharp directional pixel arc

Impact:
small concentrated burst

Heavy impact:
larger radial energy

Lantern:
warm particulate light

Water:
cool droplets
foam
ripples
splash
bubbles

Status effects:

LIT
→ warm localized glow

ROOT
→ readable net pattern

STUN
→ compact visual burst

BLEED
→ restrained and readable, not gore-heavy

Every effect should be visible at 640 × 360.

Avoid giant particle explosions.

Effects should reinforce gameplay readability.

==================================================
STAGE 16 — UI
==================================================

Redesign the UI to belong to the world.

The UI should feel inspired by:

weathered maritime equipment
navigation charts
fishing tools
old ledgers
salt-stained paper
iron fittings
lantern hardware

Do not create generic modern game UI.

Maintain the bitmap aesthetic.

Create a unified system for:

panels
buttons
bars
icons
room icons
currency icons
boss health
tide meter
dialog
codex
shop
altar
Ledger
pause
settings
ending screens

The five Tidemark families need distinct icon languages:

SALT:
crystal / salt crust

BRINE:
kelp / shell

CURRENT:
wake / foam

DEEP:
pressure / bubbles / darkness

ECHO:
lantern / pale gold

The icons must remain identifiable at small sizes.

==================================================
STAGE 17 — TYPOGRAPHY
==================================================

Evaluate the existing bitmap font.

Determine whether it should be:

retained
modified
or replaced.

Prioritize:

readability
personality
small-size clarity
consistency with pixel art

The font should feel like part of the world rather than generic retro typography.

==================================================
STAGE 18 — LOGO AND TITLE
==================================================

Create the EBB logo and title treatment.

The logo should communicate:

sea
depth
tide
quiet supernatural atmosphere

Avoid generic horror typography.

Avoid overly elaborate fantasy lettering.

The lighthouse should be an important visual motif.

==================================================
STAGE 19 — REBUILD THE ASSET LIBRARY
==================================================

Only after the visual anchors and style bible are approved:

Systematically rebuild the entire asset inventory.

Work category by category:

1. player
2. NPCs
3. enemies
4. bosses
5. weapons
6. projectiles
7. tiles
8. environmental props
9. pickups
10. effects
11. UI
12. title assets

Do not generate random assets in arbitrary order.

Every asset must be checked against STYLE.md and the approved visual anchors.

==================================================
STAGE 20 — IN-GAME COMPOSITION PASS
==================================================

This is NOT an asset-quality pass.

Inspect actual gameplay screenshots.

Evaluate:

- player readability
- enemy readability
- water readability
- floor readability
- lighting
- visual hierarchy
- clutter
- contrast
- UI visibility
- effect density
- biome identity

A sprite that looks beautiful in isolation but becomes unreadable during gameplay is a failed asset.

Modify assets when necessary.

==================================================
STAGE 21 — BIOME KEYFRAME PASS
==================================================

Create one final 640 × 360 visual keyframe for:

Marrow Rock
The Flats
The Drowned Streets
The Deep Hall

At least one should show significant flooding.

Each keyframe must contain:

HUD
player
multiple enemies
environment
water
lighting
effects

These become the final visual references for the project.

==================================================
STAGE 22 — FULL CONSISTENCY AUDIT
==================================================

Perform a visual audit of the entire game.

Check:

STYLE.md compliance
palette consistency
pixel density
outline consistency
lighting direction
character proportions
enemy readability
water treatment
VFX treatment
UI treatment
biome identity
drowned-person treatment
boss visual hierarchy

Find the ten biggest remaining visual inconsistencies.

Fix them in order of impact.

==================================================
STAGE 23 — FINAL POLISH
==================================================

Do a final polish pass.

Do NOT add random detail.

Improve only things that materially increase:

- readability
- atmosphere
- cohesion
- responsiveness
- visual hierarchy
- emotional tone
- sense of place

The final game should feel:

cold
wet
quiet
beautiful
slightly uncanny
melancholic
warm in small places

The player should feel the warmth of the lantern precisely because the world around it is cold.

==================================================
IMPORTANT AGENT BEHAVIOR
==================================================

Never respond with:

"Looks good enough."

Instead evaluate against explicit criteria.

If something is technically functional but visually weak, say so and improve it.

If two assets don't look like they belong to the same game, stop and fix them.

If an asset contains unnecessary detail that harms readability, simplify it.

If an effect obscures gameplay, reduce it.

If the environment competes with the player, reduce environmental contrast.

If the game becomes too dark, increase readability rather than simply increasing brightness.

If the game becomes too colorful, return to the limited palette.

If an asset looks like generic AI-generated pixel art, redesign it.

Do not preserve placeholder art merely because it already exists.

The goal is NOT:

"better placeholder art."

The goal is:

"A coherent, authored visual identity for EBB."

==================================================
DELIVERABLES
==================================================

Maintain these project documents:

STYLE.md
ART_ASSET_AUDIT.md
ART_PROGRESS.md

ART_PROGRESS.md should record:

current stage
completed assets
remaining assets
known inconsistencies
next visual task
visual QA findings

Never lose track of the art direction.

---

## User decisions recorded so far

- 2026-09-19, after Stage 05: "Proceed to stage 6. C tam with hood. The citizen does look like a zombie. Fountain will redraw. Do not skip ahead."
