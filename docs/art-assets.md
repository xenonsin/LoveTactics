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

As of 2026-07-23 — **513 of 601 present**, 88 outstanding. Regenerate with the command above.

(Was 513 of 625 / 112 outstanding. The 24 hazards left the ledger entirely — they are drawn by a
shader now and reference no files, so the report has no bucket to count. See
[Hazards are not icons](#hazards-are-not-icons).)

| Bucket | Have | Needed | Rendered at | Source |
|---|---|---|---|---|
| `items/` | 502 | 502 | 64px cell | game-icons.net — [pipeline](#the-icon-pipeline) ✅ |
| `chars/` | 0 | 55 | ~52px on a 60px tile | mixed — see [Characters](#characters) |
| ~~`hazards/`~~ | — | — | 64px tile, under units | **no art, ever** — [drawn by a shader](#hazards-are-not-icons) ✅ |
| `portraits/` | 0 | 19 | 470px tall standing figure | **commission** |
| `vendors/` | 0 | 8 | shop panel | **commission** |
| `traps/` | 6 | 6 | 64px tile | game-icons.net ✅ |
| `overworld/` | 0 | 4 | tilesheet, see [Terrain](#terrain) | GameDev Market |
| `materials/` | 3 | 3 | 64px cell | game-icons.net ✅ |
| `props/` | 2 | 2 | 64px tile | game-icons.net ✅ |
| `hub/` | 0 | 1 | 1280×720 | **commission** |
| `fonts/` | 0 | 1 | — | `ui.ttf`, not art |

Everything the icon pipeline covers is **complete**. The 112 outstanding are the buckets that need
a human hand: painted characters, painted hazards, backgrounds, and terrain.

`tests/` is excluded from the sweep — a spec's stand-in sprite path exists to prove the tolerant
loader survives a missing file, so it is not art anyone owes.

## Direction

Bright fantasy, **not** grim dark. Portraits in anime style. **This is not a pixel-art game** —
author above final display size and downscale; never upscale a small source.

### The two-register rule

The board carries two visual registers, and they must not bleed into each other:

- **The character layer** (unit sprites) is *painted*. Everything standing on the board is drawn
  in one style, because units are compared against each other side by side in the same role. An
  iconic token beside a painted face does not read as a style choice — it reads as unfinished art.
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

`chars/` is one folder but four different sourcing problems. 18 of the 55 double as portraits.

### Head crops — 18, free with the portraits

The named cast appears in both `portraits/` and `chars/`. The battle sprite is **a square head
crop of the commissioned portrait** — no separate art. Both draw sites already aspect-fit and
centre a square (`ui/battle_map.lua` `math.min((bw-8)/sw, (bh-8)/sh)`, `ui/combat_panel.lua`
`math.min(ps/sw, ps/sh)`), so a square source fills the cell exactly with no letterboxing and
**no code change**.

> amana · archer · avatar_1 · clem · gyeom · kaya · knight · mage · priest · ren · saber ·
> general_envy · general_gluttony · general_greed · general_lust · general_pride · general_sloth ·
> general_wrath

Crop offline and export to `assets/chars/`. Do **not** crop at runtime: that would mean a head
rect in every blueprint and keeping a ~1500px portrait resident to draw a 52px token.

### Creatures — 24, one pack

Beasts, elementals, demons, undead and constructs. Painted creature art, so it sits beside the
painted head crops rather than fighting them.

> boar · dire_bear · hawk · pig · stag · wolf · wolf_alpha · earth/fire/ice/lightning/water/wind
> elementals · demon_grunt · demon_imp · demon_lord · zombie · ogre · crucible_golem · homunculus ·
> miller_ghost · blightstake · gaunt_vigil · wolfsong_spirit

### Human enemies — 9, commission

No portrait, but they must match the painted cast. **Only the head square is needed** — never a
full standing figure — so these are a fraction of a companion portrait's cost.

> bandit · bandit_chief · bastion_sworn · caravan_master · champion · forsworn_captain ·
> forsworn_knight · ordnance_sentry · warlord

### Objects — 4, from the tileset packs

Inanimate, so they are exempt from the character-layer rule and should match the *terrain*.

> banner · march_standard · straw_sentry · totem

### Composed tokens — the budget stand-in, same philosophy as items

Most of the 55 are portrait-less — a creature, a nameless enemy, an NPC that will never earn a painted
face. Those don't wait on a commission and don't sit forever as the bare initial-in-a-disc fallback
(`ui/battle_map.lua` drawUnits): they get a **composed token**, drawn as a pure function of fields the
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
| **Base** silhouette | a creature/name match first, then a **`kind`** bucket | game-icons.net (reuse, not commission) |
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

Like `icon-build`, `assets` mode **skips any file already on disk**, so a painted head crop dropped in later
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
| [NATHUHARUCA MEGA MONSTER PACK](https://plaza-us.komodo.jp/products/nathuharuca-mega-monster-pack) | the 24 creatures | "Engine of your choice", commercial OK, editable |
| Commission | portraits, vendors, hub, 9 enemy heads | — |

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

Give this to whoever takes the commission — the head crop is load-bearing, so it belongs in the
brief rather than being discovered at delivery.

**Portraits (19)** — standing figures for the dialogue box, anchored bottom-centre, displayed at
470px tall (`ui/dialogue.lua`).

- Deliver **≥1400px tall** so a head crop is still ~300px+ and stays sharp at any future card size.
- **Consistent head height across the whole cast.** Tokens are scaled to fit a square cell, so an
  outsized head shrinks its body and the roster reads at inconsistent scale on the board.
- **Leave headroom above the crown**, and keep weapons, props and hair-wings clear of the face — a
  square crop around the head will catch anything that crosses it.
- Deliver a **layered file or a marked square crop guide**, so crops can be re-cut without going
  back to the artist.

**Enemy heads (9)** — square bust only, ~512px, same style and head scale as the cast above.

**Vendors (8) and hub city (1)** — panel and background art; the hub is 1280×720 logical
(`scale.lua`), so author at 2× and downscale.

## The icon pipeline

Icons are not hand-placed — they are rendered from game-icons.net by a three-step pipeline. Nothing
third-party is committed; `vendor/` is gitignored and reproducible, while the rendered PNGs under
`assets/` **are** committed, so a fresh clone runs without anyone installing the pipeline.

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

The pipeline above is a **sourcing stage, not the final look**: it recolours a shared line-art set
(game-icons.net) and reuses 227 drawings across 513 assets. That reuse is easy to read as a debt to
be repaid by commissioning 500 bespoke icons. It is not — because no item's identity was ever carried
by a unique drawing. It is carried by a handful of fields the blueprint already declares:

- **family** — 15 total (`Item.ARCHETYPES`): sword, greatsword, axe, mace, hammer, dagger, spear,
  bow, longbow, staff, wand, shield, censer, unarmed, natural.
- **type** — `weapon` / `ability` / `armor` / `utility` / `material`.
- **element / strike** — the damage tag (`slash`, `fire`, `ice`, …) already on `tags`.
- **class** — the vendor shelf (`fighter`, `rogue`, `priest`, …), ~7.
- **tier** — derivable from `repRank` / `price` / `discipline`.

The Carrion Axe *is* axe + slash + fighter; the Culling Stroke *is* slash + fighter + barbarian. The
picture is a pure function of tags the item carries — exactly as a hazard's picture is a function of
its `fire`/`ice` tag. So the resolution to the reuse limitation is the one the hazards already found:
**compose the icon from tags at build time; do not draw it.**

### Two moves, either or both

**Composition — the item paperdoll.** `base silhouette (per family, 15) × material/element tint ×
property badge × frame (class colour + tier)`. Fifteen base shapes, tinted and badged, read as
hundreds of distinct icons. Two of the four layers already exist: the `badges/` author folder is 59
medallions — the property-badge layer, already drawn — and colour is already baked at export (see
[Colour is baked in](#colour-is-baked-in-at-render-time)), now keyed on element/class rather than a
flat per-bucket constant. The art this actually needs is **~15 clean family silhouettes, not 500
items**.

**Restyle — the hazard shader, one layer up.** What reads as *temporary* about the current set is the
flat clipart treatment, not the count. One consistent build-time pass over all 502 — bevel, inner
shadow, material fill, a plate behind — makes the whole library cohere as a single house style, and
item #503 inherits it for nothing. Applied on its own this may retire the word "temporary" **without
replacing game-icons.net at all**: the source stays, the look becomes ours.

### What still gets commissioned

The signature relics (~8 per companion) and the generals' gear are the pieces a player studies in a
panel; those earn bespoke art. That surface is dozens, and the roadmap already isolates it (the
signature relics; the 248 items with a bespoke case). Everything else stays composed.

### Why this is not a downgrade

The icon's job here is **category legibility, not identity** — [Known limitation: icon
reuse](#known-limitation-icon-reuse) already records that names and tooltips identify an item and that
the reuse is inherent and fine. A family+element+badge composition delivers exactly the legibility the
panel needs; 500 unique drawings was an artefact of counting items rather than counting meanings.

### Migration

`icon-build` today runs `SVG → recolour → rasterize at 128px`. The permanent form swaps the middle
step for a composer that reads `(family, type, element, class, tier) → base + tint + badge + frame`;
`icon-map` already resolves the family it keys on, so the inputs are the tags the pipeline matches
today. It stays **generated**, which preserves the one property that cannot be lost — a new item costs
zero art. When built it becomes a fourth pipeline verb (`icon-compose`) beside `icon-map` and
`icon-build`, and this section moves from plan to record.

## Adding new art

1. Reference the path from a data file or widget as usual — a missing file is safe.
2. Drop the image into the matching `assets/` folder.
3. Re-run `art-report` and update the snapshot table above.

If a new bucket appears, add it to `ORDER` in `tools/art_report.lua` so it sorts with the rest.
