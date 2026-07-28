-- The UI THEME: register 5, "Etched Atmosphere". The single source of truth for the game's CHROME --
-- the surfaces, frames, ink and section-labels every panel is built from -- so the whole UI reads as
-- one designed object instead of 51 files each picking their own greys.
--
-- ---------------------------------------------------------------------------
-- WHAT THIS OWNS vs WHAT IT DOESN'T
--
-- This module owns the CHROME: panel fills, borders, body/label text, board tiles, the dark stock the
-- game is printed on. It is a DARK, moody register -- cool neutral-slate panels under bone-gold engraved
-- frames, with warm bone text -- an etched look over a shadowed ground, easy on the eyes across a long
-- session. The ground is COOL on purpose: it complements the warm gold/bone accents so they read as
-- trim, where a warm-brown ground muddied into one mass (the light-parchment register 1 was too bright;
-- see [[ui-theme]]).
--
-- It deliberately does NOT own the DATA layer. Faction colour, resource-bar fills, range washes, cost
-- badges and intent marks stay in ui/colors.lua and ui/glyphs.lua and are UNCHANGED: their job is to
-- MEAN something at a glance, and that meaning has to survive on any ground. A parchment reskin repaints
-- the frame around the information, never the information. (The one concession the light ground forces:
-- a bar needs a hairline `barOutline` so its fill doesn't bleed into the parchment -- see ui/*_bar draws.)
--
-- Colours are { r, g, b } floats in 0..1 (love.graphics convention, same as ui/colors.lua), some with a
-- fourth alpha. Plain data at require-time, no love.graphics -- fonts load lazily -- so it stays safe
-- under the headless test runner (see CLAUDE.md).
-- ---------------------------------------------------------------------------

local Colors = require("ui.colors")

local Theme = {}

-- ---- SURFACES (the printed stock) ---------------------------------------------------------------
-- A three-step stack, lightest plate on darkest mount, so a card reads as sitting ON the panel. Here
-- "lightest" means the highest-value DARK: panel is a touch above the mount, slot recedes below it.
-- A NEUTRAL COOL SLATE, deliberately desaturated: warm gold trim + bone text are the accents, so the
-- ground must be their COMPLEMENT (cool) to read as contrast, not their neighbour (warm brown) which
-- muddies into one mass. A whisper cool (b > g > r), never violet.
Theme.mount   = { 0.055, 0.058, 0.064 } -- #0e0f10  the ground: the shadowed screen behind the panels
Theme.panel   = { 0.112, 0.118, 0.130 } -- #1d1e21  a panel face (the raised surface)
Theme.panel2  = { 0.089, 0.094, 0.105 } -- #17181b  a card/row inset on a panel
Theme.slot    = { 0.069, 0.074, 0.084 } -- #121315  an action-slot / deepest inset

-- ---- INK (everything drawn ON the stock) --------------------------------------------------------
-- Edges come in THREE TIERS so gold reads as a rank, not a coat of paint (see [[ui-theme]]). Before,
-- one bright gold framed every panel AND every inset AND every accent, so nothing stood out. Now:
--   frame    -- the quiet default border every plate wears (a demoted bronze, still gold-family)
--   hairline -- internal dividers/row insets, so cool they nearly vanish (structure, not ornament)
--   accentAmber (below) -- the bright spotlight gold, spent only on what's FOCUSED / live
Theme.frame    = { 0.420, 0.376, 0.278 } -- #6b6047  the standard panel border -- quiet bronze, recedes
Theme.hairline = { 0.184, 0.196, 0.220 } -- #2f3238  internal dividers / card insets -- cool, near-invisible
Theme.ink      = { 0.925, 0.894, 0.831 } -- #ece4d4  body text, labels, values, section captions (warm bone)
Theme.muted    = { 0.659, 0.604, 0.494 } -- #a89a7e  secondary text: a label beside its value, a hint

-- ---- BOARD (the battlefield map is printed on the same stock) ------------------------------------
Theme.tile      = { 0.310, 0.240, 0.250 } -- #4f3d40  a board tile
Theme.tile2     = { 0.247, 0.184, 0.204 } -- #3f2f34  the checker's second tile
Theme.boardEdge = { 0.086, 0.055, 0.078 } -- #160e14  the grid lines between tiles

-- ---- BARS (resource pools) ----------------------------------------------------------------------
-- Fills stay semantic (Colors.PARTY / MANA / STAMINA ...). The track is a near-black well so the fill
-- reads, and every bar carries a faint dark outline so it stays crisp on the dark panels.
Theme.barTrack   = { 0.036, 0.038, 0.044 }  -- #090a0b
Theme.barOutline = { 0.000, 0.000, 0.000, 0.35 } -- a soft dark hairline

-- ---- ACCENTS ------------------------------------------------------------------------------------
-- The weapon-title red and the SPOTLIGHT gold, pitched bright to read on the dark stock. accentAmber is
-- the top tier of the edge system (see INK above): it is spent SPARINGLY -- the focused card, a section
-- caption, an initiative number, a ready action -- so that gold now MEANS "look here" instead of coating
-- every border. If it's on screen everywhere, it's the frame's job, not the accent's.
Theme.accentWeapon = { 0.880, 0.450, 0.330 } -- #e0724f  a weapon accent / hostile heading (warm red)
Theme.accentAmber  = { 0.831, 0.729, 0.447 } -- #d4ba72  the spotlight gold: focus / captions / initiative

-- The data layer, re-exported so a widget can require ONE module. These are ui/colors.lua verbatim --
-- pass-through, not copies -- so faction/pool meaning stays defined in exactly one place.
Theme.Colors = Colors

-- ---- helpers ------------------------------------------------------------------------------------

-- Set the draw colour from a theme entry, with an optional alpha override (else the entry's own 4th
-- component, else opaque). `Theme.set(Theme.ink)` / `Theme.set(Theme.frame, 0.5)`.
function Theme.set(c, a)
    love.graphics.setColor(c[1], c[2], c[3], a or c[4] or 1)
end

-- Fonts. The display face (assets/fonts/ui.ttf, an engraved/old-style serif) carries the chrome --
-- titles, names, section captions -- and gives the parchment its period voice; it falls back to the
-- LOVE default until the face is dropped in, so nothing breaks before the art lands (same tolerant
-- pattern as ui/dialogue.lua). Cached per size. Numbers/dense data can stay on the default face where
-- legibility beats character -- callers choose.
local FONT_PATH = "assets/fonts/ui.ttf"      -- display: the engraved/old-style serif (Alegreya)
local BODY_PATH = "assets/fonts/ui-body.ttf" -- body: the companion sans for dense data (Alegreya Sans)
-- LOVE does NOT synthesize italics -- a slanted face must be a real font -- so italic prose (a flavor
-- line, an aside) needs its own loaded face, or it renders upright. These are the true italic cuts.
local ITALIC_PATH = "assets/fonts/ui-italic.ttf"           -- Alegreya Italic
local BODY_ITALIC_PATH = "assets/fonts/ui-body-italic.ttf" -- Alegreya Sans Italic
local displayCache, bodyCache, italicCache, bodyItalicCache = {}, {}, {}, {}
local hasDisplay, hasBody, hasItalic, hasBodyItalic = nil, nil, nil, nil

-- Text crispness at any window size. The whole game is authored in a 1280x720 logical space and
-- letterbox-scaled UP to the real window (see scale.lua); a font's glyph atlas is baked ONCE at its
-- point size, so when the window is maximised/fullscreened that fixed atlas gets transform-scaled up
-- and the text goes soft -- the "Turn Order / Current Turn / Actions / Wait" captions were the first
-- to show it. LOVE's newFont(path, size, hinting, DPISCALE) bakes the atlas at size*dpiscale pixels
-- while still reporting every metric (getWidth/getHeight) in LOGICAL units -- so baking at the largest
-- scale the window can ever reach keeps text 1:1 crisp when maximised, downsamples cleanly when the
-- window is smaller, and needs ZERO changes to any layout/widget code. Computed once from the desktop
-- size (the ceiling on how large the window can grow), clamped and guarded for the headless runner.
local fontDpi
local function fontDpiScale()
    if fontDpi then return fontDpi end
    fontDpi = 1
    if love.window and love.window.getDesktopDimensions then
        local ok, dw, dh = pcall(love.window.getDesktopDimensions)
        if ok and dw and dh and dw > 0 and dh > 0 then
            -- Match scale.lua's fit: the window can grow until the logical space fills the desktop.
            fontDpi = math.min(dw / 1280, dh / 720)
        end
    end
    -- Never bake SMALLER than the logical size (a sub-1 desktop is nonsense); cap for atlas-memory sanity.
    fontDpi = math.max(1, math.min(fontDpi, 4))
    return fontDpi
end
function Theme.display(size)
    size = size or 15
    local f = displayCache[size]
    if f then return f end
    if hasDisplay == nil then
        hasDisplay = love.filesystem.getInfo(FONT_PATH) ~= nil
    end
    f = hasDisplay and love.graphics.newFont(FONT_PATH, size, "normal", fontDpiScale()) or love.graphics.newFont(size)
    displayCache[size] = f
    return f
end
function Theme.body(size)
    size = size or 13
    local f = bodyCache[size]
    if f then return f end
    if hasBody == nil then
        hasBody = love.filesystem.getInfo(BODY_PATH) ~= nil
    end
    f = hasBody and love.graphics.newFont(BODY_PATH, size, "normal", fontDpiScale()) or love.graphics.newFont(size)
    bodyCache[size] = f
    return f
end
-- The italic serif (Alegreya Italic), for a flavor line or a prose aside. Falls back to the UPRIGHT
-- display face when the italic ttf is absent -- never to the LOVE default -- so it degrades to
-- non-slanted rather than off-family.
function Theme.displayItalic(size)
    size = size or 13
    local f = italicCache[size]
    if f then return f end
    if hasItalic == nil then hasItalic = love.filesystem.getInfo(ITALIC_PATH) ~= nil end
    f = hasItalic and love.graphics.newFont(ITALIC_PATH, size, "normal", fontDpiScale()) or Theme.display(size)
    italicCache[size] = f
    return f
end
-- The italic sans (Alegreya Sans Italic), for an italic aside in a data-face context.
function Theme.bodyItalic(size)
    size = size or 13
    local f = bodyItalicCache[size]
    if f then return f end
    if hasBodyItalic == nil then hasBodyItalic = love.filesystem.getInfo(BODY_ITALIC_PATH) ~= nil end
    f = hasBodyItalic and love.graphics.newFont(BODY_ITALIC_PATH, size, "normal", fontDpiScale()) or Theme.body(size)
    bodyItalicCache[size] = f
    return f
end

-- One-line text pinned to a fixed width WITHOUT scaling the font. Project rule: never pass a scale
-- factor to love.graphics.print for text -- a scaled bitmap font blurs (that is why the acting card's
-- name and every "scaled to fit" name band used to smear). `fontFn` is a size->font factory
-- (Theme.body / Theme.display, both cached). Returns the largest font in [minSize, maxSize] whose render
-- of `text` fits `maxW`, paired with `text` (ellipsized on the smallest size when even that overflows).
-- Draw the returned text with the returned font at native scale (no scale args).
function Theme.fitText(fontFn, text, maxW, maxSize, minSize)
    minSize = minSize or math.max(8, maxSize - 3)
    local font
    for size = maxSize, minSize, -1 do
        font = fontFn(size)
        if font:getWidth(text) <= maxW then return font, text end
    end
    return font, Theme.ellipsize(text, font, maxW)
end

-- Trim `text` with a trailing ellipsis until it fits `maxW` in `font`; returns it unchanged when it
-- already fits. (Item/character names are ASCII here, so trimming by byte is safe.)
function Theme.ellipsize(text, font, maxW)
    if font:getWidth(text) <= maxW then return text end
    while #text > 1 and font:getWidth(text .. "...") > maxW do
        text = text:sub(1, #text - 1)
    end
    return text .. "..."
end

-- Fill a rounded panel/plate in a surface colour. `Theme.fill(Theme.panel, x, y, w, h)`.
function Theme.fill(surface, x, y, w, h, r)
    Theme.set(surface)
    love.graphics.rectangle("fill", x, y, w, h, r or 3, r or 3)
end

-- A framed plate: surface fill + a sepia border. The standard panel look.
function Theme.plate(x, y, w, h, r, surface)
    Theme.fill(surface or Theme.panel, x, y, w, h, r)
    Theme.set(Theme.frame)
    local lw = love.graphics.getLineWidth()
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", x, y, w, h, r or 3, r or 3)
    love.graphics.setLineWidth(lw)
end

-- Letter-spacing for the chrome headers ("TURN ORDER" / "ACTIONS" / the Wait button): the mock sets
-- them as SPACED small-caps, a fixed gap between glyphs the font's own kerning doesn't give.
Theme.TRACK = 3

-- Measure a run of `text` in `font` with `track` letter-spacing between glyphs (no trailing space).
local function trackedWidth(font, text, track)
    local tw = 0
    for i = 1, #text do
        tw = tw + font:getWidth(text:sub(i, i))
        if i < #text then tw = tw + track end
    end
    return tw
end

-- Draw `text` in the current font, letter-tracked and centred within [x, x+w] at baseline `y`. Snaps
-- every glyph to whole logical pixels -- fractional positions blur once the scene is letterbox-scaled
-- (subpixel text under magnification). LOVE's printf can't track text, so lay each glyph by hand.
-- Returns the tracked run width, for callers that flank the text with rules.
function Theme.printTracked(text, x, y, w, track)
    track = track or Theme.TRACK
    local font = love.graphics.getFont()
    local tw = trackedWidth(font, text, track)
    local drawX = x + (w - tw) / 2
    y = math.floor(y + 0.5)
    for i = 1, #text do
        local ch = text:sub(i, i)
        love.graphics.print(ch, math.floor(drawX + 0.5), y)
        drawX = drawX + font:getWidth(ch) + track
    end
    return tw
end

-- A section caption -- ink text centred in [x, w] with a short rule fading out to either side, the
-- "TURN ORDER" / "ACTIONS" header. Flanking lines, never an underscore (the chosen look). Draws in the
-- current font; the caller sets the display face and passes the label's baseline `y`.
function Theme.caption(text, x, y, w, opts)
    opts = opts or {}
    -- Section captions are UPPERCASE -- a header voice that reads as chrome, distinct from body prose.
    text = string.upper(text)
    local font = love.graphics.getFont()
    local track = opts.tracking or Theme.TRACK
    Theme.set(opts.color or Theme.ink)
    local tw = Theme.printTracked(text, x, y, w, track)
    y = math.floor(y + 0.5)
    -- rules flanking the centred text, TAPERED: each fades from transparent (the end beside the word)
    -- to bone-gold at its outer tip -- the mock's `linear-gradient(transparent, frame)` flourish, not a
    -- solid dash. Drawn as short alpha-ramped segments (LOVE lines take no per-vertex alpha).
    local cy = y + font:getHeight() / 2
    local pad = opts.pad or 14           -- gap between the word and the rule
    local reach = opts.reach or 26       -- rule length
    local maxA = opts.ruleAlpha or 0.8
    local cx = x + w / 2
    local lx1 = cx - tw / 2 - pad        -- inner end of the left rule (beside the word)
    local rx1 = cx + tw / 2 + pad        -- inner end of the right rule
    local function taper(xInner, xOuter)
        local n = 18
        for i = 0, n - 1 do
            local xa = xInner + (xOuter - xInner) * (i / n)
            local xb = xInner + (xOuter - xInner) * ((i + 1) / n)
            Theme.set(Theme.frame, maxA * ((i + 0.5) / n)) -- ~0 beside the word, maxA at the tip
            love.graphics.rectangle("fill", math.min(xa, xb), cy - 0.5, math.abs(xb - xa) + 0.6, 1)
        end
    end
    taper(lx1, lx1 - reach)
    taper(rx1, rx1 + reach)
end

-- Register 5 frames are near-sharp; one knob for every panel corner so they stay consistent.
Theme.R = 3

-- The atmospheric GROUND behind the panels: a vertical gradient, darker aloft with a faint warm ember
-- low down, so the screen reads as a lit scene rather than a flat fill (the mock's moody backdrop, kept
-- warm rather than violet). Cached gradient mesh, drawn scaled to (w, h); replaces a flat mount fill.
local mountMesh
function Theme.drawMount(w, h)
    if not mountMesh then
        local top = { 0.036, 0.038, 0.044 } -- aloft: cool near-black
        local bot = { 0.072, 0.076, 0.090 } -- below: a faint cool lift (slate, not ember)
        mountMesh = love.graphics.newMesh({
            { 0, 0, 0, 0, top[1], top[2], top[3], 1 },
            { 1, 0, 1, 0, top[1], top[2], top[3], 1 },
            { 1, 1, 1, 1, bot[1], bot[2], bot[3], 1 },
            { 0, 1, 0, 1, bot[1], bot[2], bot[3], 1 },
        }, "fan", "static")
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(mountMesh, 0, 0, 0, w, h)
end

-- A small heraldic crest centred on (cx, cy), radius r: a shield outline with a four-point sigil.
-- The chrome's one figurative mark, worn beside a title. Draws in `color` (default the bone-gold frame).
function Theme.crest(cx, cy, r, color)
    color = color or Theme.frame
    love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    local lw = love.graphics.getLineWidth()
    love.graphics.setLineWidth(1.4)
    love.graphics.polygon("line",
        cx - r * 0.8, cy - r * 0.85, cx + r * 0.8, cy - r * 0.85,
        cx + r * 0.8, cy + r * 0.05, cx, cy + r, cx - r * 0.8, cy + r * 0.05)
    love.graphics.setLineWidth(lw)
    local o, i = r * 0.42, r * 0.15
    love.graphics.polygon("fill",
        cx, cy - r * 0.42 - o * 0.1, cx + i, cy - i * 0.2, cx + o, cy - r * 0.1,
        cx + i, cy + i, cx, cy + r * 0.35, cx - i, cy + i, cx - o, cy - r * 0.1, cx - i, cy - i * 0.2)
end

-- Carved L-bracket ornaments at the four corners of a rect -- the engraved-plate look. `len` is the
-- arm length; draws in `color` (default frame). Sits just inside the border it decorates.
function Theme.corners(x, y, w, h, len, color)
    len = len or 8
    Theme.set(color or Theme.frame)
    local lw = love.graphics.getLineWidth()
    love.graphics.setLineWidth(1.4)
    love.graphics.line(x, y + len, x, y, x + len, y)
    love.graphics.line(x + w - len, y, x + w, y, x + w, y + len)
    love.graphics.line(x, y + h - len, x, y + h, x + len, y + h)
    love.graphics.line(x + w - len, y + h, x + w, y + h, x + w, y + h - len)
    love.graphics.setLineWidth(lw)
end

-- A dotted leader line between a label and its value (the tooltip receipt look), from x1 to x2 at y.
function Theme.leader(x1, x2, y, color)
    if x2 - x1 < 6 then return end
    Theme.set(color or Theme.frame, 0.5)
    local x = x1
    while x < x2 do
        love.graphics.rectangle("fill", x, y, 1.5, 1)
        x = x + 3
    end
end

return Theme
