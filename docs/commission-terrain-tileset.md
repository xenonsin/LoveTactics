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

Each biome = **6 tile types** (the battle board uses **1–4**; the world map uses all six). Order is
the engine's index:

| # | type | role | forest | castle | underworld |
|--|--|--|--|--|--|
| 1 | forest | fill / obstacle | dense canopy | stone-wall block | black basalt block |
| 2 | grass | fill | grass | mossy stone | cooled slag |
| 3 | rock | obstacle | rock / boulder | lighter masonry | broken stone |
| 4 | path | traversable | dirt trail | flagstone corridor | ash underfoot |
| 5 | bridge\* | traversable | timber bridge | timber drawbridge | span of fused bone |
| 6 | water\* | obstacle | river / water | moat | river of fire (lava) |

\* **bridge & water are world-map only — not drawn on the battle board.** Battle-critical tiles are
**1–4**. Each biome must read as a **different place**: leafy forest vs cold castle stone vs
volcanic underworld.

## Scope & phasing (suggested)

- **Phase 1 — Forest, tiles 1–4** — proof of style on one battlefield.
- **Phase 2 — Castle, tiles 1–4** — the most common battlefield.
- **Phase 3 — bridge/water (5–6) for both + the full Underworld biome** — for the world map and the
  underworld quest.

## Licensing

**Full commercial rights / work-for-hire buyout** — use in a commercial game and its marketing, no
project-count limit. **100% human-authored, no AI-generated content.** Credit welcome, not required.
