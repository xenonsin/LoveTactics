# Board Sprites — Commission Brief

A hand-off brief for commissioning the game's on-board unit sprites: the animated characters that
stand and fight on the tactics grid. Everything a delivered rig needs to drop straight into the game
is here. Deeper character context — personalities, story roles, faction looks — lives in
[story.md](story.md), and the matching dialogue portraits (a separate commission) in
[commission-portraits.md](commission-portraits.md).

## The project

**LoveTactics** — a 2D tactics RPG. Tone: **bright heroic fantasy**, not grim-dark. Battles play out
on a grid of ~60px tiles, where each combatant is a small **animated sprite** that idles, moves,
attacks, takes hits and falls — the readable, lively unit art of a game like *Fire Emblem Heroes*.

## What we're commissioning

**Animated character rigs, one per combatant — and there are 191 of them**, not the ~55 an earlier
version of this brief quoted. That number came from `data/characters/`, which has grown; regenerate it
with `& "E:\LOVE\lovec.exe" . art-report` rather than trusting any figure typed here.

**This is the whole art budget.** There is no separate portrait commission any more — see
[The rig is also the portrait](#the-rig-is-also-the-portrait) — so these rigs are the only painted
character art the game will have, and every place a person appears is one of them.

191 bespoke rigs is not what we are asking for, because it is not what 191 bodies need. See
[Skeletons and skins](#skeletons-and-skins-what-we-are-actually-buying) — the count we expect to pay
rigging labour on is **the skeletons**, and the 191 are **skins** over them.

## Art direction

- **Style: anime, bright fantasy.** Clean line, saturated but not garish, expressive. **Not pixel
  art** — author above final size and downscale.
- **Fire Emblem Heroes-style animation.** Skeletal/mesh motion — a living idle, weight in the walk,
  follow-through on a swing — not a stiff paper doll and not a frame-by-frame flipbook.
- **One consistent cast.** Shared rendering style, line weight and proportion across all 191, and
  matched to the dialogue portraits of the named characters. Units are compared side by side on the
  board, so a mismatch reads immediately.
- **Readable small, and readable darkened.** The sprite is displayed around 52px tall. Silhouette and
  key colours must carry at that size, and must still read when the sprite is **greyed / desaturated**
  (fallen and inactive states tint it down). Avoid identity resting on fine low-contrast detail.
- **Human-made only:** **no AI-generated content.** A contractual requirement, not a preference.

## Skeletons and skins — what we are actually buying

Spine skins are native to the tool, and they are the shape of this job. One **skeleton** per body plan,
rigged and animated once; one **skin** per character, which is artwork attached to that skeleton and no
rigging labour at all. The animation set below therefore gets authored **once per skeleton**, not 191
times.

The roster's own `kind` field already partitions it, and the split is lopsided in the direction that
helps:

| kind | bodies | note |
|---|---|---|
| humanoid | **113** | wants a few skeletons, split by stance/weapon (one-hand, two-hand, bow, staff) |
| beast | 23 | quadruped, plus a flyer |
| demon | 15 | mostly humanoid-adjacent; some may ride the humanoid skeletons |
| construct | 15 | |
| elemental | 12 | amorphous — one skeleton covers the set, recoloured |
| object | 7 | barely animated: a banner, a totem, a straw sentry |
| undead | 6 | can ride a humanoid skeleton with a different skin |

We expect this to land somewhere around **10 skeletons**. Propose your own split — you will know better
than us where a shared rig stops being convincing — but the deliverable we are pricing is *skeletons
rigged and animated* plus *skins authored*, itemised separately, not a flat per-character rate.

**Where the shared skeleton pays most:** 38 of the humanoids are the game's **discipline exemplars** —
one hero per discipline, all human, differing in kit and silhouette rather than in build. A further 7
are the named companions. Those 45 are the bodies a player recruits and looks at longest, and they are
the single most skin-able group in the game.

**Where it must not be pushed:** the seven generals and the final boss are the game's set-pieces. If a
shared skeleton would make one of them read as a reskin of a rank-and-file body, rig it on its own and
tell us — we would rather pay for eight distinctive silhouettes than have the bosses feel generic.

## The rig is also the portrait

The game tells its story visual-novel style, with a standing figure over a dialogue box at **470px
tall**. There is no separate portrait commission: **that figure is the rig**, posed.

This has one hard consequence for authoring, and it cannot be retrofitted:

- **Author and export the atlas at portrait scale, not board scale.** The board draws a unit at ~52px.
  A rig authored for 52px and scaled up 9× to fill a dialogue box is a blurred mess. Author the source
  art large and deliver atlas pages that stay crisp at **470px tall**, then let the engine downscale for
  the board — the same "never author small" rule as below, taken seriously enough to survive the larger
  of the two sizes.
- **Compose so the figure reads at both sizes.** Silhouette and key colours carry the 52px board read;
  face and costume detail carry the 470px one. Detail that only exists at portrait scale is fine — detail
  the silhouette *depends* on is not.
- **A neutral standing/idle pose is the portrait pose.** No separate portrait artwork is delivered; the
  dialogue box shows the rig at rest.

Only the named cast is ever shown in a dialogue box, so if it changes the price, treat portrait-scale
fidelity as a requirement for **Phase 1** and board-scale as sufficient for Phases 2–3.

## Format & delivery

- **Authored and delivered as a Spine project** (Esoteric Software Spine). Mesh deformation and
  weighted bones are expected for the FEH-style motion, so author in **Spine Professional**.
- Deliver, per unit:
  - the **Spine project / source** (`.spine`), and
  - the **exported runtime files**: skeleton (`.json` or `.skel`), atlas (`.atlas`), and the atlas
    **page PNG(s)** — transparent background.
- **Name each rig to match the unit id** in the roster below (e.g. `general_wrath`, `dire_bear`).
- **One texture atlas per rig** where practical; keep atlas pages to a sensible power-of-two size.
- Keep the **origin/root at the feet, centred** — the sprite is placed by its footprint on a tile.
- **Author facing one direction** (screen-right by convention). The game mirrors a rig for units
  facing the other way, so the art need not be drawn both ways.

## Animation set

Every rig ships the same named clips, so a delivered unit works the moment it drops in. Match these
names and loop settings:

| Clip | Loop? | Reads as |
|---|---|---|
| `idle` | loop | At-rest breathing/sway. The state a unit spends most of its time in. |
| `move` | loop | Walking/advancing between tiles. |
| `attack` | one-shot | A committed strike — wind-up, hit, follow-through. Returns to `idle`. |
| `hit` | one-shot | Taking a blow — a flinch/recoil. Returns to `idle`. |
| `cast` | one-shot | Channelling an ability (magic, a shout, a heal). Returns to `idle`. |
| `death` | one-shot | Being felled — a collapse/fade the unit ends on. Holds on the last pose. |

- Keep clips **short and loopable at small scale** — motion should read at 52px, not rely on detail.
- A creature with no spellcasting can play a second physical `attack` variation in place of `cast`;
  flag any unit where a clip doesn't fit and we'll agree a substitute.

## Technical spec

- **Display size:** ~52px tall on a 60px tile (the game runs in a fixed 1280×720 logical space). Author
  well above that and let the engine downscale; never author small.
- **Large units:** a few enemies occupy a **2×2 footprint** (e.g. the ogre) and are drawn at roughly
  twice the size — we'll mark which in the roster. Compose those to read as genuinely larger bodies.
- **Transparent** throughout; no baked background, ground shadow, or tile.
- No baked team colour or selection frame — the game draws allegiance rings and highlights itself.

## The roster (191)

Unit ids match the game's data files; see [story.md](story.md) for who each character is. Suggested
phasing runs most-seen first. **The lists below are not the whole 191** — they are the named bodies of
each phase; `& "E:\LOVE\lovec.exe" . art-report missing` prints the current full set, and it is the only
figure that cannot go stale.

### Phase 1.5 — the recruit roster (45)

Slotted between the named cast and the enemies because it is what a player spends the most time
*choosing between*, and because it is where [skins](#skeletons-and-skins-what-we-are-actually-buying)
do the most work.

- **The 7 companions** — already in Phase 1 below. One per story line.
- **The 38 discipline exemplars** — one hero per discipline (`data/disciplines/*.lua`, field `hire`).
  All human, all distinguished by kit and role rather than by build: a Necromancer, a Warlord, a
  Trapper. These are the descent's hireable bodies, met one at a time at the Crossing, and studied on a
  card when they arrive.

A player sees these more often than any enemy in the game. They should be **skins of shared humanoid
skeletons** and should still read as 45 different people.

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

The generic soldier types — `knight`, `mage`, `archer`, `priest` — also need a rig as the game's
rank-and-file stand-ins; they can be plainer than the named cast.

### Phase 3 — the creatures (~78)

Beasts, elementals, undead, demons and constructs — 23 + 12 + 6 + 15 + 15 by the roster's own `kind`
field, plus the 7 inanimate objects below. Most read best with non-humanoid skeletons, and each of those
skeletons covers a whole group: one quadruped serves every beast on four legs, one amorphous body serves
all six elementals recoloured.

> `boar` · `dire_bear` · `hawk` · `pig` · `stag` · `wolf` · `wolf_alpha` ·
> `earth` / `fire` / `ice` / `lightning` / `water` / `wind` elementals ·
> `demon_grunt` · `demon_imp` · `zombie` · `ogre` *(2×2)* · `crucible_golem` · `homunculus` ·
> `miller_ghost` · `blightstake` · `gaunt_vigil` · `wolfsong_spirit` · … and the rest, from `art-report`

### Phase 4 — the objects (7)

`banner` · `march_standard` · `straw_sentry` · `totem` and three others. Inanimate things that stand on
the board and can be destroyed. They need a skeleton only in the loosest sense: a sway, a hit reaction
and a topple. Cheapest group in the game and worth quoting separately.

## Licensing

**Full commercial rights / work-for-hire buyout** — use in a commercial game and its marketing, no
project-count limit. **100% human-authored, no AI-generated content.** Delivery includes the editable
Spine source so the rigs can be maintained. Credit welcome, not required.
