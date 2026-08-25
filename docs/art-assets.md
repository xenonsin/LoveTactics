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
& "E:\LOVE\lovec.exe" . art-build            # regenerate everything composed, then overlay art/
& "E:\LOVE\lovec.exe" . art-build stale       # ... or just ask whether it needs it
& "E:\LOVE\lovec.exe" . art-source            # how much of what ships is still game-icons.net
```

`art-report` counts **files**; `art-source` counts **drawings**, which is the number a commission is
priced off. They answer different questions and disagree on purpose: a bucket can be "done" on disk and
entirely third-party underneath.

It sweeps every `assets/...` literal in the source and checks it against disk, so the moment a
file lands the count moves on its own. Paste a fresh summary into the snapshot below when it does.

## Snapshot

As of 2026-08-24 — **981 of 1031 present**, 50 outstanding. Regenerate with the command above.
Counts predate the 38 hire deletions; rerun `art-report` before quoting them.

> The snapshot before this one read *71 outstanding* and was three weeks stale; the sweep found **254**.
> Nearly all of the gap was an **unrun regen** — 114 items and 83 tokens whose blueprints had been
> authored since — which is exactly the failure mode `. art-build stale` now exists to catch. Regenerate
> the numbers here from the tool, and never retype one from memory.

`chars/` is now full, but with **composed placeholder tokens**, not painted art — every character
blueprint resolves to a file so nothing renders as the bare letter fallback, yet the animated-character
work below is still owed. See [Composed tokens](#composed-tokens--the-budget-stand-in-same-philosophy-as-items):
`char-compose assets` fills the gaps and skips any id that already has real art, so a delivered
**painted still** dropped in later transparently replaces its token. Each of the 37 **discipline exemplars** now carries its
own sprite path and its own silhouette (a `DISCIPLINE_SILHOUETTE` tier in `tools/char_compose.lua`, keyed
off the discipline's `exemplar`), so a Necromancer no longer wears the plain mage token; and every
remaining body is named out of its bucket by a `CHARACTER_SILHOUETTE` tier above it, so that **no two
characters share a token** (the sin generals were one picture between the seven of them) — see
[Composed tokens](#composed-tokens--the-budget-stand-in-same-philosophy-as-items).

| Bucket | Have | Needed | Rendered at | Source |
|---|---|---|---|---|
| `items/` | 729 | 733 | 64px cell | **composed from tags** — [icon system](#the-permanent-icon-system--compose-dont-commission); bases still vendored ⚠️ |
| `chars/` | 154 | 154 | ~52px board, **470px dialogue** | **painted stills (commission)**, animated in code — composed tokens stand in and animate identically; see [Characters](#characters) |
| ~~`hazards/`~~ | — | — | 64px tile, under units | **no art, ever** — [drawn by a shader](#hazards-are-not-icons) ✅ |
| `portraits/` | 0 | 17 | — | **commission CANCELLED** — the board still is the portrait; see [Characters](#the-named-cast--the-board-still-is-the-portrait) |
| ~~`vendors/`~~ | — | — | shop panel | **no art, ever** — [the mark is the keeper](#vendors-wear-a-mark-not-a-face) ✅ |
| `traps/` | 6 | 6 | 64px tile | game-icons.net ✅ |
| `overworld/` | 0 | 9 | one tilesheet per biome, see [Terrain](#terrain) | **commission** — [brief](commission-terrain-tileset.md) |
| `materials/` | 6 | 10 | 64px cell | game-icons.net ✅ |
| `props/` | 2 | 2 | 64px tile | game-icons.net ✅ |
| `hub/` | 0 | 2 | 1280×720 | **commission** (`the_gate` can stay a name plate) |
| `fonts/` | 4 | 4 | — | `ui.ttf`, not art |
| `audio/` | 43 | 56 | — | see [audio-assets.md](audio-assets.md) |

The icon pipeline and the composed character tokens are **complete**. What is left needing a human hand
is terrain, one background, the last audio — and the 154 board stills.

The **17 portraits still listed are a commission that will not be placed.** They stay in the count
because the blueprints still name the paths and a sweep that quietly dropped them would be lying about
what the source asks for; what changed is that the board still now answers them.

> **`chars/` is no longer mid-migration, and the report is no longer blind.** It was: a composed token
> is one flat PNG while a Spine rig is a skeleton + `.atlas` + page PNGs, so the row said "done" about
> the largest outstanding commission in the project and `art-report` needed a rule for the triple.
> A painted still is **the same shape as the token it replaces** — one PNG at one path — so the row is
> honest as it stands. What it still cannot tell you is *token or painting*, which is the same blind
> spot `items/` has and is what `art-source` exists to answer.

## Vendors wear a mark, not a face

`assets/vendors/` was 11 shopkeeper portraits. It is now **not a bucket at all** — the `sprite` field is
gone from every `data/vendors/*.lua`, and the counters draw the house's own vector mark on its name
instead (`ui/vendor_icons.lua`'s `drawNamed`, used by the shop, Cafe, Touchstone, Crossing and Inn
panels).

The mark already existed and was already doing this job in three other surfaces — the writ on a ground,
the day's checklist, the quest board — and each house already had a colour to draw it in. What the
panels had was a *portrait pane*: a tinted plate holding that same mark at a third of the panel's width,
standing in for a painting nobody had commissioned. Two panels were even sized around it — the Inn's
card inflated to 532px tall to hold a lettered plate — so removing it gave the room back.

The rule this follows is the one the marks were built on: **a mark is taught beside its name.** A player
stands still at a counter, reads the house's name with its glyph on it, and meets that same glyph alone
on a 32px tile out on the ground.

`tests/` is excluded from the sweep — a spec's stand-in sprite path exists to prove the tolerant
loader survives a missing file, so it is not art anyone owes.

## Direction

Bright fantasy, **not** grim dark. Portraits in anime style — in the vein of _Fire Emblem_
(Awakening / Three Houses) and _Granblue Fantasy_. **This is not a pixel-art game** —
author above final display size and downscale; never upscale a small source.

Board units are **painted stills, animated in code**. What is commissioned is one picture per body;
the motion is transform curves in `ui/combat_fx.lua` — idle, move, attack, hit, cast, death — driven
through `spriteState`, which carries rotation and non-uniform scale as well as an offset.

> **This reverses a Spine commission.** Board sprites were to be hand-rigged skeletal meshes, ~10
> skeletons and 191 skins, with a Spine Editor licence per rigging artist and a `spine-love` runtime
> licence obligation on top. The deciding fact is the size this brief itself quotes — **~52px on a 60px
> tile**, where mesh deformation is sub-pixel. The Fire Emblem Heroes reference misleads: those sprites
> are displayed huge on a phone, which is what pays for the rigging. Painting labour is identical either
> way, so the rig was pure surcharge — and the two-register rule below made 191 rigs an all-or-nothing
> gate, where curves reach every body on the day they land. The six clips shipped in `2268eee`.

### The two-register rule

The board carries two visual registers, and they must not bleed into each other:

- **The character layer** (unit sprites) is *painted* — one still per unit, moved by code.
  Everything standing on the board is drawn in one style, because units are compared against each
  other side by side in the same role. A composed token beside a painted body does not read as a style
  choice — it reads as unfinished art, which is exactly why composed tokens are only ever interim (see
  [Composed tokens](#composed-tokens--the-budget-stand-in-same-philosophy-as-items)). Note this rule is
  about *painting*, not motion: the curves apply to a token and a painted body alike, so a half-painted
  roster is inconsistent in style but never in animation.
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

Every combatant on the board (**154**) is slated for its own **painted still** — that is the whole
`chars/` bucket, and its hand-off brief is [commission-board-sprites.md](commission-board-sprites.md).
The named cast *also* has a static dialogue portrait in `portraits/`, but the two are **separate
assets**, not a crop relationship (see below). Until a unit's picture is delivered it shows a
[composed token](#composed-tokens--the-budget-stand-in-same-philosophy-as-items), which animates
identically.

> **The count fell from 191 to 154.** The 38 named discipline hires — Brann the Barbarian, Pim the
> Thief and the rest — were the Crossing's stock, and the Crossing is retired. Their bodies were
> the wrong thing to recruit and the right thing to fight, so `models/warband.lua` now draws each
> discipline's **exemplar** where its hire used to stand. One body per discipline instead of two.

### The named cast — the board still IS the portrait

This has now gone round twice, so here is the whole history in one place:

1. **One asset.** The board sprite was a square head crop of the commissioned portrait.
2. **Two assets.** The crop coupling was retired: the board sprite became its own asset, authored
   independently, so the portrait no longer had to reserve headroom or keep weapons clear of the face.
3. **One asset again, the other way round.** The **portrait commission is cancelled** — the prose it
   would have illustrated is being rewritten, so there is no cast to paint yet — and the dialogue box
   shows **the board still**, posed at rest.

So one painting owns the board *and* the dialogue box, and the one thing that buys is a hard authoring
requirement: it must stay crisp at **470px** (`ui/dialogue.lua`'s `PORTRAIT_H`), not merely at the
~52px the board draws it at. That cannot be retrofitted, which is why it is in the brief now rather
than when the first one lands. See
[The board still is also the portrait](commission-board-sprites.md#the-board-still-is-also-the-portrait).

> amana · avatar_1 · clem · gyeom · kaya · knight · ren · saber ·
> general_envy · general_gluttony · general_greed · general_lust · general_pride · general_sloth ·
> general_wrath · demon_lord

(`archer` / `mage` / `priest` are the retired generic classes — kept as enemy/test stand-ins, owed no
portrait; see [commission-portraits.md](commission-portraits.md). They still get a board still like any
other combatant.)

### Creatures — 24, painted (Phase 3)

Beasts, elementals, demons, undead and constructs — the largest group, and the last phase in
[commission-board-sprites.md](commission-board-sprites.md). Painted in the same register as the cast so
they sit beside it rather than fighting it. Purchased still-art packs (e.g. NATHUHARUCA, see
[Sourcing](#sourcing)) remain useful as **reference / an interim still** for a creature awaiting its
painting, above the composed token — but the board's end-state for every creature is a painted still.

> boar · dire_bear · hawk · pig · stag · wolf · wolf_alpha · earth/fire/ice/lightning/water/wind
> elementals · demon_grunt · demon_imp · demon_lord · zombie · ogre · crucible_golem · homunculus ·
> miller_ghost · blightstake · gaunt_vigil · wolfsong_spirit

### Human enemies — 9, painted (Phase 2)

No portrait, but they must match the cast. These are now **full figures**, not the square busts
they once were — they moved wholesale into [commission-board-sprites.md](commission-board-sprites.md)
when the board sprite stopped being a portrait crop.

> bandit · bandit_chief · bastion_sworn · caravan_master · champion · forsworn_captain ·
> forsworn_knight · ordnance_sentry · warlord

### Objects — 4, static, from the tileset packs

Inanimate, so they are exempt from the character-layer rule and stay **unanimated** (the curves skip them) —
they should match the *terrain*, not the cast.

> banner · march_standard · straw_sentry · totem

### Composed tokens — the budget stand-in, same philosophy as items

Every one of the 154 is awaiting a painting, and a nameless enemy or a background creature may wait a long
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
| **Base** silhouette | a **character** match (by name), then a **discipline** match (the exemplar), then a creature/name match, then a **`kind`** bucket | game-icons.net (reuse, not commission) |
| **Tint** | element (elementals), else kind | — |
| **Frame** | `class` colour (the vendor shelf), gold + thicker for a boss | shared with the item composer |
| **Badge** | a gold disc for a `boss`/general | — |

A classless boss — `boss = true` with no `class` — would otherwise be a rank swordman told apart only by
its badge, so it is lifted to an **overlord silhouette** (a horned helm). A boss that *has* a class keeps
its role look and a boss that is a demon or beast keeps its creature; only the generic humanoid is lifted.

**Every tier below the character one hands a whole bucket a single picture**, and that is the point of the
`CHARACTER_SILHOUETTE` tier on top of them. A class gives its whole shelf one body, `boss` gives every
classless boss one body, `kind` gives every demon one body — correct for the *generic template* at the head
of each bucket, wrong for everyone else in it. Left to the guesses alone, **51 of the 107 blueprints
resolved to just 15 pictures**: the seven sin generals were one token, and Rowan, the Forsworn Captain and
the Road-Knight were another. So a bucket's silhouette stays the property of the generic body at its head
(`character_knight` keeps the knight banner, `character_bandit` the rank swordman, `character_demon_grunt`
the daemon skull) and every other occupant is named out of it — one line, never art.

Two invariants in `tests/char_compose_spec.lua` hold it: **no two blueprints resolve to the same
silhouette**, and **no two name the same `sprite` path** (the composer writes one file per distinct path and
lets later blueprints ride along, so a shared path is invisible on the board however the slugs differ — the
Trapper wore the Bandit's art that way). The only exceptions are the deliberate aliases: `saber_bout` *is*
Saber. A new blueprint silently joins whichever bucket it derives into and re-collides, which is exactly
what these catch. The rest of the guessing is regression-guarded the same way — pure logic, no render.

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

The battle board and the overworld **share one tilesheet**. `BattleMap.ART` maps every arena tile
type onto an overworld tileset type, so one set of tiles dresses both surfaces:

| arena type | draws as | arena type | draws as |
|--|--|--|--|
| `ground` | `path` | `sand` | `forest` |
| `forest` | `forest` | `ice` | `forest` |
| `mountain` / `obstacle` | `rock` | `mire` | `water` |
| `rough` | `grass` | `lava` | `water` |
| `water` | `water` | | |

The four on the right are the biome floors added with the desert/tundra/volcanic/swamp pass — each
borrows the *role* its biome dresses to suit, so a desert's "forest" is a dune crest and a volcanic
map's "water" is the flow. **Every arena type must have an entry**: the draw site falls back to
`path`, so a missing one never crashes, it just paints that floor as the trail. Pinned by
`tests/biome_spec.lua`.

8 biomes (`forest`, `castle`, `underworld`, `desert`, `tundra`, `volcanic`, `swamp`, `colosseum`) × 6
types (`forest`, `grass`, `rock`, `path`, `bridge`, `water`) = **48 tiles**. The colosseum is the one
that is a building rather than a country, and the cheapest of the eight to draw: two materials, raked
sand and grey stone, and no landform of any kind. The board only ever shows 4
of the 6 — `bridge` and `water` are overworld-only — but the map needs all six. Full per-biome
breakdown and the art direction for each is in
[commission-terrain-tileset.md](commission-terrain-tileset.md).

## Traps

6 icons on the overlay layer, at 64px. Sourced from game-icons.net.

**Hazards need no art at all** — they are drawn procedurally by the field shader. See
[Hazards are not icons](#hazards-are-not-icons); nothing in `data/hazards/` names a sprite, and
`assets/hazards/` is not a bucket anybody owes anything to.

## Sourcing

Two hard constraints: **commercial use must be permitted**, and **no AI-generated art**. A third, added
later and stated plainly here because it governs the whole icon plan: **game-icons.net does not ship.**
The set is recognisable — it is in a great many games — and shipping it as-is reads as an asset flip.
It stays as the development stand-in and comes out of the build before release. See
[Getting game-icons out of the build](#getting-game-icons-out-of-the-build).

| Source | Covers | Terms |
|---|---|---|
| [game-icons.net](https://game-icons.net/) | items, hazards, traps, materials — **development stand-in only** | CC BY 3.0 — **attribution required while it is in the build** |
| [GameDev Market](https://www.gamedevmarket.net/) | terrain, props | Pro Licence; platform bans generative AI outright |
| [NATHUHARUCA MEGA MONSTER PACK](https://plaza-us.komodo.jp/products/nathuharuca-mega-monster-pack) | interim creature stills / reference | "Engine of your choice", commercial OK, editable |
| Commission — **board stills** | all 154 board sprites, one painting each — [commission-board-sprites.md](commission-board-sprites.md) | full commercial buyout, no AI |
| Commission — portraits | dialogue portraits, vendors, hub | — |

### No tooling cost — and there was one

This section used to budget a **Spine pipeline**: an Editor licence for every artist who creates or
exports a rig (Professional, since mesh weights are what the FEH look wants), plus a `spine-love`
runtime licence — the Spine Runtimes Licence requires anyone *shipping* the runtime to hold a valid
Editor seat, so it was a cost on the project and not only on the artists.

**All of it is gone.** A painting is a PNG; there is no editor, no seat, no runtime licence, and no
per-artist gate on who can be hired. Recorded here rather than deleted because a rig will look cheap
again the next time somebody wants a weapon arc, and this is the line item that made it not cheap.

### Attribution obligation

game-icons.net is CC BY 3.0, so for as long as any of it is in the build a credits screen must name the
artists with a link to game-icons.net. This is a licence condition, not a courtesy — build the credits
panel early rather than at ship. The obligation retires exactly when the last vendored slug is replaced
([below](#getting-game-icons-out-of-the-build)), and not before.

`docs/credits-icons.md` is the generated list, and **it must be regenerated by `. art-source credits`,
not by `. icon-build`.** icon-build is the superseded *sourcing* stage: it credits every glyph that
stage ever rendered (632 of them), where the shipped composers draw 410. Both the licence exposure and
the "how much game-icons is in this game" question had been answered off the wrong file.

## Getting game-icons out of the build

The stigma attaches to the **silhouette**, and composing does not launder it — `icon_source.foreground`
inlines the source SVG's paths verbatim and only swaps the fill, so anyone who knows the set will clock
the shape. What composing *does* buy is concentration: 962 shipped assets reduce to **410 distinct
silhouettes**, because a family shape is shared by every weapon in it.

```powershell
& "E:\LOVE\lovec.exe" . art-source            # the exposure, by bucket and by artist
& "E:\LOVE\lovec.exe" . art-source slugs      # every outstanding slug, most-used first
& "E:\LOVE\lovec.exe" . art-source credits    # rewrite docs/credits-icons.md from this truth
& "E:\LOVE\lovec.exe" . art-source ship       # exit 1 while any shipped slug is still vendored
```

| bucket | assets | distinct slugs |
|---|---|---|
| `items/` | 749 | 262 |
| `chars/` | 199 | 191 |
| `traps/` + `materials/` + `props/` | 14 | 11 |
| **distinct across the project** | **962** | **410** |

`items/` reduces hard (262 slugs for 749 icons) because weapons share a family shape. `chars/` does not
reduce at all — `tests/char_compose_spec.lua` requires every blueprint to resolve to a *different*
silhouette, so that bucket is 191 drawings however it is sourced. It is also the most visible exposure
on screen, which is the argument for the board paintings having a date rather than an eventually.

### 410 is not the commission — 268 is

The buckets name 464 slugs between them, which are 410 distinct drawings, so 53 are **shared** and
arrive with whichever bucket is drawn first. `. art-source` reports what each bucket needs *alone*:

| bucket | drawings only it needs |
|---|---|
| `items/` | 209 |
| `chars/` | **142** |
| `materials/` | 4 |
| `props/` | 2 |
| `traps/` | 0 — every trap slug is shared |
| shared by two or more | 53 |

**The 142 chars-only glyphs should not be commissioned at all.** Those tokens are interim by design and
are slated for replacement by painted stills ([commission-board-sprites.md](commission-board-sprites.md)) —
drawing them flat is paying for art the plan already intends to throw away. Take the char bucket out and
the flat-glyph commission is **268 drawings**, with the board handled as paintings instead.

Which also means the two-register rule decides a budget, not just a look: painting some bodies and leaving
the rest as tokens is [already ruled out](#the-two-register-rule), so `chars/` is 154 paintings or 154 flat
glyphs — never a mix, and never both.

### Two roots, and a slug is an address

`tools/icon_source.lua` resolves every slug against two roots, in order:

| root | what it is |
|---|---|
| `art/bases/<slug>.svg` | **drawn art, tracked, ships** — preferred |
| `vendor/game-icons/<slug>.svg` | CC BY 3.0 stand-in, gitignored, development only |

So a delivered glyph takes over everywhere its slug is used the moment it lands — one file re-skins
every asset that reduces to it — and the commission can be **accepted a glyph at a time** with the
exposure watched down to zero, rather than landing as one all-or-nothing swap. Reusing the vendored
slug as the address means no remapping table, no blueprint edits and no code change; the folder name in
a slug is where the *stand-in* came from, never a claim about who drew the replacement.

The deliverable is a **flat single-colour vector glyph**, not an illustration: `viewBox="0 0 512 512"`,
one `#fff` foreground fill (the composers substitute it to tint by element — multi-colour art silently
defeats that channel), no background rect, readable at 64px and again greyed. The full contract, and the
order to draw them in, is [art/bases/README.md](../art/bases/README.md).

### Order the work by what it buys

`. art-source slugs` sorts by how many assets ride on each glyph, and the distribution is steep:

| drawn | assets covered |
|---|---|
| top 10 | 24% |
| top 20 | 35% |
| top 40 | 48% |
| top 80 | 60% |
| all 410 | 100% |

`delapouite/claws` alone dresses 73 assets and `lorc/round-bottom-flask` 44. Draw **down** the list.

## The art build — regenerate, then let drawn art win

```powershell
& "E:\LOVE\lovec.exe" . art-build            # regenerate + overlay + stamp the manifest
& "E:\LOVE\lovec.exe" . art-build overlay     # copy art/ over assets/ only
& "E:\LOVE\lovec.exe" . art-build stale       # exit 1 if assets/ is behind its inputs
```

The obvious way to protect commissioned art from the composer is to make the composer skip files that
already exist. **That is the wrong instinct, and it fails in both directions:**

- It blocks the base swap the override exists for. Drop a new silhouette in `art/bases/` and a
  skip-if-exists composer regenerates nothing, so the delivered glyph changes not one pixel.
- It silently pins stale output. `char-compose assets` has skipped the committed tokens under
  `assets/chars/` for exactly this reason — 15 of them were still drawn from silhouette tables that had
  since moved, while the other 177 were current.

So precedence is **build order**, not a filesystem check: compose everything unconditionally, then copy
`art/` over `assets/`. Drawn art wins by landing second. `art/bases/` is the one subtree *not* copied —
those SVGs are composer input, not art the game loads.

This also retires a convention that was being held in a human's memory. The note below about bespoke art
belonging "on its own path" existed because re-running the composer would overwrite it; under the
overlay, drawn art is not in the composer's write path at all — and it is **tracked in git**, which
`assets/` is not. `assets/` being gitignored is correct for generated output and was quietly wrong for
paid work.

### Staleness is a thing a build can fail on

A composed icon is a pure function of its inputs, so whenever an input moves every output downstream is
silently wrong. That is how 114 items sat with no icon at all — not a bug, an unrun regen. `. art-build`
stamps `assets/.art-manifest` with a fingerprint of the inputs (`tools/art_hash.lua`: the *resolved*
base slug and tint per asset, the fields the pips and badges read, and the bytes of every base SVG), and
`. art-build stale` fails when they diverge.

**A re-tier pass invalidates art every time.** `repRank` drives the frame thickness (`12 + repRank·4`)
and the row of tier pips, so `balance-rescale apply` silently makes the icons of everything it moved
wrong. Run `. art-build` after a rebalance, the same way [balance.md](balance.md) ends a re-tier on a
rescale.

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

Two separate commissions now — the board stills and the dialogue portraits are independent assets. The
full hand-off for each lives in its own doc; the summary:

**Board sprites (154)** — **painted stills**, one per combatant, displayed at ~52px on a 60px
tile (`ui/battle_map.lua`). Full spec in [commission-board-sprites.md](commission-board-sprites.md):
one PNG per body, the pose it is painted in, and
multi-cell scaling. The six clips (idle/move/attack/hit/cast/death) are code and need nothing from the artist.

**Portraits (17)** — static standing figures for the dialogue box, anchored bottom-centre, displayed
at 470px tall (`ui/dialogue.lua`). Full spec in
[commission-portraits.md](commission-portraits.md). Deliver **≥1400px tall** and keep the cast
consistent in style and proportion. (The old head-crop constraints — headroom, weapons clear of the
face, uniform head height, a layered crop guide — are **retired**: the portrait no longer feeds the
board token, so it only has to serve the dialogue box.)

**Vendors (8) and hub city (1)** — panel and background art; the hub is 1280×720 logical
(`scale.lua`), so author at 2× and downscale.

## Code follow-ups (wiring a board still)

**There is nothing to wire.** This section used to list five jobs — vendoring the `spine-love` runtime,
branching every board draw site on skeleton-vs-texture, mapping clips onto the fx signals, deciding how
the dissolve shader met the meshes, and teaching `art-report` to count a rig triple. All five existed
because the delivered asset was a different *kind* of thing from the placeholder it replaced.

A painted still is the same kind of thing: one PNG at the path the blueprint already names.
`models/sprite.lua` loads it, `ui/battle_map.lua` draws it, `shaders/sprite.lua` wraps it, and
`ui/combat_fx.lua` animates it — all exactly as they already do for the composed token. **Drop the file
in and it is done**, which is also why art can land one body at a time instead of all 154 at once.

The one thing that still wants checking when real paintings arrive: the tilt constants
(`DEATH_TILT` and its neighbours) were tuned against composed tokens — emblems on a baked plate — and
want raising for bodies with a readable silhouette. Judge that by looking, never from the numbers: the
**Animation Gallery** (menu debug column) runs every clip at once, and the board's right-click
**Animations** page fires one clip at a chosen body with a playback-speed control.

## Code follow-ups (wiring a portrait)

- **Point the remaining blueprints at their portrait (still to do)** — add
  `portrait = "assets/portraits/<id>.png"` to the seven `data/vendors/*.lua` that still lack the
  field, and to `character_demon_lord.lua`, so `art-report` counts them and the VN box can show
  them. After that, `& "E:\LOVE\lovec.exe" . art-report` lists exactly the 24 portrait files in
  [commission-portraits.md](commission-portraits.md).
- **The generic classes owe no portrait — done.** `data/player.lua`'s default roster/party is
  `character_rowan` only (a New Game starts lean; the rest are recruited at slot 2 of each vendor
  line), and the `portrait` field is stripped from `character_mage` / `character_archer` /
  `character_priest`. Those blueprints stay — they are load-bearing enemy/ally/test stand-ins across
  ~15 quests and ~60 tests — but they never reach the dialogue box.

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

> **What ships is the composition, not the current silhouettes.** The layering below is permanent; the
> game-icons.net shapes feeding it are the development stand-in and come out before release. That is a
> swap of **410 base glyphs**, not a commission of 749 icons — see
> [Getting game-icons out of the build](#getting-game-icons-out-of-the-build). The distinction matters
> because it is the difference between a small icon-design gig and an unaffordable one.

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

### The four husks

`assets/items/unidentified_{weapon,armor,utility,ability}.png` are the icons an **unidentified** piece
wears until somebody pays to name it ([identification.md](identification.md)). They are the one set in
`assets/items/` that the composer must never touch, and the reason is the feature: the composer draws a
family, an element, a class and a tier, and every one of those is a fact the husk exists to withhold. A
composed husk would answer the question the Touchstone charges to answer.

So they are four hand-authored silhouettes and nothing else — a blade shape, a coat shape, a charm
shape, a rune shape — each unmistakably its type and deliberately unmistakable for any particular item
of it. Wrapped, shrouded, or drawn as an outline; whatever reads as "this is a thing of that kind and
you cannot see it yet" at 38px in a list row and again at 64px on a card.

### What still gets commissioned

The signature relics (~8 per companion) and the generals' gear are the pieces a player studies in a
panel; those earn bespoke art. Everything else stays composed.

Per-item bespoke art goes in **`art/items/<name>.png`**, not at the blueprint's `assets/` path: the
[art build](#the-art-build--regenerate-then-let-drawn-art-win) copies `art/` over `assets/` *after*
composing, so it wins by landing second and no longer depends on anybody remembering to keep it clear of
the composer. (The old rule — "bespoke art belongs on its own path, because re-running `icon-compose
assets` would overwrite it" — is retired with the convention that made it necessary.)

Worth weighing before placing that commission: the argument in the next section applies to relics
unchanged. 38 of the outstanding item icons are `sig_*`, and the cheaper route to a better relic icon is
drawing the **base glyph** it composes from, which improves every item riding on that glyph too.

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
