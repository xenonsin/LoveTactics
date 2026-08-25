# Item Icons — Commission Brief

A hand-off brief for the **base silhouettes** every item icon in the game is composed from. Built
from the pipeline's real constraints (`tools/icon_compose.lua`, `tools/icon_source.lua`,
[art/bases/README.md](../art/bases/README.md)) so a delivered file drops straight in and re-skins
everything riding on it the same afternoon. See [art-assets.md](art-assets.md) for the wider art
plan and [credits-icons.md](credits-icons.md) for the licence exposure this commission retires.

## The project

**LoveTactics** — a 2D tactics RPG built in LÖVE2D. Tone: **bright heroic fantasy**, not grim-dark.

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

## What is being bought — 62 drawings for 749 icons

The game ships **749 item icons and draws them with 62 distinct silhouettes**, because the icon is
*composed* from what the blueprint already declares rather than drawn per item ([The permanent icon
system](art-assets.md#the-permanent-icon-system--compose-dont-commission)). Every axe in the game is
one axe drawing; every warding spell is one warding drawing in ten colours.

That is the whole reason this commission is affordable, and it is also the reason it is worth
placing: the silhouettes standing in today are [game-icons.net](https://game-icons.net) under
CC BY 3.0, which is **development stand-in only** — the set is recognisable, shipping it reads as an
asset flip, and it comes out of the build before release.

> **This brief used to ask for 262 drawings, 164 of them for a single item each.** The catalogue had
> no cap: `tools/icons/map.lua` named a glyph per asset, mostly auto-guessed, and every new ability
> quietly added one more. The composer now holds a **vocabulary** — a declared list of the shapes this
> game is allowed to draw — and anything outside it falls through to what the ability *does* or when
> the charm *fires*. The commission is a list somebody chose, and it no longer grows with the
> catalogue. See [The vocabulary](#the-vocabulary-and-why-62-is-the-whole-of-it).

### Snapshot

As of 2026-08-25. **Never retype these from memory** — regenerate:

```powershell
& "E:\LOVE\lovec.exe" . art-source          # the exposure, by bucket and by artist
& "E:\LOVE\lovec.exe" . art-source slugs    # every outstanding slug, most-used first
& "E:\LOVE\lovec.exe" . art-source ship     # exit 1 while any shipped slug is still vendored
```

| | |
|---|---|
| item icons the game ships | **749** |
| distinct silhouettes they reduce to | **62** |
| of those, needed **only** by items | 52 |
| shared with `chars/` · `traps/` · `materials/` · `props/` | 10 — arrives with whichever bucket is drawn first |
| drawn so far | **0** |

## What the composer does, so you don't

Your file is one layer, and the rest is code. **Deliver the shape and nothing else:**

- **Colour is not yours.** The composer substitutes the fill to tint by element — orange for fire,
  blue for ice, violet for arcane, steel for a physical strike. The same glyph ships in a dozen
  colours, and that is doing a lot of the work: the ten wards are one drawing.
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

## The vocabulary, and why 62 is the whole of it

`Icon.baseFor` resolves an item in five steps, and only the second one can name a shape that is not
already on this list:

1. **A weapon's family** — 15 shapes, one per family in `Item.ARCHETYPES`. An axe reads as an axe.
2. **Its own mapped glyph, if that glyph is in the vocabulary.** This is the gate. An unapproved
   guess draws nothing; it falls through.
3. **What an ability *does*, or when a charm *fires*.** The verb comes from `Combat.abilityOutput` —
   the same dry run the tooltip reads, so an icon can never claim something the tooltip denies. A
   passive charm is named by the field it carries or the hook its trait fires on.
4. **The pool an ability spends** — a mana spell and a stamina technique read differently.
5. **The type base** — ability, armor, utility, material, consumable.

The rule for step 2 is **four items**: a mapped glyph is kept when four or more items share it.
Below that the shape is not naming a category, it is naming an item — which is the tooltip's job.
The exceptions are five silhouettes worn by **bound relics** (a signature that can never leave its
holder), capped at 24 and pinned by `tests/art_pipeline_spec.lua`.

## What to draw, in order

Draw **down** this list: it is sorted by how many item icons ride on each glyph.

| drawn | of the 749 item icons |
|---|---|
| top 10 | 45% |
| top 16 | 58% |
| top 36 | 85% |
| all 62 | 100% |

### Phase 1 — the sixteen that carry the shelf (58%)

| # | Slug | Icons | What it stands for |
|---|---|---|---|
| 1 | `delapouite/claws` | 73 | the `natural` family — beast weapons and natural implements |
| 2 | `lorc/round-bottom-flask` | 61 | the utility base: any charm that is not something else |
| 3 | `sbed/shield` | 42 | **ward** — an ability whose whole job is granting a buff |
| 4 | `lorc/deadly-strike` | 41 | **strike** — a blow landing on one body |
| 5 | `caro-asercion/round-potion` | 25 | the consumable base — a drink, a draught, an elixir |
| 6 | `lorc/magic-swirl` | 22 | the ability base, and a spell paid for in mana |
| 7 | `lorc/spark-spirit` | 21 | **summon** — a called body, or one reshaped |
| 8 | `lorc/cursed-star` | 20 | **curse** — an ability that inflicts and nothing else |
| 9 | `delapouite/abdominal-armor` | 18 | mail and cuirass: most of the armour shelf |
| 10 | `delapouite/knight-banner` | 17 | a rally — raised once, before anything happens |
| 11 | `lorc/breastplate` | 17 | the armour base |
| 12 | `lorc/incense` | 16 | the `censer` family |
| 13 | `lorc/broad-dagger` | 16 | the `dagger` family |
| 14 | `lorc/fire-zone` | 15 | **hazard** — a patch of ground laid down |
| 15 | `delapouite/healing` | 14 | **heal** |
| 16 | `delapouite/cross-shield` | 14 | the `shield` family |

### Phase 2 — the next twenty (to 85%)

| # | Slug | Icons | What it stands for |
|---|---|---|---|
| 17 | `lorc/wizard-staff` | 13 | the `staff` family |
| 18 | `lorc/tied-scroll` | 12 | a written charm — one that rides a cast |
| 19 | `lorc/robe` | 12 | cloth armour |
| 20 | `lorc/muscle-up` | 12 | a technique paid for in stamina |
| 21 | `lorc/broadsword` | 12 | the `sword` family |
| 22 | `lorc/spiked-mace` | 11 | the `mace` family |
| 23 | `lorc/spear-hook` | 11 | the `spear` family |
| 24 | `lorc/crystal-wand` | 11 | the `wand` family |
| 25 | `delapouite/two-handed-sword` | 11 | the `greatsword` family |
| 26 | `delapouite/bow-arrow` | 11 | the `bow` family |
| 27 | `sbed/blast` | 10 | **area strike** — a blow landing on a footprint |
| 28 | `lorc/high-shot` | 10 | the `longbow` family |
| 29 | `lorc/battle-axe` | 10 | the `axe` family |
| 30 | `delapouite/thor-hammer` | 10 | the `hammer` family |
| 31 | `delapouite/shield-impact` | 10 | a charm that answers a blow |
| 32 | `darkzaitzev/smoke-bomb` | 9 | the thrown-flask family |
| 33 | `lucasms/cloak` | 8 | a mantle, worn over |
| 34 | `lorc/boots` | 8 | footwear, and anything leaving a trail |
| 35 | `delapouite/heart-stake` | 8 | a charm that pays out on a death |
| 36 | `delapouite/barrier` | 8 | **wall** — something solid put in the way |

### Phase 3 — the last twenty-six (to 100%)

| # | Slug | Icons | What it stands for |
|---|---|---|---|
| 37 | `sbed/poison` | 6 | a charm watching for an affliction |
| 38 | `lorc/sprint` | 6 | **move** — a push, a pull, a swap |
| 39 | `lorc/rune-stone` | 6 | a cut sigil |
| 40 | `lorc/prayer` | 6 | an invocation |
| 41 | `lorc/mantrap` | 6 | **trap** — a tile armed and waiting |
| 42 | `lorc/fist` | 6 | the `unarmed` family |
| 43 | `delapouite/notebook` | 6 | ledgers and codices |
| 44 | `delapouite/centaur-heart` | 6 | a carried heart or core |
| 45 | `lorc/stone-sphere` | 5 | a thrown stone |
| 46 | `lorc/shouting` | 5 | a shout |
| 47 | `lorc/double-shot` | 5 | a bow trick |
| 48 | `delapouite/pirate-coat` | 5 | a coat |
| 49 | `cathelineau/holy-oak` | 5 | a blessing that grows |
| 50 | `sbed/duel` | 4 | a single combat |
| 51 | `lorc/mirror-mirror` | 4 | a reflection |
| 52 | `lorc/hourglass` | 4 | something that spends time |
| 53 | `lorc/energise` | 4 | **resource** — a pool drained or restored |
| 54 | `lorc/charm` | 4 | a hung charm |
| 55 | `lorc/armor-vest` | 4 | a padded vest |
| 56 | `lorc/aura` | 3 | a standing field around the bearer |
| 57 | `caro-asercion/french-horn` | 3 | a horn ⚑ |
| 58 | `lorc/crossed-swords` | 2 | a charm that follows an ally's swing |
| 59 | `lorc/jeweled-chalice` | 2 | a reliquary ⚑ |
| 60 | `lorc/crystal-ball` | 1 | ⚑ *Overflowing Focus* |
| 61 | `lorc/crown` | 1 | ⚑ *Hollow Crown* |
| 62 | `delapouite/health-potion` | 1 | ⚑ *Aqua Vitae* |

⚑ = one of the five kept for a **bound relic** — a signature item a player studies rather than
scans. Everything else on the list earns its drawing by being shared.

Two shapes carry the game on their own: **claws** (the `natural` family, and every familyless thing
the resolver reads as a natural implement) and the **round-bottomed flask** (the utility base). They
are 134 icons — 18% of the bucket — for two drawings.

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
| `materials/` | 4 | crafting stock, 64px cell |
| `traps/` | 2 | the overlay layer, 64px tile |
| `props/` | 2 | board furniture, 64px tile |

## Not in this commission

- **`chars/` — 144 silhouettes.** Character tokens are interim by design and are slated for
  replacement by painted stills ([commission-board-sprites.md](commission-board-sprites.md)).
  Drawing them flat is paying for art the plan already intends to throw away. They are also the
  reason the project's total exposure (215 slugs) is so much larger than this brief.
- **Hazards.** Drawn procedurally by a shader; there is no hazard art and never will be
  ([why](art-assets.md#hazards-are-not-icons)).
- **Portraits.** [Cancelled](art-assets.md#the-named-cast--the-board-still-is-the-portrait) — the
  board still is the portrait.
- **Bespoke relic art.** The five relic silhouettes above are flat glyphs like everything else. A
  signature relic *could* earn a painting instead; weigh that against this brief first, because the
  cheaper route to a better relic icon is drawing the **base glyph** it composes from, which
  improves every item riding on that glyph too.

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
