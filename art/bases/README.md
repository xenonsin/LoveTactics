# `art/bases/` — the silhouette set

Drawn base silhouettes, and the one place a commissioned glyph lands.

Everything the composers draw resolves a **slug** (`lorc/broadsword`) to an SVG, and
[tools/icon_source.lua](../../tools/icon_source.lua) answers it from two roots in order:

| root | what it is |
|---|---|
| `art/bases/<slug>.svg` | **drawn art, tracked, ships** — preferred |
| `vendor/game-icons/<slug>.svg` | CC BY 3.0 stand-in, gitignored, development only |

So a delivered glyph takes over **everywhere its slug is used** the moment it lands — one file re-skins
every asset that reduces to it — and the vendored set keeps standing in for the slugs nobody has drawn
yet. The commission can be accepted a glyph at a time and the exposure watched down to zero:

```powershell
& "E:\LOVE\lovec.exe" . art-source slugs   # what is left, most-used first
& "E:\LOVE\lovec.exe" . art-source ship    # exit 1 while any shipped slug is still vendored
& "E:\LOVE\lovec.exe" . art-build          # regenerate everything from the current bases
```

## Keep the slug, keep the folder

A file here mirrors the vendored layout exactly — `art/bases/lorc/broadsword.svg` replaces
`vendor/game-icons/lorc/broadsword.svg`. **The slug is an address, not a credit.** Reusing it means no
remapping table, no blueprint edits, and no code change: the composers never learn where their art came
from. The `lorc/` folder in a path is where the stand-in came from, not a claim about who drew the
replacement.

## The contract every file must meet

The composers do surgery on these, so the shape of the file matters as much as the drawing:

- **`viewBox="0 0 512 512"`**, square.
- **One flat foreground fill of `#fff`.** The composers *substitute that fill* to tint the layer by
  element — orange for fire, blue for ice, steel for a physical strike. Multi-colour art, gradients or
  a hard-coded palette silently defeat the tint channel and the icon comes out the wrong colour with no
  error anywhere.
- **No background rect.** One is stripped if present (game-icons ships one), but do not add one — the
  icon is a bare silhouette on transparency, so it sits inside the action slot's own frame instead of
  fighting it with a second one.
- **Readable as a silhouette at 64px**, and again when **greyed** — fallen and inactive units tint the
  whole sprite down, so identity cannot rest on fine low-contrast detail.
- **Paths, not strokes.** Outline a stroke before delivery; a stroked path scales its weight with the
  layer transform and thickens unpredictably.

Flat single-colour vector, in other words — an icon-design deliverable, not an illustration. The colour,
the frame, the tier pips and the magical aura are all drawn procedurally by the composer from fields the
blueprint already carries; none of them are art anybody has to draw.

## Order the work by what it buys

`. art-source slugs` sorts by how many assets ride on each glyph, and the distribution is steep — the
first few dozen silhouettes carry most of the screen:

| drawn | assets covered |
|---|---|
| top 10 | 37% |
| top 20 | 53% |
| top 40 | 73% |
| top 80 | 85% |
| all 215 | 100% |

`delapouite/claws` alone dresses 73 assets. Draw down the list, not across the catalogue.

The item half of that list — 62 slugs, phased by what each one buys — is written up as a hand-off
brief in [docs/commission-item-icons.md](../../docs/commission-item-icons.md). What bounds it at 62
is the vocabulary in `tools/icon_compose.lua`: a mapped glyph is only drawn when four or more items
share it, so a slug that is not on this list is not art anybody owes.
