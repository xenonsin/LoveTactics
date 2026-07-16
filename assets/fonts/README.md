# Fonts

Drop a Unicode TrueType/OpenType font here named **`ui.ttf`** to override the built-in LÖVE font
for the dialogue overlay (`ui/dialogue.lua`). This is required to render non-Latin languages —
the default font has no CJK glyphs, so Japanese/Chinese/Korean would show as blank boxes.

Recommended: **Noto Sans JP** (or Noto Sans CJK), licensed under the SIL Open Font License, which
covers Latin + Japanese and is redistributable. Download the `.otf`/`.ttf`, rename it to `ui.ttf`,
and place it in this folder.

Without `ui.ttf`, the game falls back to the built-in font — fine for English, tofu for CJK.
Do **not** commit proprietary system fonts (Yu Gothic, MS Gothic, etc.) here.
