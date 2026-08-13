# Terrain Tileset — Commission Brief

A hand-off brief for commissioning the battlefield terrain tiles. Built from the engine's real
constraints (`ui/battle_map.lua`, `models/tileset.lua`, `data/tilesets/*.lua`) so delivered art
drops straight in. See [art-assets.md](art-assets.md) for the wider art plan.

## The project

**LoveTactics** — a 2D tactics RPG built in LÖVE2D. Tone: **bright heroic fantasy** (not
grim-dark). Battles play out on a **top-down, square-grid tactical board**, in the tradition of
Game Boy Advance *Fire Emblem*. We need terrain tiles that dress that grid.

## Art direction

- **Reference — the map grammar:** GBA-era *Fire Emblem* tactical maps (*Binding Blade*, *Blazing
  Blade*, *Sacred Stones*). We want their **flat top-down readability** — plains, forest, mountain,
  road, fort, river all readable at a glance from directly above.
- **Finish:** **HD, hand-illustrated / painted. NOT pixel art.** Crisp at 128px, bright palette.
- **Human-made only:** **no AI-generated content** — a contractual requirement, not a preference.

## Technical spec

- **Tile size:** **128 × 128 px**, square. Deliver **256px (2×) masters** too if convenient, for
  clean downscaling.
- **Perspective:** straight **top-down / orthographic**, flat. No isometric, no strong 3D relief
  or long cast shadows.
- **Seamless self-tiling:** each *fill* tile (grass, forest, rock, water) must tile **seamlessly
  against copies of itself** — the engine stamps one image per cell across the board. Avoid
  directional lighting or one-off features that reveal the repeat.
- **Moderate internal contrast:** the engine paints its **own translucent move-cost tint** over
  costly terrain and a **dark overlay** on impassable tiles. Keep each tile's internal value range
  moderate (no blown highlights / crushed shadows) so those overlays stay legible on top.
- **Readable passability (FE convention):** roads/floors read as **traversable lanes**;
  forest / mountain / water read as **terrain features / obstacles**.
- **Delivery:** individual **transparent PNGs**, named `<biome>_<type>.png`, **plus layered
  source** (PSD or SVG). A pre-assembled row-major spritesheet is a bonus, not required — we
  assemble it.

## Tiles needed

**8 biomes × 6 tile types = 48 tiles.** Every biome supplies the same six *roles*; what changes is
what that role is made of in that place. The engine's index order is the row order below.

| # | role | what it does |
|--|--|--|
| 1 | forest | the **solid fill** — the mass the trails are carved out of. Impassable on the world map |
| 2 | grass | a **softer fill** variant, scattered through 1 by noise |
| 3 | rock | a **harder fill** variant, scattered through 1 by noise |
| 4 | path | the **traversable lane**. On most maps this is the only thing a player walks on |
| 5 | bridge\* | a traversable span **across** 6 |
| 6 | water\* | an **impassable channel** cutting the map |

\* **bridge & water are world-map only — not drawn on the battle board.** Battle-critical tiles are
**1–4**.

### What each role is, per biome

| biome | 1 forest (fill) | 2 grass | 3 rock | 4 path | 5 bridge | 6 water |
|--|--|--|--|--|--|--|
| **forest** | dense canopy | grass | rock / boulder | dirt trail | timber bridge | river |
| **castle** | stone-wall block | mossy stone | lighter masonry | flagstone corridor | timber drawbridge | moat |
| **underworld** | black basalt block | cooled slag | broken stone | ash underfoot | span of fused bone | river of fire |
| **desert** | dune crest | dry scrub | weathered sandstone | packed track | planks over a wadi | wadi pool |
| **tundra** | snow drift | frozen tussock | frost-split stone | trodden snow | a span of ice | meltwater lead |
| **volcanic** | basalt block, **sunlit** | cooled slag | broken stone, bleached | ash underfoot | fused span | lava flow |
| **swamp** | mangrove thicket | sedge and reed, yellowed | mossed-over boulder | churned mud / boardwalk | old timber | brackish standing water |
| **colosseum** | the stands, in shadow | worn seating stone | barrier / pillar block, set on the sand | raked sand | timber gate ramp | the drain |

Each biome must read as a **different place** at a glance. Two pairs need deliberate separation:

- **volcanic vs underworld** share a vocabulary of rock and fire. The underworld is subterranean and
  near-black; the volcanic surface is the same geology **under daylight** — warmer, lighter, with sun
  on the stone.
- **swamp vs forest** are both green. The forest reads as somewhere you walk *through*; the swamp
  should read as somewhere you *wade*. Push its greens toward yellow-grey, and its standing water is
  the murkiest in the game — barely lighter than its own fill.

**The colosseum is the odd one and the cheapest.** It is the only biome that is a *building* rather
than a country, so it has no landform in it at all: two materials, raked sand and grey stone, and every
piece of stone on the floor was carried there and set down. Nothing weathers, nothing grows, nothing
wanders. Its fill is the stands seen from inside the bowl — dark, because the crowd is in shadow and
the floor is the thing that is lit. Its "water" is the drain, and it is not water.

Two roles carry an unusual burden and are worth calling out:

- **tundra path.** Snow wants to be white and so does the trail. The trodden path must read as a
  *route* against the drifts, so it is the **bluest** thing in that biome rather than the brightest.
- **desert path.** The reverse problem: everything is already pale, so the packed track is the
  **lightest** value on the board and the dune fill sits a clear step darker.

Reference fallback colours for every one of the 48 are already in the repo at
`data/tilesets/<biome>.lua` — the game currently renders flat rects in those values, so they show the
intended relative values and the separations above.

## Scope & phasing (suggested)

Ordered by how much play each biome actually carries.

- **Phase 1 — Forest, tiles 1–4** — proof of style on one battlefield.
- **Phase 2 — Castle, tiles 1–4** — the most common battlefield.
- **Phase 3 — bridge/water (5–6) for forest + castle** — the world map for the two shipped biomes.
- **Phase 4 — Desert, Tundra, Volcanic, Swamp, tiles 1–4** — the four new battlefields, in that
  order. Each is a distinct tactical floor, not a reskin, so each needs to read as its own place.
- **Phase 4b — Colosseum, tiles 1–4** — small, and worth pulling forward if the schedule allows: the
  prologue's climax is fought on it, so it is the first floor a new player ever looks at.
- **Phase 5 — bridge/water (5–6) for those four + the full Underworld biome.**

## Licensing

**Full commercial rights / work-for-hire buyout** — use in a commercial game and its marketing, no
project-count limit. **100% human-authored, no AI-generated content.** Credit welcome, not required.
