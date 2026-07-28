# UI style — "Etched Atmosphere" (register 5)

The game's UI chrome is a **dark, moody register**: **cool neutral-slate** panels under **bone-gold
engraved frames**, with warm **bone** text — an etched look over a shadowed ground, easy on the eyes
across a long session. It is defined once, in [`ui/theme.lua`](../ui/theme.lua), and every panel builds
from it so the whole UI reads as one designed object.

The ground is **cool on purpose**: gold trim + bone text are warm accents, so the ground must be their
*complement* (cool) to read as trim. A warm-brown ground makes gold + brown analogous and muddies into
one mass; violet is that cool ground pushed too far.

(An earlier light "parchment" register was tried and pulled — too bright in practice. The centralised
theme made the swap a one-file change.)

## The rule: reskin the frame, never the information

- **Chrome** — panel fills, borders, body/label text, section captions — comes from `ui/theme.lua`.
- **Data** — faction colour, resource-bar fills, range/target washes, cost badges, intent marks —
  stays in [`ui/colors.lua`](../ui/colors.lua) and [`ui/glyphs.lua`](../ui/glyphs.lua), **unchanged**.
  Those colours mean something at a glance and must survive on any ground. On the dark stock they read
  as authored (they were always tuned for a dark UI); bars carry a faint dark `Theme.barOutline`.

## Palette

Colours are `{ r, g, b }` floats (0–1), the love.graphics / `ui/colors.lua` convention.

### Surfaces — the dark stock (panel raised a step above the mount, slot recessed below)

| Token          | Hex       | Use                                             |
|----------------|-----------|-------------------------------------------------|
| `Theme.mount`  | `#0e0f10` | shadowed screen ground behind the panels        |
| `Theme.panel`  | `#1d1e21` | a panel face (the raised surface)               |
| `Theme.panel2` | `#17181b` | a card / row inset on a panel                   |
| `Theme.slot`   | `#121315` | an action slot / deepest inset                  |

### Ink — everything drawn on the stock

Edges come in **three tiers** so gold reads as a *rank*, not a coat of paint. One bright gold on every
border made nothing stand out; now the default border is a quiet bronze, internal dividers are a cool
near-invisible hairline, and the bright gold (`accentAmber`, below) is the **spotlight** — spent only on
what's focused or live.

| Token            | Hex       | Use                                                        |
|------------------|-----------|------------------------------------------------------------|
| `Theme.frame`    | `#6b6047` | the standard panel border — a quiet bronze that recedes    |
| `Theme.hairline` | `#2f3238` | internal dividers / card insets — cool, near-invisible     |
| `Theme.ink`      | `#ece4d4` | body text, labels, values (warm bone)                      |
| `Theme.muted`    | `#a89a7e` | secondary text (a label beside its value, hints)           |

### Board

| Token            | Hex       | Use                       |
|------------------|-----------|---------------------------|
| `Theme.tile`     | `#4f3d40` | a board tile              |
| `Theme.tile2`    | `#3f2f34` | the checker's second tile |
| `Theme.boardEdge`| `#160e14` | grid lines                |

(The live battle board keeps its biome terrain art — it's the battlefield, not chrome. These tokens
are for abstract grids/diagrams.)

### Bars

| Token              | Value           | Use                                  |
|--------------------|-----------------|--------------------------------------|
| `Theme.barTrack`   | `#0d0a0f`       | the empty well behind a pool fill    |
| `Theme.barOutline` | black @ 35%     | soft hairline so a fill stays crisp  |

### Accents

| Token                | Hex       | Use                                       |
|----------------------|-----------|-------------------------------------------|
| `Theme.accentWeapon` | `#e0724f` | weapon-title red / hostile heading (warm)        |
| `Theme.accentAmber`  | `#d4ba72` | **spotlight gold** — the focused card, a section caption, an initiative number, a ready action. Spent sparingly; if it's everywhere it's the frame's job, not the accent's. |

Badges keep their bright tints (gold speed, red warn, lavender charges) — each rides its own dark pill.

## Typography — a two-tier serif/sans pairing (Alegreya family)

- `Theme.display(size)` — the **chrome voice**: titles, unit names, section captions, item names.
  Serif, **Alegreya** at `assets/fonts/ui.ttf` (OFL).
- `Theme.body(size)` — **dense data**: stat numbers, `HP 70/70`, tags, log lines, where crisp digits
  beat character. Sans, **Alegreya Sans** at `assets/fonts/ui-body.ttf` (OFL) — the family's own
  companion face.
- `Theme.displayItalic(size)` / `Theme.bodyItalic(size)` — real italic cuts (**Alegreya Italic** /
  **Alegreya Sans Italic**, at `ui-italic.ttf` / `ui-body-italic.ttf`), for a flavor line or prose
  aside. LÖVE cannot synthesize a slant, so italic prose needs a genuine italic face; these fall back
  to the *upright* face (not the LÖVE default) when the ttf is absent.

All fall back gracefully if a ttf is missing. `Theme.R` (= 3) is the shared near-sharp corner radius.

## Section captions & flourishes

- `Theme.caption(text, x, y, w)` — an **UPPERCASE** section header centred with a short rule fading out
  to **each side** (flanking lines, never a centered underscore). The function upper-cases the text, so
  callers pass normal case (`"Turn Order"` → `TURN ORDER`).
- `Theme.crest(cx, cy, r, color)` — a small heraldic crest (shield + sigil), worn flanking a title.
- `Theme.corners(x, y, w, h, len, color)` — carved L-bracket corner ornaments (the engraved-plate look).
- `Theme.leader(x1, x2, y, color)` — a dotted leader line between a label and its value (tooltip rows).
- `Theme.drawMount(w, h)` — the atmospheric ground: a warm vertical gradient behind the panels
  (darker aloft, a faint ember below), in place of a flat mount fill.

## Helpers

- `Theme.set(color, a)` — `love.graphics.setColor` from a theme entry.
- `Theme.fill(surface, x, y, w, h, r)` — a rounded surface fill.
- `Theme.plate(x, y, w, h, r, surface)` — surface fill + bone-gold border (the standard panel).
