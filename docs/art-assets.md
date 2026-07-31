# Art assets

Every image the game can ask for, what it must be, and where it comes from. The game runs fine
without any of it — `models/sprite.lua` resolves a missing file to its path string instead of
crashing — so **the art debt is invisible unless it is written down**. This file is where it is
written down.

Two halves, deliberately split so neither can rot:

- **This doc holds the decisions** — sizes, sourcing, style rules, the artist brief.
- **`tools/art_report.lua` holds the counts.** Never retype a number here from memory:

```powershell
& "E:\LOVE\lovec.exe" . art-report           # summary by bucket
& "E:\LOVE\lovec.exe" . art-report missing   # ... and the outstanding filenames
```

It sweeps every `assets/...` literal in the source and checks it against disk, so the moment a
file lands the count moves on its own. Paste a fresh summary into the snapshot below when it does.

## Snapshot

As of 2026-07-30 — **735 of 806 present**, 71 outstanding. Regenerate with the command above.

`chars/` is now full, but with **composed placeholder tokens**, not painted art — every character
blueprint resolves to a file so nothing renders as the bare letter fallback, yet the animated-character
work below is still owed. See [Composed tokens](#composed-tokens--the-budget-stand-in-same-philosophy-as-items):
`char-compose assets` fills the gaps and skips any id that already has real art, so a delivered board
sprite (a **Spine rig**) dropped in later transparently replaces its token. Each of the 37 **discipline exemplars** now carries its
own sprite path and its own silhouette (a `DISCIPLINE_SILHOUETTE` tier in `tools/char_compose.lua`, keyed
off the discipline's `exemplar`), so a Necromancer no longer wears the plain mage token — see
[Composed tokens](#composed-tokens--the-budget-stand-in-same-philosophy-as-items).

| Bucket | Have | Needed | Rendered at | Source |
|---|---|---|---|---|
| `items/` | 583 | 619 | 64px cell | **composed from tags** — [icon system](#the-permanent-icon-system--compose-dont-commission) ✅ |
| `chars/` | 94 | 94 | ~52px on a 60px tile | **Spine rigs (commission)** — composed tokens stand in until each rig lands; see [Characters](#characters) |
| ~~`hazards/`~~ | — | — | 64px tile, under units | **no art, ever** — [drawn by a shader](#hazards-are-not-icons) ✅ |
| `portraits/` | 0 | 17 | 470px tall standing figure | **commission** |
| `vendors/` | 0 | 8 | shop panel | **commission** |
| `traps/` | 6 | 6 | 64px tile | game-icons.net ✅ |
| `overworld/` | 0 | 4 | tilesheet, see [Terrain](#terrain) | GameDev Market |
| `materials/` | 3 | 3 | 64px cell | game-icons.net ✅ |
| `props/` | 2 | 2 | 64px tile | game-icons.net ✅ |
| `hub/` | 0 | 1 | 1280×720 | **commission** |
| `fonts/` | 4 | 4 | — | `ui.ttf`, not art |
| `audio/` | 43 | 48 | — | see [audio-assets.md](audio-assets.md) |

The icon pipeline and the composed character tokens are **complete**; the 71 outstanding are the buckets
that still need a human hand: painted portraits, vendors, backgrounds, terrain, and the last audio. The
composed `chars/` tokens stand in until an animated **Spine rig** replaces each one (see
[Characters](#characters)).

> **`chars/` is mid-migration to a new asset type.** A composed token is a single flat PNG, but a board
> rig is a skeleton (`.json`/`.skel`) + `.atlas` + page PNG(s). The 94/94 count above is still the
> composed-token PNGs; the `art-report` sweep will need a rule for the rig triple before it can count
> real board art (see [Code follow-ups](#code-follow-ups-wiring-a-rig)).

`tests/` is excluded from the sweep — a spec's stand-in sprite path exists to prove the tolerant
loader survives a missing file, so it is not art anyone owes.

## Direction

Bright fantasy, **not** grim dark. Portraits in anime style. **This is not a pixel-art game** —
author above final display size and downscale; never upscale a small source.

Board units are **Fire Emblem Heroes-style animated sprites** — hand-rigged in **Spine** (skeletal
mesh, not pixel art, not a flipbook), style-matched to the painted dialogue portraits so a unit and
its portrait read as the same character. See [Characters](#characters) and the hand-off brief in
[commission-board-sprites.md](commission-board-sprites.md).

### The two-register rule

The board carries two visual registers, and they must not bleed into each other:

- **The character layer** (unit sprites) is *painted and animated* — a Spine rig per unit.
  Everything standing on the board is drawn in one style, because units are compared against each
  other side by side in the same role. A static composed token beside an animated rig does not read
  as a style choice — it reads as unfinished art, which is exactly why composed tokens are only ever
  interim (see [Composed tokens](#composed-tokens--the-budget-stand-in-same-philosophy-as-items)).
- **The overlay layer** (hazards, traps, ground marks) is *graphic*. These sit **under** the units,
  semi-transparent, and read as marks on the ground rather than things standing on it. A flat,
  symbolic treatment here is a deliberate choice tactics games make constantly.

The rule is **never mix registers within a layer**. If one hazard is a painted flame, all of them
are. If they are icons, all of them are icons.

Item icons sit outside this entirely: no item or ability sprite is ever drawn on the battlefield
(`ui/battle_map.lua` draws terrain, hazards, traps, walls, props and units; status badges are
plain rects). They appear only in panel and inventory surfaces, so they never sit beside a
portrait in the same role.

## Characters

Every combatant on the board (~55) is slated for its own **animated Spine rig** — that is the whole
`chars/` bucket, and its hand-off brief is [commission-board-sprites.md](commission-board-sprites.md).
The named cast *also* has a static dialogue portrait in `portraits/`, but the two are now **separate
assets**, not a crop relationship (see below). Until a unit's rig is delivered it shows a
[composed token](#composed-tokens--the-budget-stand-in-same-philosophy-as-items).

### The named cast — rig and portrait are separate now

The named cast appears in both `portraits/` (dialogue) and `chars/` (board). These used to be **one
asset**: the board sprite was a square head crop of the commissioned portrait. **That coupling is
retired.** The board sprite is now its own **Spine rig**, authored independently — so the portrait no
longer has to reserve headroom or keep weapons clear of the face for a crop, and there is no
crop-and-export step. The rig owns the board; the portrait owns the dialogue box.

> amana · avatar_1 · clem · gyeom · kaya · knight · ren · saber ·
> general_envy · general_gluttony · general_greed · general_lust · general_pride · general_sloth ·
> general_wrath · demon_lord

(`archer` / `mage` / `priest` are the retired generic classes — kept as enemy/test stand-ins, owed no
portrait; see [commission-portraits.md](commission-portraits.md). They still get a board rig like any
other combatant.)

### Creatures — 24, rigged (Phase 3)

Beasts, elementals, demons, undead and constructs — the largest rig group, and the last phase in
[commission-board-sprites.md](commission-board-sprites.md). Rigged in the same register as the cast so
they sit beside it rather than fighting it. Purchased still-art packs (e.g. NATHUHARUCA, see
[Sourcing](#sourcing)) remain useful as **reference / an interim still** for a creature awaiting its
rig, above the composed token — but the board's end-state for every creature is a Spine rig.

> boar · dire_bear · hawk · pig · stag · wolf · wolf_alpha · earth/fire/ice/lightning/water/wind
> elementals · demon_grunt · demon_imp · demon_lord · zombie · ogre · crucible_golem · homunculus ·
> miller_ghost · blightstake · gaunt_vigil · wolfsong_spirit

### Human enemies — 9, rigged (Phase 2)

No portrait, but they must match the cast. These are now **full rigged figures**, not the square busts
they once were — they moved wholesale into [commission-board-sprites.md](commission-board-sprites.md)
when the board went animated.

> bandit · bandit_chief · bastion_sworn · caravan_master · champion · forsworn_captain ·
> forsworn_knight · ordnance_sentry · warlord

### Objects — 4, static, from the tileset packs

Inanimate, so they are exempt from the character-layer rule and stay **static** (not rigged) —
they should match the *terrain*, not the cast.

> banner · march_standard · straw_sentry · totem

### Composed tokens — the budget stand-in, same philosophy as items

Every one of the ~55 is awaiting a rig, and a nameless enemy or a background creature may wait a long
time. None of them sit meanwhile as the bare initial-in-a-disc fallback (`ui/battle_map.lua`
drawUnits): they get a **composed token**, drawn as a pure function of fields the
blueprint already carries — exactly the way an item's icon is a function of its family/element/class
([The permanent icon system](#the-permanent-icon-system--compose-dont-commission)) and a hazard's picture
is a function of its `fire`/`ice` tag.

```powershell
& "E:\LOVE\lovec.exe" . char-compose            # every character -> vendor/compose-preview/chars/
& "E:\LOVE\lovec.exe" . char-compose assets      # publish into assets/chars/, skipping ids with real art
& "E:\LOVE\lovec.exe" . char-compose assets force # ... and overwrite even where real art exists
```

`tools/char_compose.lua` composes four layers, four data channels:

| Layer | Channel | Source |
|---|---|---|
| **Base** silhouette | a **discipline** match (the exemplar), then a creature/name match, then a **`kind`** bucket | game-icons.net (reuse, not commission) |
| **Tint** | element (elementals), else kind | — |
| **Frame** | `class` colour (the vendor shelf), gold + thicker for a boss | shared with the item composer |
| **Badge** | a gold disc for a `boss`/general | — |

A classless boss — the seven sin generals are `boss = true` with no `class` — would otherwise be a rank
swordman told apart only by its frame, so it is lifted to an **overlord silhouette** (a horned helm). A boss
that *has* a class keeps its role look (priest-boss Amana still reads priest) and a boss that is a demon or
beast keeps its creature; only the generic humanoid is lifted. The guessing is regression-guarded headlessly
by `tests/char_compose_spec.lua` — pure logic, no render — the way the item pipeline guards its family picks.

`kind` (humanoid · beast · elemental · construct · demon · undead · object) is the character analog to an
item's **family** — the one field that decides the silhouette. It is *guessed* from the blueprint (a
`class` says humanoid; the id's own words say the rest) and **corrected with one line**, `kind = "beast"`,
the same "guess, then override" split the icon pipeline uses. No mass edit of blueprints.

**One tier sits above the creature/`kind` guessing: the discipline.** `class` picks a whole shelf's body
(all seven mage-disciplines would otherwise share the wizard), so a `DISCIPLINE_SILHOUETTE` table gives
each of the 37 disciplines its own game-icons shape (a Necromancer's skull-staff, a Warlord's banner). It
fires only for a discipline's `exemplar` character — keyed off the pointer in `data/disciplines/*.lua`, not
a loose substring, so a `demon_champion` is never mistaken for the Champion — and a boss exemplar keeps its
discipline body while still earning the gold badge (`warlord` → banner, not the overlord lift). The picks
were reviewed shape-by-shape; `tests/char_compose_spec.lua` guards them.

Like `icon-build`, `assets` mode **skips any file already on disk**, so real board art dropped in later
is never overwritten — and it writes to the exact `def.sprite` path (not `<id>.png`), so a shared file
(`demon_bomblet` → `demon_imp.png`) is composed once and every borrower rides along on it. A composed token
is a placeholder in the painted register, so it is deliberately **not** committed by default: the plain run
lands in `vendor/compose-preview/chars/` for review, and only the explicit `assets` arg publishes.

## Terrain

⚠️ **Fix before buying:** every tileset declares `tileSize = 16` (`data/tilesets/*.lua`,
`models/tileset.lua`), and `ui/battle_map.lua` computes `tileScale = self.size / ts` — a 60/16 =
**3.75× upscale**. That is pixel art whether or not it was meant to be. Author at **128px** and set
`tileSize = 128`; the scale is computed, so this is a data-only change.

The battle board and the overworld **share one tilesheet**. `ui/battle_map.lua` maps arena tile
types onto overworld tileset types (`ground→path`, `forest→forest`, `mountain/obstacle→rock`,
`rough→grass`), so one set of tiles dresses both surfaces.

3 biomes (`castle`, `forest`, `underworld`) × 6 types (`forest`, `grass`, `rock`, `path`,
`bridge`, `water`) = **18 tiles**. The board only ever shows 4 of the 6 — `bridge` and `water` are
overworld-only — but the map needs all six.

## Traps

6 icons on the overlay layer, at 64px. Sourced from game-icons.net.

**Hazards need no art at all** — they are drawn procedurally by the field shader. See
[Hazards are not icons](#hazards-are-not-icons); nothing in `data/hazards/` names a sprite, and
`assets/hazards/` is not a bucket anybody owes anything to.

## Sourcing

Two hard constraints: **commercial use must be permitted**, and **no AI-generated art**.

| Source | Covers | Terms |
|---|---|---|
| [game-icons.net](https://game-icons.net/) | items, hazards, traps, materials | CC BY 3.0 — **attribution required** |
| [GameDev Market](https://www.gamedevmarket.net/) | terrain, props | Pro Licence; platform bans generative AI outright |
| [NATHUHARUCA MEGA MONSTER PACK](https://plaza-us.komodo.jp/products/nathuharuca-mega-monster-pack) | interim creature stills / reference | "Engine of your choice", commercial OK, editable |
| Commission — **Spine rigs** | all ~55 board sprites — [commission-board-sprites.md](commission-board-sprites.md) | full commercial buyout, no AI; **[Spine tooling](#spine-tooling--a-real-cost)** below |
| Commission — portraits | dialogue portraits, vendors, hub | — |

### Spine tooling — a real cost

The board rigs are a paid pipeline, not a free asset source, and that belongs alongside the
"commercial use / no AI" constraints:

- **Spine Editor licence per rigging artist.** [Spine](https://esotericsoftware.com/) (Esoteric
  Software) is commercial software; every artist who *creates or exports* a rig needs a licence
  (Essential or Professional — mesh/weights, which the FEH look wants, is Professional).
- **`spine-love` runtime licence.** The official LÖVE runtime is free to use, but the **Spine Runtimes
  Licence** requires that anyone shipping the runtime hold a valid Spine Editor licence. Budget the
  editor seat(s) as part of the commission, not an afterthought.

### Attribution obligation

game-icons.net is CC BY 3.0 and covers the majority of the file count. A credits screen must name
**"Lorc, Delapouite & contributors"** with a link to game-icons.net. This is a licence condition,
not a courtesy — build the credits panel early rather than at ship.

### Rejected, and why

- **AI-generated packs** — AssetSmithy, cogabushi and Vill8tion all disclose generative AI.
  Excluded by direction.
- **NoranekoGames** — hand-drawn and AI-free, but CC BY-NC-SA. The non-commercial clause rules it out.
- **Knickknack PJ** — states only "free to use", with no licence named. Ambiguous terms are not a
  basis for shipping.
- **RPG Maker DLC (Steam)** — the per-pack EULA grants "engine of your choice", but the Steam SKUs
  require owning RPG Maker MZ to install, and the umbrella Gotcha Gotcha Games material terms limit
  use to individuals and small indie circles, excluding corporations. Buy standalone from KOMODO
  Plaza instead, which is how the NATHUHARUCA pack above qualifies.

## Artist brief

Two separate commissions now — the board rigs and the dialogue portraits are independent assets. The
full hand-off for each lives in its own doc; the summary:

**Board sprites (~55)** — animated **Spine rigs**, one per combatant, displayed at ~52px on a 60px
tile (`ui/battle_map.lua`). Full spec in [commission-board-sprites.md](commission-board-sprites.md):
skeleton + atlas + page PNG delivery, the required animation set (idle/walk/attack/hit/cast/death),
multi-cell scaling, and the Spine tooling/licence note above.

**Portraits (17)** — static standing figures for the dialogue box, anchored bottom-centre, displayed
at 470px tall (`ui/dialogue.lua`). Full spec in
[commission-portraits.md](commission-portraits.md). Deliver **≥1400px tall** and keep the cast
consistent in style and proportion. (The old head-crop constraints — headroom, weapons clear of the
face, uniform head height, a layered crop guide — are **retired**: the portrait no longer feeds the
board token, so it only has to serve the dialogue box.)

**Vendors (8) and hub city (1)** — panel and background art; the hub is 1280×720 logical
(`scale.lua`), so author at 2× and downscale.

## Code follow-ups (wiring a rig)

Producing the rigs is decoupled from wiring them — art can be authored against the brief before any
of this exists. When the first rig lands, wiring it takes:

- **Vendor the `spine-love` runtime** (official Esoteric LÖVE runtime); mind the Spine Runtimes
  Licence ([Spine tooling](#spine-tooling--a-real-cost)).
- **A skeleton-vs-texture branch at the three board draw sites** — `ui/battle_map.lua` `drawUnits`
  and `drawFallenSprite`, and `ui/combat_panel.lua`'s portrait square. Each today does
  `love.graphics.draw(u.char.sprite, …)` on a static texture; when a unit's art is a Spine skeleton,
  render it through the runtime instead.
- **Map animation states onto the existing fx signals** so a rig needs no new model plumbing:
  idle/walk from `fx:spriteState` (walk-slide offset), attack/hit from the lunge + hit-flash,
  arrivals from `materialize`, death from `fade`/dissolve.
- **Decide the shader interaction** — the dissolve/materialize/grayscale sprite shader
  (`shaders/sprite.lua`) currently wraps one textured quad. Either apply it to the skeleton's meshes
  or let a rig's own `death` clip replace it.
- **Tolerant loader + report** — a rig loader analogous to `models/sprite.lua` (a missing rig falls
  back to the composed token, never a crash), and an `art-report` rule that counts the rig triple
  (`.json`/`.skel` + `.atlas` + page PNG) rather than a lone PNG (`tools/art_report.lua` `ORDER`).

## The icon pipeline

Icons are not hand-placed — they are rendered from game-icons.net by a three-step pipeline. Nothing
third-party is committed; `vendor/` is gitignored and reproducible. `assets/` is gitignored too:
item icons are regenerated with `. icon-compose assets` (see [The permanent icon
system](#the-permanent-icon-system--compose-dont-commission)), and `models/sprite.lua` tolerates a
missing file — a fresh clone simply shows no icons until the composer runs.

```powershell
powershell -ExecutionPolicy Bypass -File tools\icons\fetch.ps1   # once: SVG sources + resvg
& "E:\LOVE\lovec.exe" . icon-map                                 # propose an icon per asset
& "E:\LOVE\lovec.exe" . icon-build                               # render the mapping into assets/
```

| Step | Does | Writes |
|---|---|---|
| `fetch.ps1` | clones ~4200 CC BY 3.0 SVGs, downloads the pinned resvg rasterizer | `vendor/` |
| `icon-map` | token-matches each asset name against the icon set | `tools/icons/map.lua` |
| `icon-build` | recolors onto transparency, rasterizes at 128px | `assets/`, `docs/credits-icons.md` |

### The mapping is the work

Rendering is mechanical; deciding that `ability_bear_trap` should be drawn with `lorc/mantrap` is a
judgement call 500 times over. `icon-map` guesses and a human corrects. Four things do the guessing:

**1. The head noun.** English compounds put the depicted thing last, so the last word is weighted
double: a *bellfounder's hammer* is a hammer, a *falconer's glove* is a glove. Without this, a vivid
modifier drags the match onto the wrong object.

**2. Synonyms** (`SYNONYMS` in `tools/icon_map.lua`). game-icons.net has no *aegis*, *censer* or
*blink* — it has shields, incense and teleports. Without this layer those score zero against all
4180 icons. Add a row rather than hand-mapping the same idea repeatedly: `censer` alone covers nine
items, `fists` seven. A row also catches every future item using the word, which a hand-edit cannot.

**3. Compound splitting.** This project writes compounds closed — `rimecloth`, `stormcloth`,
`witchlight`, `powershot` — and a closed compound is one token that matches nothing. Splitting on
the icon set's own vocabulary recovered 17 items that were failing purely on spelling.

**4. Archetype tags.** An item's *name* says what it means; its *tags* say what it **is**. "Sworn
Lance" and "Thin Place" match no icon by name, but their `spear` and `dagger` families do. Name and
family are scored **separately and combined by taking the better of the two** — an early version
folded the family into the same denominator, which diluted a zero rather than rescuing it and cost
the pikes and lances matches they should have won. Only `Item.ARCHETYPES` tags are used; `physical`
and `melee` are mechanics that would add noise to every score without naming a picture.

Where nothing still scores well enough it writes `icon = false` rather than inventing a match.

### The register blocklist

game-icons.net is a general-purpose set — it has bowling, lab coats and the Arc de Triomphe next to
the swords, and substring matching finds them cheerfully. A review of all 409 auto-matches turned up
*Power Strike* on `bowling-strike` (shared with eight other strikes), *Boots of Speed* on
`speed-boat`, *Confessor's Needle* on `space-needle`, and five coats on `lab-coat`.

`BLOCKED_WORDS` in `tools/icon_map.lua` drops those icons from the index entirely — ~230 of 4180 —
so they cannot be matched by accident. The test for adding a word is **"could this object exist in
this game's world?"**, not "do I like this icon?". Firearms are blocked because this game's ranged
weapons are bows.

One trap worth remembering: the blocklist checks the raw hyphen-separated slug, not the matcher's
tokens. Tokens keep letters only, so `3d-hammer` tokenizes to `{ "d", "hammer" }` — a `3d` entry
checked against tokens silently never fires, and every maul in the game kept its 3D-modelling icon.

### Known limitation: icon reuse

227 distinct icons cover 513 assets. Twenty items share `shield`, fifteen share `fist`, thirteen
share `incense`. That is inherent — the game has nine censers and game-icons.net has one — and it
means **the icon alone does not identify an item** in a full inventory. Tooltips and names carry
that weight today. If the ability bar ever needs to be readable at a glance, the fix is a per-class
tint or a small badge, not 500 unique icons.

### Correcting a guess

Hand-picked icons live in **`tools/icons/overrides.lua`**, not as edits to the generated map — so
human decisions sit in one reviewable diff and cannot be lost to a regeneration bug. An override
wins over any guess and is written into `map.lua` as `by = "hand"`.

```lua
["items/ability_banish.png"] = "magic-portal",   -- by name; the artist is looked up for you
["items/kingsfall.png"]      = "lorc/crown-coin", -- or fully qualified
```

Naming an icon that does not exist is **reported as an error**, not skipped silently, so a typo
cannot quietly cost an item its art.

`by = "auto"` entries in `map.lua` are guesses and get overwritten on the next run; that is what
makes the pipeline safe to re-run as new items are added.

`icon-build` also **skips files already on disk** unless you pass `force`, so purchased or
commissioned art that has replaced a generated icon is never overwritten.

### Colour is baked in at render time

Not a runtime tint: baking lets each icon take its own colour at export, which beats a blanket
per-bucket `setColor` and costs nothing (game-icons.net's editor exports coloured PNGs).

| Bucket | Colour |
|---|---|
| `items/`, `materials/`, `props/` | `#e9e2d0` warm off-white |
| `traps/` | `#f0b8a8` |

The `badges/` author folder is excluded from matching: those 59 are 256px medallions on a filled
circle, where the other 4180 are line icons on a 512px canvas. One badge in a panel of icons reads
as a mistake, not a variation.

### Hazards are not icons

Deliberately outside the pipeline. A hazard is a patch of **ground** — fire spreading across tiles,
rain falling on them — and a centred line-art glyph reads as an object dropped on the board rather
than a condition covering it.

This bucket used to sit here as an open commission for 24 pieces of painted, tileable, **edge-aware**
art in the terrain's register. **That commission is closed, and it was never placed.** Hazards are
drawn procedurally instead, by one pixel shader with ten patterns (`shaders/field.lua`, driven by
`ui/field_fx.lua`), which buys every property the brief asked for and several it could not have:

- **Tileable and edge-aware by construction.** The shader samples its noise in *board* space and is
  told which of a tile's four sides are actually the footprint's boundary, so a 3×3 blessing is one
  continuous patch of ground with a soft rim, not nine separately-feathered squares.
- **It stacks.** Painted art occludes; a field composites. Rain drifting over a Sanctuary shows both,
  which is what the model always supported (`Hazard.allAt`) and the picture never could.
- **It is alive.** A field blooms in when it is laid and thins out as its duration runs down, so
  a fire about to gutter out looks like one.
- **No per-hazard cost.** A new zone gets its picture from the tags it already declares for
  mechanical reasons (`fire` → flame, `ice` → rime). Adding the 25th hazard commissions nothing.

The same shader also dresses the statuses a unit carries and the footprint an armed ability
telegraphs, off that one tag table — see [architecture.md](architecture.md#zones-and-auras).

Sprites for hazards are gone entirely: no blueprint names one, `models/hazard.lua` loads none, and
there is no fallback-to-art path to keep alive. The only fallback is `FieldFx:drawFallback`, the old
flat disposition wash, kept for a machine whose driver refuses the GLSL.

### Attribution is not optional

`icon-build` regenerates `docs/credits-icons.md` listing exactly which artists shipped and how many
icons each. CC BY 3.0 requires this reach **players**, not just the repository — it belongs on the
credits screen. See [Attribution obligation](#attribution-obligation).

## The permanent icon system — compose, don't commission

**This is the shipped item-icon system.** Every file in `assets/items/` is composed at build time by
`tools/icon_compose.lua` (`. icon-compose assets`) from tags the blueprint already declares — the
`icon-build` game-icons.net recolour was a *sourcing stage*, and this replaced it as the final look.

No item's identity was ever carried by a unique drawing. It is carried by a handful of fields:

- **family** — 15 total (`Item.ARCHETYPES`): sword, greatsword, axe, mace, hammer, dagger, spear,
  bow, longbow, staff, wand, shield, censer, unarmed, natural.
- **type** — `weapon` / `ability` / `armor` / `utility` / `material`.
- **element / strike** — the damage tag (`slash`, `fire`, `ice`, …) already on `tags`.
- **class** — the vendor shelf (`fighter`, `rogue`, `priest`, …), ~7.
- **tier** — the item's `repRank`.

The Carrion Axe *is* axe + slash + fighter; the Culling Stroke *is* slash + fighter + barbarian. The
picture is a pure function of those tags — exactly as a hazard's picture is a function of its
`fire`/`ice` tag. So the icon is **composed from tags at build time, not drawn.**

### The four layers — and the legend

Each icon is `base silhouette × element tint × class frame × type-and-tier badge`. The four layers map
to four data channels; the colour tables below are the single source of truth alongside the
`CLASS_COLOR` / `TYPE_COLOR` / `ELEMENT_TINT` tables in `tools/icon_compose.lua` — **keep them in
sync**.

**1. Base silhouette — the item's family (or type, for typeless items).** One of 15 canonical
game-icons shapes (a broadsword, a battle-axe, a wizard-staff…). An ability/armor/utility/material
owns no weapon family, so it falls back to a type shape (ability → magic-swirl, armor → breastplate,
utility → flask, material → gems).

**2. Tint — the element/strike tag** recolours that silhouette. A physical strike or no element at
all lands on steel.

| Element tag | Tint |
|---|---|
| `fire` / `burn` | orange `#ef7d4a` |
| `ice` / `frost` | light blue `#7fc6ec` |
| `lightning` / `shock` | yellow `#f3d24a` |
| `holy` / `radiant` / `light` | pale gold `#f2e6a8` |
| `shadow` / `dark` | purple `#a279c9` |
| `poison` / `nature` | green `#8fbf5a` |
| `arcane` | violet `#b98fe0` |
| *(physical / none)* | steel `#dce1e6` |

**3. Frame — the class (vendor shelf) colour**, a rounded border that **thickens with tier**
(`12 + repRank·4` px).

| Class | Frame |
|---|---|
| fighter | red-orange `#c0562f` |
| rogue | green `#6f9a52` |
| mage | blue `#6f82d4` |
| ranger | teal `#4f9a86` |
| priest / cleric | gold `#d8c15f` |
| *(none)* | grey `#9aa0a8` |

**4. Badge — the type**, a corner disc top-right; plus **tier pips**, a row of `repRank` diamonds
along the bottom in the class colour. So *four green pips + green frame* reads as *a rank-4 rogue item*
at a glance.

| Type | Badge disc |
|---|---|
| weapon | orange `#c9603a` |
| ability | purple `#8a6fd0` |
| armor | blue `#5f8fb0` |
| utility / consumable | green `#6fae72` |
| material | brown `#b0894f` |
| *(other)* | grey `#888e96` |

### How it's built

`icon-compose` is the fourth pipeline verb beside `icon-map` and `icon-build`:

```powershell
& "E:\LOVE\lovec.exe" . icon-compose         # demo spread (one per family + type) -> vendor/compose-preview/
& "E:\LOVE\lovec.exe" . icon-compose all      # every item, preview only (never assets/)
& "E:\LOVE\lovec.exe" . icon-compose assets   # graduate: write each item's OWN sprite path in assets/
```

The `assets` verb writes to each blueprint's **own `sprite` path** (not `<id>.png`) — the game loads
by that path, and the id and sprite basename disagree for ~half the catalogue. It renders only into
`assets/items/`; a sprite pointing elsewhere (e.g. `weapon_talons` borrows `assets/chars/hawk.png`) is
skipped rather than composed over shared art. Output stays **generated**, preserving the one property
that cannot be lost — a new item costs zero art.

### What still gets commissioned

The signature relics (~8 per companion) and the generals' gear are the pieces a player studies in a
panel; those earn bespoke art. `models/sprite.lua` loads by path, so a hand-drawn file dropped at an
item's `sprite` path transparently replaces its composed icon — re-running `icon-compose assets` would
overwrite it, so bespoke art belongs on its own path. Everything else stays composed.

### Why this is not a downgrade

The icon's job here is **category legibility, not identity** — [Known limitation: icon
reuse](#known-limitation-icon-reuse) records that names and tooltips identify an item and that reuse is
inherent and fine. A family + element + class + tier composition delivers exactly the legibility the
panel needs; 500 unique drawings was an artefact of counting items rather than counting meanings.

## Adding new art

1. Reference the path from a data file or widget as usual — a missing file is safe.
2. Drop the image into the matching `assets/` folder.
3. Re-run `art-report` and update the snapshot table above.

If a new bucket appears, add it to `ORDER` in `tools/art_report.lua` so it sorts with the rest.
