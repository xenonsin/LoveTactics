# Board Sprites — Commission Brief

A hand-off brief for commissioning the game's on-board unit sprites: the characters that stand and
fight on the tactics grid. Everything a delivered painting needs to drop straight into the game
is here. Deeper character context — personalities, story roles, faction looks — lives in
[story.md](story.md), and the matching dialogue portraits (a separate commission) in
[commission-portraits.md](commission-portraits.md).

## The project

**LoveTactics** — a 2D tactics RPG. Tone: **bright heroic fantasy**, not grim-dark. Battles play out
on a grid of ~60px tiles, where each combatant is a small sprite that idles, moves, attacks, takes
hits and falls — the readable, lively unit art of a game like *Fire Emblem Heroes*.

## What we're commissioning

**One painted still per combatant — and there are 153 of them.** Regenerate that figure with
`& "E:\LOVE\lovec.exe" . art-report` rather than trusting any number typed here.

**You are not animating anything.** The motion is already built, in code: idle, move, attack, hit,
cast and death are transform curves the game applies to whatever picture it is given. What we need
from you is the body, in one pose, painted well.

> **This brief used to ask for Spine rigs** — ~10 skeletons with 191 skins over them, mesh
> deformation, Spine Professional, and a per-artist editor licence. That is withdrawn. The deciding
> fact is the display size below: **~52px on a 60px tile**, where mesh deformation is sub-pixel. The
> *Fire Emblem Heroes* reference misleads — those sprites are displayed huge on a phone, which is what
> pays for the rigging. **Painting labour is identical either way**, so the rig was pure surcharge.

**This is the whole character art budget.** There is no separate portrait commission — see
[The board still is also the portrait](#the-board-still-is-also-the-portrait) — so these are the only
painted character art the game will have, and every place a person appears is one of them.

## Art direction

- **Style: anime, bright fantasy.** Clean line, saturated but not garish, expressive. **Not pixel
  art** — author above final size and downscale.
- **Fire Emblem Heroes-style *bodies*.** The liveliness comes from the code's motion; what the painting
  owes is a pose with weight in it — planted, ready, never a stiff paper doll.
- **One consistent cast.** Shared rendering style, line weight and proportion across all 153, and
  matched to the dialogue portraits of the named characters. Units are compared side by side on the
  board, so a mismatch reads immediately.
- **Readable small, and readable darkened.** The sprite is displayed around 52px tall. Silhouette and
  key colours must carry at that size, and must still read when the sprite is **greyed / desaturated**
  (fallen and inactive states tint it down). Avoid identity resting on fine low-contrast detail.
- **Human-made only:** **no AI-generated content.** A contractual requirement, not a preference.

## The board still is also the portrait

The game tells its story visual-novel style, with a standing figure over a dialogue box at **470px
tall**. There is no separate portrait commission: **that figure is the board still**, posed.

This has one hard consequence for authoring, and it cannot be retrofitted:

- **Author at portrait scale, not board scale.** The board draws a unit at ~52px.
  A picture authored for 52px and scaled up 9x to fill a dialogue box is a blurred mess. Author the source
  art large and deliver a file that stays crisp at **470px tall**, then let the engine downscale for
  the board — the same "never author small" rule as below, taken seriously enough to survive the larger
  of the two sizes.
- **Compose so the figure reads at both sizes.** Silhouette and key colours carry the 52px board read;
  face and costume detail carry the 470px one. Detail that only exists at portrait scale is fine — detail
  the silhouette *depends* on is not.
- **A neutral standing pose is the portrait pose.** No separate portrait artwork is delivered; the
  dialogue box shows the same picture, at rest.

Only the named cast is ever shown in a dialogue box, so if it changes the price, treat portrait-scale
fidelity as a requirement for **Phase 1** and board-scale as sufficient for Phases 2–3.

## Format & delivery

- **One PNG per unit**, transparent background. That is the entire delivery — no project file, no
  atlas, no export step.
- **Name each file to match the unit id** in the roster below (e.g. `general_wrath.png`,
  `dire_bear.png`). It drops into `assets/chars/` and the game picks it up with no wiring.
- **Author at portrait scale** (see above) — deliver **≥1400px tall** so the same picture stays crisp
  in the 470px dialogue box, and let the engine downscale to the board's ~52px.
- **Compose the figure standing on its feet, centred.** The game pivots every animation at the
  **feet** — a body that topples or squashes around its middle reads as a spinning coin — so the
  footprint must sit at the bottom edge of the canvas with no padding under it.
- **Author facing one direction** (screen-right by convention). The game mirrors the sprite for units
  facing the other way, so it need not be drawn both ways.
- **A neutral standing pose.** The code supplies motion; what it needs is a body at rest that reads as
  ready, not mid-swing.

## Technical spec

- **Display size:** ~52px tall on a 60px tile (the game runs in a fixed 1280×720 logical space). Author
  well above that and let the engine downscale; never author small.
- **Large units:** a few enemies occupy a **2×2 footprint** (e.g. the ogre) and are drawn at roughly
  twice the size — we'll mark which in the roster. Compose those to read as genuinely larger bodies.
- **Transparent** throughout; no baked background, ground shadow, or tile.
- No baked team colour or selection frame — the game draws allegiance rings and highlights itself.

## The roster (153)

Unit ids match the game's data files; see [story.md](story.md) for who each character is. Suggested
phasing runs most-seen first. **The lists below are not the whole 153** — they are the named bodies of
each phase; `& "E:\LOVE\lovec.exe" . art-report missing` prints the current full set, and it is the only
figure that cannot go stale.

### Phase 1 — the named cast (~18)

The player's own party and the story's antagonists — the faces on screen every battle.

| id | Who |
|---|---|
| `avatar_1` (+ a gender variant) | The player's created hero |
| `knight` | Rowan — the knight, front-line guard |
| `saber` | The gladiator |
| `kaya` | The hunter — ranged |
| `gyeom` | The mage |
| `amana` | The priest/acolyte — support |
| `ren` | The alchemist |
| `clem` | The rogue — glass-cannon skirmisher |
| `general_wrath` | Ira, the Unappeased |
| `general_sloth` | Acedia, the Unrelieved |
| `general_pride` | Sublimitas, the Unequalled |
| `general_lust` | Luxuria, the Unbidden |
| `general_greed` | Aurea, the Ever-Owed |
| `general_gluttony` | Gula, the Unsated |
| `general_envy` | Livia, the Unborn |
| `demon_lord` | The Hollow Crown — the final boss |

### Phase 2 — the named human enemies (9)

Recurring foes that must match the cast's style.

> `bandit` · `bandit_chief` · `bastion_sworn` · `caravan_master` · `champion` ·
> `forsworn_captain` · `forsworn_knight` · `ordnance_sentry` · `warlord`

The generic soldier types — `knight`, `mage`, `archer`, `priest` — also need a painting as the game's
rank-and-file stand-ins; they can be plainer than the named cast.

### Phase 3 — the creatures (~78)

Beasts, elementals, undead, demons and constructs — 23 + 12 + 6 + 15 + 15 by the roster's own `kind`
field, plus the 7 inanimate objects below. Most are non-humanoid, and a shared body plan carries a whole
group: the beasts on four legs read as one family, the amorphous ones as another. The six elementals are
one body recoloured, and should be quoted that way.

> `boar` · `dire_bear` · `hawk` · `pig` · `stag` · `wolf` · `wolf_alpha` ·
> `earth` / `fire` / `ice` / `lightning` / `water` / `wind` elementals ·
> `demon_grunt` · `demon_imp` · `zombie` · `ogre` *(2×2)* · `crucible_golem` · `homunculus` ·
> `miller_ghost` · `blightstake` · `gaunt_vigil` · `wolfsong_spirit` · … and the rest, from `art-report`

### Phase 4 — the objects (7)

`banner` · `march_standard` · `straw_sentry` · `totem` and three others. Inanimate things that stand on
the board and can be destroyed. They barely move at all: a sway, a hit reaction
and a topple. Cheapest group in the game and worth quoting separately.

## Licensing

**Full commercial rights / work-for-hire buyout** — use in a commercial game and its marketing, no
project-count limit. **100% human-authored, no AI-generated content.** Delivery includes the layered
source (PSD or equivalent) so a body can be revised without repainting it. Credit welcome, not required.

There is **no tooling requirement on either side** — no editor licence to hold, no runtime licence to
ship. A PNG is the whole contract, which also means we are not restricted to artists who own or know a
particular package.
