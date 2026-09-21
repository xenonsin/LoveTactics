# Item Icons — Commission Brief

A hand-off brief for the **base silhouettes** every item icon in the game is composed from. Built
from the pipeline's real constraints (`tools/icon_compose.lua`, `tools/icon_source.lua`,
[art/bases/README.md](../art/bases/README.md)) so a delivered file drops straight in and re-skins
everything riding on it the same afternoon. See [art-assets.md](art-assets.md) for the wider art
plan and [credits-icons.md](credits-icons.md) for the licence exposure this commission retires.

## The project

**Project Tactics** — a 2D tactics RPG built in LÖVE2D. Tone: **bright heroic fantasy**, not grim-dark.

Item icons are **panel furniture**. No item or ability sprite is ever drawn on the battlefield, so
these never sit beside a painted unit in the same role — they live in the inventory grid, the shop
shelf, the bag, the tooltip card and the battle action bar. Sizes they are actually seen at:

| Surface | Drawn at |
|---|---|
| Inventory / action grid slot (`ui/inventory_grid.lua`) | 92px |
| Shop and bag cells (`ui/pool_grid.lua`) | 64px |
| List rows and card headers | ~38px |
| Battle action slot (`ui/combat_panel.lua`) | inside 96 × 58 |
| Rasterized master | 256px PNG |

## What is being bought — 825 drawings for 852 icons

The game ships **852 item icons and draws them with 825 distinct silhouettes**: one shape per item,
with the only sharing coming from the blueprints that deliberately point at a single sprite file
(the fangs three beasts wear; an ability granted both from a charm and from a shelf).

The icon is still *composed* — colour, aura and rank are code, not your file ([The permanent icon
system](art-assets.md#the-permanent-icon-system--compose-dont-commission)) — but the **silhouette layer
is per-item**, and that is what makes this a large commission rather than a small one.

It is worth placing because the silhouettes standing in today are
[game-icons.net](https://game-icons.net) under CC BY 3.0, which is **development stand-in only** — the
set is recognisable, shipping it reads as an asset flip, and it comes out of the build before release.

> **This brief asked for 62 drawings between 2026-08-25 and 2026-09-20.** A *vocabulary gate* in the
> composer held the catalogue to a declared list of shapes, and anything outside it fell through to what
> the ability *does* or when the charm *fires* — so 73 items shared the claws, 61 the flask and 42 the
> ward. That was reversed on 2026-09-20: **every item draws its own silhouette now**
> ([One item, one silhouette](art-assets.md#one-item-one-silhouette)). Anyone reading an older version of
> this file, or quoting the 62 figure in a conversation with an artist, is quoting a retired decision.
### Snapshot

As of 2026-09-20. **Never retype these from memory** — regenerate:

```powershell
& "E:\LOVE\lovec.exe" . art-source          # the exposure, by bucket and by artist
& "E:\LOVE\lovec.exe" . art-source slugs    # every outstanding slug, most-used first
& "E:\LOVE\lovec.exe" . art-source ship     # exit 1 while any shipped slug is still vendored
```

| | |
|---|---|
| item icons the game ships | **852** |
| distinct silhouettes they draw | **825** |
| of those, needed **only** by items | 735 |
| shared with `chars/` · `traps/` · `materials/` · `props/` | 90 — arrives with whichever bucket is drawn first |
| drawn so far | **0** |

## What the composer does, so you don't

Your file is one layer, and the rest is code. **Deliver the shape and nothing else:**

- **Colour is not yours.** The composer substitutes the fill to tint by element — orange for fire,
  blue for ice, violet for arcane, steel for a physical strike. The same glyph ships in a dozen
  colours, and that is doing a lot of the work: a ward's tint says which ward it is without the name.
- **The magical aura is not yours.** A spell blooms a soft radial glow behind the silhouette in its
  element tint; a physical swing has none. That is the at-a-glance magic tell and it is drawn
  procedurally.
- **Tier and class are not yours.** A row of `repRank` diamonds along the bottom edge, in the vendor
  shelf's colour, says rank and house. The composer already scales your art to 62.5% and nudges it
  up to clear that row, so draw to the full canvas and let it inset you.
- **There is no frame and no badge.** An earlier revision framed the art in a class-colour border
  and stamped a type disc in the corner; both were dropped — the border fought the action slot's own
  frame. The icon is a bare silhouette on transparency.

## The contract every file must meet

The composer does surgery on these, so the shape of the *file* matters as much as the drawing:

- **`viewBox="0 0 512 512"`**, square.
- **One flat foreground fill of `#fff`.** Multi-colour art, gradients or a hard-coded palette
  silently defeat the tint channel — the icon comes out the wrong colour with **no error anywhere**.
- **No background rect.** One is stripped if present, but do not add one.
- **Paths, not strokes.** Outline every stroke before delivery; a stroked path scales its weight
  with the layer transform and thickens unpredictably.
- **Readable as a silhouette at 64px, and again when greyed.** Inactive and fallen items tint the
  whole sprite down, so identity cannot rest on fine low-contrast detail.
- **Readable in any colour.** Every shape below is tinted by whatever the item deals or wards
  against, so it must hold up in pale gold and in near-white as well as in steel.

Flat single-colour vector, in other words — **an icon-design deliverable, not an illustration.**

### Do not trace the stand-in

Each slug currently resolves to a game-icons.net SVG, and that file is *not* reference to copy. The
point of the commission is to get that set out of the build; a traced or redrawn derivative carries
the same CC BY 3.0 obligation and buys nothing. Draw the **same subject** — a broadsword, a
round-bottomed flask, a censer — as your own drawing.

## Delivery

One SVG per silhouette, at the address the slug names:

```
art/bases/<folder>/<name>.svg      e.g. art/bases/lorc/broadsword.svg
```

**The slug is an address, not a credit.** The `lorc/` in that path is where the *stand-in* came
from; it is never a claim about who drew the replacement. Reusing the address means no remapping
table, no blueprint edits and no code change — `tools/icon_source.lua` prefers `art/bases/` over the
vendored root, so **a delivered glyph takes over everywhere its slug is used the moment it lands**.

Which also means the work can be **accepted a glyph at a time**, with the exposure watched down to
zero, rather than landing as one all-or-nothing swap.

Deliver source (SVG, or an AI / Figma export). No PNGs are needed for the bases — the pipeline
rasterizes.

## One item, one silhouette

`Icon.baseFor` resolves an item in five steps, and **the first one answers for everything shipped**:

1. **Its own mapped glyph.** `tools/icons/map.lua` names a distinct shape for every icon-shaped asset in
   the project — 857 assets, 857 slugs — and `. icon-map` keeps it that way by treating a match as a
   *claim*: the second item reaching for the shield settles for its own second-best rather than sharing.
2. **A weapon's family** — 15 shapes, one per family in `Item.ARCHETYPES`.
3. **What an ability *does*, or when a charm *fires*.** The verb comes from `Combat.abilityOutput` —
   the same dry run the tooltip reads, so an icon can never claim something the tooltip denies.
4. **The pool an ability spends** — a mana spell and a stamina technique read differently.
5. **The type base** — ability, armor, utility, material, consumable.

**Steps 2–5 are a placeholder, not a fallback anyone ships on.** They are what a blueprint authored
since the last `. icon-map` run draws in the meantime, and `tests/art_pipeline_spec.lua` reddens the
moment two items land on the same one. So for the purposes of this brief there is exactly one rule:
**one item, one drawing.**

### What that means for the list you are given

A quarter of the catalogue has a name that describes an idea rather than an object — *Tempo Debt*, *The
Names He Kept*, *The Unpaid Tithe*. Those items were assigned their shapes by hand, in
`tools/icons/overrides.lua`, each drawing **the mechanic rather than the title**. That is the rule to
follow when a slug on the list looks unrelated to the item riding it: it is not a mismatch, it is a
decision, and the item's tooltip is what it was drawn against.

## What to draw, in order

**There is no cheap top of the list any more.** `. art-source slugs` still sorts by how many assets ride
on each glyph, but almost every glyph now dresses exactly one — the steepest entry in the whole item
bucket covers five assets. Under the old vocabulary the top ten drawings covered 45% of the shelf; there
is nothing like that left to exploit, because the sharing that created it is what was removed.

So order by **what a player stops and looks at**, not by coverage:

| Phase | What | Why first |
|---|---|---|
| 1 | the **starting kits** and the first two shelves of each house | seen in the first hour, by everybody |
| 2 | **consumables and charms** | the densest grids in the game — the bag and the shop |
| 3 | the **bound relics** and named pieces | the items a player studies rather than scans |
| 4 | the **90 slugs two buckets share** | the only drawings that still pay twice |
| 5 | the long tail | deep-shelf weapons and abilities, in any order |

Regenerate the authoritative list rather than working from a table in this file — it is 825 rows and it
moves whenever an item is added:

```powershell
& "E:\LOVE\lovec.exe" . art-source slugs    # every outstanding slug, with the items riding it
```
## The four husks — the one thing here that is drawn, not composed

`assets/items/unidentified_{weapon,armor,utility,ability}.png` are the icons an **unidentified**
piece wears until somebody pays to name it ([identification.md](identification.md)). They are the
one set the composer must never touch, and the reason is the feature: the composer draws a family,
an element, a class and a tier, and **every one of those is a fact the husk exists to withhold.** A
composed husk would answer the question the Touchstone charges to answer.

So they are four hand-authored silhouettes and nothing else — a blade shape, a coat shape, a charm
shape, a rune shape — each unmistakably its *type* and deliberately unmistakable for any particular
item of it. Wrapped, shrouded, or drawn as an outline; whatever reads as "this is a thing of that
kind and you cannot see it yet" at 38px in a list row and again at 64px on a card.

These four are the only item icons outstanding on disk today (`. art-report missing`). Deliver them
as **256 × 256 transparent PNG** (plus source) at `art/items/unidentified_<type>.png` — under
`art/`, which is tracked and overlays `assets/` *after* the composer runs, so nothing regenerates
over them. They do **not** follow the single-`#fff`-fill contract: nothing tints them.

## Optional add-ons

Same register, same contract, and cheap because they are small:

| Bucket | Extra drawings | Note |
|---|---|---|
| `materials/` | 17 | crafting stock, 64px cell |
| `traps/` | 7 | the overlay layer, 64px tile |
| `props/` | 2 | board furniture, 64px tile |

## Not in this commission

- **`chars/` — 75 silhouettes.** Character tokens are interim by design and are slated for
  replacement by painted stills ([commission-board-sprites.md](commission-board-sprites.md)).
  Drawing them flat is paying for art the plan already intends to throw away. The project's total
  exposure is 926 slugs; this brief is 825 of them.
- **Hazards.** Drawn procedurally by a shader; there is no hazard art and never will be
  ([why](art-assets.md#hazards-are-not-icons)).
- **Portraits.** [Cancelled](art-assets.md#the-named-cast--the-board-still-is-the-portrait) — the
  board still is the portrait.
- **Bespoke relic art.** A relic's silhouette is a flat glyph like everything else. A signature relic
  *could* earn a painting instead, and that is now a straight comparison rather than a leveraged one:
  since every item draws its own shape, a drawing buys exactly one item whichever way it is made.

## Licensing

**Full commercial rights / work-for-hire buyout** — use in a commercial game and its marketing, no
project-count limit. **100% human-authored; no AI-generated content** — a contractual requirement,
not a preference. Credit welcome, not required.

Each delivered glyph retires a piece of a live obligation: while any game-icons.net silhouette is in
the build, CC BY 3.0 requires those artists be credited **to players**, on a credits screen. The
obligation ends when the last vendored slug is replaced, and not before.

## Acceptance

Per drop, in order:

```powershell
& "E:\LOVE\lovec.exe" . art-build            # regenerate every composed icon from the new bases
& "E:\LOVE\lovec.exe" . art-source           # confirm the slug now answers from art/bases/
& "E:\LOVE\lovec.exe" . art-source ship      # exit 0 only when nothing shipped is game-icons
```

Then look at it: the icon greyed, the icon at 64px in a full shop shelf, and the icon in each of its
element tints — a shape that works in steel can still fail in pale gold.
