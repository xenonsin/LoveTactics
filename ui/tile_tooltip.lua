-- Shared hover tooltip for a battlefield tile: a dark panel showing the tile's terrain type,
-- its movement / line-of-sight / positional modifiers, and — when something stands on it — the
-- occupant's details. A unit shows its side, resource pools (HP / mana / stamina bars) and combat
-- stats; a revealed trap shows its owner and remaining health; a conjured wall shows its owner,
-- health and how long it stands; a prop (a barrel, a crate) shows its health and what breaking it
-- does. Positioned near the mouse and clamped on-screen, mirroring ui/item_tooltip.lua and
-- ui/status_tooltip.lua.
--
--   TileTooltip.draw(info, mx, my, maxRight)
--     info = { cell = <arena tile>, bonus = <fieldBonus bag>, unit = <combat unit|nil>,
--              trap = <revealed trap|nil>, wall = <wall|nil>, prop = <prop|nil>,
--              reinforce = <{ edge, ticksUntil, char }|nil>,   -- a telegraphed muster landing tile
--              objective = <Combat.objectiveTileInfo bag|nil>, -- marked objective ground
--              rally = <Combat.rallyTileInfo bag|nil>,         -- your own lines (the fall-back ground)
--              blocks = <prebuilt block list|nil> }            -- a caller that is not a tile at all
--
-- `blocks` is the seam a non-tile readout comes in through: hand in an assembled list and this draws,
-- measures and clamps it exactly as it does its own (ui/body_tooltip.lua, the Gate's roster card).
--
-- Content is assembled once into an ordered list of blocks that is both measured and drawn, so the
-- computed box height can never drift from what's rendered. No love.graphics at require-time.

local Scale = require("scale")
local Character = require("models.character")
local Combat = require("models.combat")
local Intent = require("models.intent")
local Trap = require("models.trap")
local Prop = require("models.prop")
local Colors = require("ui.colors")
local Glyphs = require("ui.glyphs")
local TerrainArt = require("ui.terrain_art")
local Theme = require("ui.theme")
local PoolCallout = require("ui.pool_callout")

local TileTooltip = {}

local titleFont, bodyFont, smallFont
local function fonts()
    titleFont = titleFont or Theme.display(15) -- name/heading: the serif chrome voice
    bodyFont = bodyFont or Theme.body(12)      -- dense data: the companion sans
    smallFont = smallFont or Theme.body(11)
    return titleFont, bodyFont, smallFont
end

-- Display metadata per terrain type (models/terrain.lua's keys). `name` is the human-readable terrain
-- name; `desc` is a short flavour/mechanics line.
--
-- ALL SIXTEEN, and until now it was six. The other ten fell through to a title-cased id and an empty
-- description, so a player hovering the drift that fills a tundra board read the bare word "Ice" and
-- was told nothing -- not that it is the one floor on the board that does not tax a step, and not that
-- it carries a charge. That was survivable while every tile was one flat colour and nobody could tell
-- them apart anyway; it is not survivable now that each has a picture on it, because THIS is where the
-- picture is learned (see the swatch in appendTerrain, and ui/terrain_art.lua's header).
--
-- What each line says is the thing the mark cannot: a shape can say "trees" and not "costs two and is
-- worth twenty points of somebody's aim". The numbers themselves are rows below, off the live cell --
-- never retyped here, or the two would drift.
local TILE_INFO = {
    ground   = { name = "Open Ground", desc = "Flat, open field. No movement penalty." },
    path     = { name = "Trail",       desc = "A worn track. Open ground, and no faster for being a road." },
    bridge   = { name = "Bridge",      desc = "A built crossing -- the only way over a river." },
    forest   = { name = "Forest",      desc = "Slow to cross. Soft cover that hampers line of sight. It catches fire." },
    thicket  = { name = "Dense Wood",  desc = "Too thick to enter, and nothing sees through it. It catches fire." },
    mountain = { name = "High Ground", desc = "Steep and slow, but grants extra reach and blocks the view behind it." },
    rough    = { name = "Rough Terrain", desc = "Broken ground that slows movement and makes a body harder to hit." },
    rock     = { name = "Standing Rock", desc = "Solid stone. Blocks movement and line of sight." },
    obstacle = { name = "Obstacle",    desc = "Solid terrain. Blocks movement and line of sight." },
    grass    = { name = "Scrub",       desc = "Growth too dense to push through. Blocks movement and line of sight." },
    river    = { name = "River",       desc = "Impassable except at a bridge -- but you can see the far bank perfectly well." },
    water    = { name = "Shallow Water", desc = "Wadeable but slow. Conducts lightning: a bolt striking beside it arcs in." },
    lava     = { name = "Lava Flow",   desc = "Impassable. Like a river it blocks the feet and not the eye." },
    mire     = { name = "Mire",        desc = "Sucking bog. The heaviest ground to cross, and it leaves a body easier to hit. It conducts." },
    sand     = { name = "Loose Sand",  desc = "Heavy going, with nothing to hide behind." },
    ice      = { name = "Ice",         desc = "The one floor that costs nothing to cross. It conducts: a bolt sweeps the whole sheet." },
}

-- Accent per terrain type (title + border tint). Cool for what stops you, warm for what merely slows
-- you, and each family shaded off the one above it so the list reads as four kinds of ground rather
-- than sixteen colours. The MARK is what identifies a terrain (see ui/terrain_art.lua); this only has
-- to keep the heading legible and roughly in the right key.
local TILE_COLOR = {
    ground   = { 0.80, 0.78, 0.62 },
    path     = { 0.80, 0.78, 0.62 },
    bridge   = { 0.82, 0.66, 0.44 },
    forest   = { 0.55, 0.80, 0.55 },
    thicket  = { 0.42, 0.66, 0.44 },
    mountain = { 0.72, 0.74, 0.82 },
    rough    = { 0.80, 0.66, 0.45 },
    rock     = { 0.66, 0.64, 0.62 },
    obstacle = { 0.62, 0.62, 0.68 },
    grass    = { 0.60, 0.76, 0.50 },
    river    = { 0.45, 0.68, 0.95 },
    water    = { 0.45, 0.68, 0.95 },
    lava     = { 0.95, 0.55, 0.30 },
    mire     = { 0.62, 0.72, 0.44 },
    sand     = { 0.90, 0.80, 0.54 },
    ice      = { 0.72, 0.88, 0.95 },
}
local DEFAULT_COLOR = { 0.86, 0.87, 0.92 }

-- The terrain vocabulary, exported so tests/terrain_art_spec.lua can ask the real question -- "is this
-- type AUTHORED here" -- rather than a proxy for it. Reading it back off the built blocks cannot tell
-- an authored "Bridge" from the fallback's title-cased `bridge`, and a guard that cannot see the fault
-- it exists to catch is worse than none.
TileTooltip.TERRAIN = TILE_INFO

-- The swatch that teaches the mark: a square of the tile's own ground tone with the terrain's mark
-- drawn on it, set beside the name.
--
-- It takes its size from the HEADING'S OWN LINE HEIGHT rather than a constant, which is the whole
-- reason it needs no entry in measureBlocks: a square that is never taller than the row it sits on
-- cannot change the row's height, and this file's box height is measured once and drawn once from the
-- same list precisely so the two can never disagree. Whatever font the heading is in -- the serif
-- title on a bare tile, the smaller sans when a body owns the title above it -- the swatch matches it.
local SWATCH_GAP = 6

-- Draw the mark for `kind` on its ground tone at (x, y), `size` square, and answer how far the text
-- after it must move right. Zero, and nothing drawn, when there is no swatch to show.
local function drawSwatch(b, x, y, size)
    if not (b.swatch and b.tone) then return 0 end
    local t = b.tone
    love.graphics.setColor(t[1], t[2], t[3], 1)
    love.graphics.rectangle("fill", x, y, size, size, 2, 2)
    TerrainArt.draw(b.swatch, x, y, size, size, t[1], t[2], t[3], 3, 5)
    Theme.set(Theme.frame, 0.45) -- the same hairline the box itself is trimmed in
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x + 0.5, y + 0.5, size - 1, size - 1, 2, 2)
    return size + SWATCH_GAP
end

local PARTY_COLOR = Colors.PARTY
local ENEMY_COLOR = Colors.ENEMY

-- The muster red the board marks a landing zone in (ui/battle_map.lua MUSTER) -- a threat arriving,
-- kept apart from the orange of a hostile field. The reinforcement box borrows it so the tooltip and
-- the tile the player is hovering read as the same warning.
local MUSTER_COLOR = { 0.88, 0.24, 0.18 }

-- The side a muster walks in from, in board terms (the resolved edge; see Combat.resolveWaveEdge).
local EDGE_LABEL = { top = "Top edge", bottom = "Bottom edge", left = "Left flank", right = "Right flank" }

local MUTED = Theme.muted
local VALUE = Theme.ink
local DESC = Theme.ink

local GLYPH_GAP = 4 -- between a row's glyph and the value it marks (matches ui/item_tooltip.lua)
local BAR_GLYPH_W = 7 -- the resource mark ahead of a pool bar's HP/MP/SP tag
local PAIR_GAP = 14 -- the gutter between the two halves of a paired row

-- Lay `rows` out two to a line as `pair` blocks. Each row is a half: `{ label, value, valueColor,
-- labelColor, hourglass }` -- the same shape a full-width `stat` or `status` block carries, because
-- one renderer draws all three (drawLeaderRow).
--
-- WHY ANYTHING IS PAIRED AT ALL: this box docks into a column 288 wide and 652 tall, and it shares
-- that column with the ground underfoot and with the whole exchange while a blow is being aimed. Eight
-- stat rows spend 144px of it printing eight two-digit numbers, each alone on a line wide enough for
-- three of them. Paired, the same eight numbers cost 72 and read as a grid -- which is how a stat
-- block wants to be read anyway, in pairs down a column rather than as a list.
--
-- An odd last row keeps its own line with the right half empty, rather than stretching across it: a
-- lone value sliding out to the far edge breaks the column the rows above it just made.
local function appendPairs(blocks, rows)
    for i = 1, #rows, 2 do
        blocks[#blocks + 1] = { kind = "pair", left = rows[i], right = rows[i + 1] }
    end
end

-- Resource pools shown as labeled bars, in draw order. Health has no fixed colour: it's filled with
-- the unit's SIDE colour (blue ally / red foe) like the board token's bar and the turn card's, so
-- the same unit reads the same way wherever it's shown. Resolved per unit in appendUnit.
local RESOURCES = {
    { stat = "health",  label = "HP" },
    { stat = "mana",    label = "MP", color = Colors.MANA },
    { stat = "stamina", label = "SP", color = Colors.STAMINA },
}

-- Flat combat stats shown as label/value rows, in draw order.
local STAT_ROWS = {
    { stat = "damage",       label = "Damage" },
    { stat = "magicDamage",  label = "Magic Dmg" },
    { stat = "defense",      label = "Defense" },
    { stat = "magicDefense", label = "Magic Def" },
    { stat = "movement",     label = "Movement" },
    { stat = "speed",        label = "Speed" },
    -- The two accuracy stats (docs/accuracy.md). They belong on this readout for the same reason
    -- Defense does: the player is about to be told a hit chance by the action preview, and these are
    -- what that number is made of. Without them a 79% is a fact with no explanation attached, and no
    -- way to tell a body that is hard to hit from one that is merely lucky about crits.
    { stat = "skill",        label = "Skill" },
    { stat = "luck",         label = "Luck" },
}

-- THE INTENT SECTION (models/intent.lua). The board badge and the turn card both draw a foe's coming
-- turn as a bare glyph and a number, which is the right density for a mark worn over a sprite and the
-- wrong one for learning what that mark MEANS. This section is where it is glossed: the same glyph, in
-- the same kind colour, sitting next to the word it stands for, on the readout the player already
-- opens by hovering the body or its turn card.
--
-- `name` is the word; `desc` is the one flat sentence that separates the kind from its neighbours --
-- what an Attack is that an Ability isn't. The target and the figure are rows rather than part of that
-- sentence, so no number is quoted twice.
--
-- NOT WRITTEN HERE. The sentences live beside the classifier that produces the kind
-- (models/intent.lua's Intent.GLOSS), because the turn card's icon now hangs its own hover note off
-- the same words (ui/combat_panel.lua's intentNote) and two boxes glossing one mark must not drift
-- apart. tests/intent_note_spec.lua reads this file's source to keep them from being re-inlined here.
local INTENT_KINDS = Intent.GLOSS

-- The foe's predicted turn, appended as its own section: the mark and its name, who it comes for, and
-- the figure the badge quotes -- labelled here, because a bare number on a card cannot say whether it
-- is damage dealt or healing given.
--
-- A hold (`wait`) prints the mark and its sentence and nothing else: there is no target to name and no
-- figure to quote, and a "Target: nobody" row would be a row about an absence.
local function appendIntent(blocks, intent)
    local kind = intent.kind or "wait"
    local def = INTENT_KINDS[kind] or INTENT_KINDS.wait
    -- THE HEADING IS THE ROW'S OWN LABEL. A "Intent" line with the mark on the line under it spent two
    -- rows saying one thing, in a box that has to share its column with the ground and the whole
    -- exchange. "Intent .... [mark] Attack" is the same statement on one line, and it reads as the
    -- stat rows above it do -- the question on the left, the answer on the right.
    blocks[#blocks + 1] = { kind = "sep" }
    blocks[#blocks + 1] = { kind = "intent", label = "Intent", name = def.name, glyphKind = kind,
        color = Colors.INTENT[kind] or Colors.INTENT.wait }
    local rows = {}
    local target = intent.target
    if kind ~= "wait" and target and target.char then
        rows[#rows + 1] = { label = "Target",
            value = target.char.name or "Unit", valueColor = Colors.unit(target) }
    end
    -- Only the two figures the badge itself quotes, and only where they are real: a strike shows the
    -- damage it lands, a support cast the healing it gives. A debuff's mark already says "a status",
    -- and the classifier counts those without naming them, so there is no row here worth printing.
    --
    -- LABELLED WITH THE VERB, not with "Damage" -- the unit's own Damage stat is a row in this very
    -- box, eight lines up, and two rows reading "Damage 8" / "Damage 12" about entirely different
    -- things is worse than no figure at all. "Deals" / "Heals" also say who the number happens TO,
    -- which "Damage" never did.
    local dmg = (kind == "attack" or kind == "cast") and (intent.amount or 0) or 0
    local heal = (kind == "support") and (intent.heal or 0) or 0
    if dmg > 0 then
        rows[#rows + 1] = { label = "Deals", value = tostring(math.floor(dmg + 0.5)) }
    elseif heal > 0 then
        rows[#rows + 1] = { label = "Heals",
            value = tostring(math.floor(heal + 0.5)), valueColor = Colors.HEALING }
    end
    -- Who it comes for and what it lands, on one line: two short answers to the one question the
    -- section exists to ask, and the column has other things to hold while this box is open.
    appendPairs(blocks, rows)
    blocks[#blocks + 1] = { kind = "desc", text = def.desc }
end

-- A key rendered as words: a camelCase stat name (`magicDamage`) carries a word boundary at the hump,
-- so the "... bonus" line below reads "Magic Damage bonus" rather than "MagicDamage bonus".
local function titleCase(s)
    return (tostring(s):gsub("(%l)(%u)", "%1 %2"):gsub("^%l", string.upper))
end

-- Round a status duration to 1 decimal, dropping a trailing ".0" so whole turns read as "3"
-- (matches ui/status_tooltip.lua).
local function fmtDuration(n)
    local rounded = math.floor((tonumber(n) or 0) * 10 + 0.5) / 10
    return (rounded % 1 == 0) and tostring(math.floor(rounded)) or string.format("%.1f", rounded)
end

-- Describe a sight cost (how much a tile obstructs a shot passing through it) in words.
local function coverText(sightCost)
    sightCost = sightCost or 0
    if sightCost == math.huge then return "Blocks sight" end
    if sightCost >= 2 then return "Blocks sight" end
    if sightCost == 1 then return "Soft cover" end
    return "Clear"
end

-- The accent (title/border) colour for the hovered tile: the occupant drives it when present
-- (it's the priority), else the terrain type.
local function accentFor(info)
    local unit = info.unit
    if unit and unit.char then
        return Colors.unit(unit)
    end
    if info.trap then
        return info.trap.side == "party" and PARTY_COLOR or ENEMY_COLOR
    end
    -- A wall takes a side like a trap (whoever raised it), and the board draws it the same stone grey
    -- either way -- so the tooltip is the only place the ownership shows, and it says it in the tint.
    if info.wall then
        return info.wall.side == "party" and PARTY_COLOR or ENEMY_COLOR
    end
    -- A prop takes no side, so it borrows its own blueprint colour rather than a team's -- the same
    -- rust-red or pine the board draws it in, which is what ties the tooltip to the block on the tile.
    if info.prop then
        return (info.prop.def and info.prop.def.color) or DEFAULT_COLOR
    end
    if info.reinforce then
        return MUSTER_COLOR
    end
    return TILE_COLOR[(info.cell or {}).type] or DEFAULT_COLOR
end

-- Append the terrain section (type name, flavour, movement / line-of-sight / positional
-- modifiers). `asHead` demotes the name from a top-level title to a section heading, used when a
-- unit/trap owns the title above it.
local function appendTerrain(blocks, info, asHead)
    local cell = info.cell or { type = "ground" }
    local meta = TILE_INFO[cell.type] or { name = titleCase(cell.type or "Tile"), desc = "" }
    local col = TILE_COLOR[cell.type] or DEFAULT_COLOR

    -- The heading carries the board's own swatch when the caller handed one over (`info.tone`, from
    -- BattleMap:tileTone): the exact tone that tile is painted in, with its mark on it. This is the
    -- dwell surface for ui/terrain_art.lua's vocabulary -- the player meets the picture here, next to
    -- the words and the move cost, and afterwards recognises it on the ground at a glance. Absent
    -- whenever the board is drawing a real tileset sheet instead, and the heading is then just a
    -- heading, exactly as it was.
    blocks[#blocks + 1] = { kind = asHead and "head" or "title", text = meta.name, color = col,
                            swatch = info.tone and cell.type or nil, tone = info.tone }
    if meta.desc and meta.desc ~= "" then
        blocks[#blocks + 1] = { kind = "desc", text = meta.desc }
    end

    -- THE TWO THINGS EVERY TILE SAYS -- what it costs to walk on and what it does to a sightline --
    -- share a line, because they are read together and because this box shares its column with the
    -- body standing here and with the whole exchange while a blow is aimed. The watch tax stays on a
    -- line of its own: it is not a property of the ground (see below) and must not be read as one.
    local ground = {}
    if cell.walkable == false then
        ground[#ground + 1] = { label = "Movement", value = "Impassable", valueColor = ENEMY_COLOR }
    else
        -- The tile's own price, and then what somebody watching it adds. Two lines rather than one
        -- summed figure: the ground charges what it charges whoever walks on it, while the tax is a
        -- fact about an enemy currently standing beside this square and will lift when they stop --
        -- folding them together would say the mud got deeper.
        local mc = cell.moveCost or 1
        ground[#ground + 1] = { label = "Move cost", value = tostring(mc),
            valueColor = mc > 1 and { 0.92, 0.72, 0.42 } or VALUE }
    end
    ground[#ground + 1] = { label = "Line of sight", value = coverText(cell.sightCost) }
    appendPairs(blocks, ground)
    if cell.walkable ~= false and info.watched then
        blocks[#blocks + 1] = { kind = "stat", label = "Watched", value = "+" .. tostring(info.watched),
            valueColor = ENEMY_COLOR }
    end

    -- Positional bonuses granted for standing here (terrain + any field object), aggregated by
    -- combat into a flat bag, e.g. { range = 1 }.
    for _, stat in ipairs({ "avoid", "range", "damage", "magicDamage", "defense", "magicDefense", "movement" }) do
        local amount = info.bonus and info.bonus[stat]
        if amount and amount ~= 0 then
            -- Reach from a vantage is a SIGHTLINE, so it lengthens shots and nothing else (see
            -- Combat.fieldRangeBonus). Say so on the tile, or a melee player reads "+1 Range" as a
            -- promise the swing won't keep.
            --
            -- Avoid leads the list, and is the one bonus written as a percentage because that is the
            -- unit it is spent in -- it comes straight off an attacker's hit chance (docs/accuracy.md).
            -- It is also the most important thing a tile can say since accuracy landed: cover is the
            -- positional decision this game has instead of facing, and a forest that did not mention
            -- being worth 20 points of somebody's aim would be asking the player to know that already.
            local label = stat == "range" and "Range bonus (ranged)"
                or stat == "avoid" and "Cover (harder to hit)"
                or (titleCase(stat) .. " bonus")
            local shown = (amount > 0 and "+" or "") .. tostring(amount) .. (stat == "avoid" and "%" or "")
            blocks[#blocks + 1] = { kind = "stat", label = label,
                value = shown,
                valueColor = amount > 0 and { 0.55, 0.85, 0.55 } or ENEMY_COLOR }
        end
    end
end

-- Append a unit occupant's readout: name (as the title), side, resource pools, and combat stats.
-- `preview` (optional, a Combat.previewAbility entry for this unit) makes the HP bar show the
-- damage/heal an aimed ability would do: an amber "to be lost" segment (or green "to be gained"),
-- with the value it would settle at quoted by a floating callout pill (ui/pool_callout.lua) -- the
-- same blueprint the acting card's pool stack uses, so one preview reads the same on both surfaces.
local function appendUnit(blocks, unit, preview, intent)
    local char = unit.char
    local sideCol = Colors.unit(unit)
    -- An ally we don't command reads as its own thing ("Ally (auto)"), matching the green the board
    -- token wears for it, so a survivor isn't taken for a party member you can order about.
    local uncommanded = unit.side == "party" and (unit.control == "ai" or unit.control == "none")
    local sideLabel = unit.side == "party" and (uncommanded and "Ally (auto)" or "Ally") or "Enemy"
    -- THE SIDE RIDES THE NAME LINE rather than taking a row under it. It is one word, it is already
    -- the colour the name is printed in, and a row of its own bought nothing but 18px of a column that
    -- has none to spare. On the name line it reads as what it is: which of the two this body is.
    blocks[#blocks + 1] = { kind = "title", text = (char.name or "Unit"), color = sideCol,
        right = sideLabel, rightColor = sideCol }

    -- Net change to the health pool the aimed ability would cause (damage negative, heal positive).
    local hpDelta = 0
    if preview then hpDelta = (preview.heal or 0) - (preview.damage or 0) end

    -- HEALTH TAKES A LINE OF ITS OWN and the two spendable pools share the one under it. Health is the
    -- pool an aimed blow forecasts on, and the pill quoting that forecast needs the width to float in;
    -- mana and stamina are never previewed and are read as a pair anyway -- what this body can still
    -- spend. Three full-width bars cost 81px of a column that also holds the ground and the exchange.
    local spendable = {}
    for _, r in ipairs(RESOURCES) do
        local res = char.stats and char.stats[r.stat]
        -- Only pools the unit actually has (max > 0); a beast with no mana skips the MP bar.
        if type(res) == "table" and (res.max or 0) > 0 then
            -- A reservation (sustaining a summon) lowers the ceiling `current` can reach without
            -- touching `max`, so the bar reads against the ceiling while still drawing the locked
            -- slice at its far end -- the pool you have, and the pool you've committed.
            local reserved = Combat.reservedAmount(char, r.stat)
            local block = { kind = "bar", label = r.label, stat = r.stat,
                cur = res.current or 0, max = res.max - reserved, color = r.color or sideCol }
            if reserved > 0 then
                block.reserved = reserved
                block.fullMax = res.max
            end
            if r.stat == "health" and hpDelta ~= 0 then
                block.delta = hpDelta
                block.lethal = preview and preview.lethal
            end
            if r.stat == "health" then
                blocks[#blocks + 1] = block
            else
                spendable[#spendable + 1] = block
            end
        end
    end
    -- A body with only one of the two keeps it full width: half a row with nothing beside it would
    -- read as a pool that had lost something, which is exactly what a bar is for saying.
    if #spendable == 2 then
        blocks[#blocks + 1] = { kind = "barPair", left = spendable[1], right = spendable[2] }
    else
        for _, block in ipairs(spendable) do blocks[#blocks + 1] = block end
    end

    -- Two to a line (appendPairs says why), in the order STAT_ROWS lists them -- so the offensive
    -- pair sits above the defensive pair above the movement pair above the two accuracy stats, and
    -- each line is a question with its answer beside it.
    local statRows = {}
    for _, row in ipairs(STAT_ROWS) do
        local base = char.stats and char.stats[row.stat]
        if type(base) == "number" then
            local bonus = (unit.bonus and unit.bonus[row.stat]) or 0
            local value = tostring(base + bonus)
            if bonus ~= 0 then value = value .. " (" .. (bonus > 0 and "+" or "") .. bonus .. ")" end
            statRows[#statRows + 1] = { label = row.label, value = value }
        end
    end
    appendPairs(blocks, statRows)

    -- A foe whose kit has been laid open (the Assayer's Eye) says so, and says how to read it. The
    -- reveal lasts the whole fight and its card no longer opens on a hover, so without this line the
    -- thing the ability bought would be invisible -- and this tooltip is exactly where the player is
    -- already looking at the foe it was spent on.
    if Combat.inventoryRevealed(unit) then
        blocks[#blocks + 1] = { kind = "desc",
            text = "Assayed — K, or click its turn card, to read its kit." }
    end

    -- What it is about to do, where the player is already asking about it. The badge on the body and
    -- the mark on the turn card are the fast read; this is the slow one, and both hovers open it.
    if intent then appendIntent(blocks, intent) end

    -- Active status effects: each shown as its name (in the status's colour) with the remaining
    -- duration on the right, so a stunned/rooted unit's condition reads in full here.
    local statuses = unit.statuses
    if statuses and #statuses > 0 then
        blocks[#blocks + 1] = { kind = "sep" }
        blocks[#blocks + 1] = { kind = "head", text = "Status Effects", color = { 0.85, 0.86, 0.92 } }
        local rows = {}
        for _, st in ipairs(statuses) do
            local def = st.def or {}
            rows[#rows + 1] = {
                label = def.name or st.name or "Status",
                labelColor = def.color or { 0.82, 0.82, 0.88 },
                -- A self-expiring status (Defending, Channeling) carries a meaningless countdown and
                -- opts out of it, exactly as in ui/status_tooltip.lua -- the same status must not
                -- quote a duration in one tooltip and withhold it in the other.
                value = (not def.hideDuration and st.remaining) and fmtDuration(st.remaining) or nil,
                hourglass = true }
        end
        -- Paired like the stats above them, and for the same reason: a status is a word and a number,
        -- and four of them stacked one per line is 72px of a column spent on eight short strings. The
        -- hourglass stays on every duration it quotes -- half a row is still a row.
        appendPairs(blocks, rows)
    end
end

-- Disposition -> badge tint for a hazard heading (no `color` on the hazard def itself).
local HAZARD_COLOR = {
    hostile  = { 0.95, 0.55, 0.35 }, -- fire orange
    friendly = { 0.45, 0.85, 0.55 }, -- sanctuary green
    neutral  = { 0.55, 0.72, 0.95 }, -- rain blue
}

-- Append the hazards on the tile (info.hazards): per hazard, its name (tinted by disposition) with
-- the remaining duration on the right, and its mechanical line. Ordered to sit ABOVE the terrain
-- section but BELOW any occupant, so a fire/sanctuary reads between the two.
-- Returns true if it appended a hazard section (so the empty-tile caller knows to add a divider
-- before the terrain that follows). A leading divider is added only when the box already has content
-- above (an occupant); on an empty tile the hazard leads, so no leading divider.
local function appendHazard(blocks, info)
    local hazards = info.hazards
    if not hazards or #hazards == 0 then return false end
    if #blocks > 0 then blocks[#blocks + 1] = { kind = "sep" } end
    for _, h in ipairs(hazards) do
        local def = h.def or {}
        blocks[#blocks + 1] = { kind = "status",
            name = def.name or h.name or "Hazard",
            color = HAZARD_COLOR[def.disposition] or HAZARD_COLOR.neutral,
            remaining = h.remaining }
        if def.description and def.description ~= "" then
            blocks[#blocks + 1] = { kind = "desc", text = def.description }
        end
    end
    return true
end

-- The two colours the board paints marked ground in (ui/battle_map.lua drawObjective): amber for
-- ground still up for grabs, green while the count is actually running for the local player. Borrowed
-- verbatim so the pulsing tile and the box describing it read as the same thing.
local OBJECTIVE_COLOR = { 0.95, 0.75, 0.30 }
local HELD_COLOR = { 0.40, 0.85, 0.50 }

local function charName(id)
    local def = id and Character.defs[id]
    return (def and def.name) or id or "your charge"
end

-- Heading + flavour per objective type, given the bag Combat.objectiveTileInfo builds. The line has
-- to state the CONTEST, not just the goal: the HUD banner above the board already names the goal
-- ("hold the moving node"), and what a player hovering the tile is asking is why the ground matters
-- and what standing here would do.
local function objectiveHeading(o)
    if o.type == "control" then
        return "Control Node",
            "Hold this node alone to bank time toward the round. An enemy boot on it stops the count for both sides."
    elseif o.type == "hold" then
        return "Objective Ground",
            "Hold this ground to bank the time the win is owed. An enemy standing on it stalls the count."
    elseif o.type == "reach" then
        if o.who then
            return "Crossing Ground", "Get " .. charName(o.who) .. " onto this ground to win the fight."
        end
        return "Crossing Ground", "Get any one of your units onto this ground to win the fight."
    elseif o.type == "defend" then
        if o.protect then
            return "Your Charge", charName(o.protect)
                .. " stands here. Every wave is coming for them, and their death loses the fight."
        end
        return "Defended Ground", "The ground the waves are marching on."
    end
    return "Objective Ground", nil
end

-- Append the objective section for marked ground (info.objective, from Combat.objectiveTileInfo):
-- what the tile is worth, who is holding it right now, and the clocks running on it. Leads the box
-- above the hazards and the terrain, and -- unlike the occupant box, which yields when the column
-- runs short -- rides on the terrain info so it is drawn for EVERY hover on the ground the fight is
-- decided on, including a tile with a unit already standing on it (which is the state the read
-- matters most in: standing on the node is not the same as holding it).
-- Returns true if it appended anything.
local function appendObjective(blocks, info)
    local o = info.objective
    if not o then return false end
    local mySide = o.playerSide or "party"
    local foeSide = (mySide == "party") and "enemy" or "party"
    local counting = (o.holder == mySide)
    local accent = counting and HELD_COLOR or OBJECTIVE_COLOR

    local heading, desc = objectiveHeading(o)
    blocks[#blocks + 1] = { kind = "title", text = heading, color = accent }
    if desc then blocks[#blocks + 1] = { kind = "desc", text = desc } end

    -- Who owns the ground right now -- the one thing the board's two colours cannot spell out (it
    -- shows green only while the LOCAL player is counting, so "contested" and "the enemy is banking
    -- points off you" look identical on the tile).
    if o.type == "control" or o.type == "hold" then
        local value, color = "Unclaimed", MUTED
        if o.holder == mySide then value, color = "You (counting)", HELD_COLOR
        elseif o.holder == foeSide then value, color = "Enemy (counting)", ENEMY_COLOR
        elseif o.party and o.enemy then value, color = "Contested", OBJECTIVE_COLOR end
        blocks[#blocks + 1] = { kind = "stat", label = "Holding", value = value, valueColor = color }
    end

    -- The clocks, each under the hourglass: banked score is a count of ticks exactly as a countdown
    -- is, so it wears the same mark (ui/glyphs.lua) as every other time value in the game.
    if o.scores then
        blocks[#blocks + 1] = { kind = "status", name = "Your score", color = HELD_COLOR,
            remaining = o.scores[mySide] or 0 }
        blocks[#blocks + 1] = { kind = "status", name = "Enemy score", color = ENEMY_COLOR,
            remaining = o.scores[foeSide] or 0 }
    end
    if o.movesIn then
        blocks[#blocks + 1] = { kind = "status", name = "Node moves in", color = OBJECTIVE_COLOR,
            remaining = math.ceil(o.movesIn) }
    end
    if o.remaining then
        local label = (o.type == "control" and "Round ends in")
            or (o.type == "hold" and "Time still owed") or "Time left"
        blocks[#blocks + 1] = { kind = "status", name = label, color = MUTED, remaining = o.remaining }
    end
    return true
end

-- RALLY GROUND (info.rally, from Combat.rallyTileInfo): your own lines, the ground the board outlines
-- quietly all fight (ui/battle_map.lua drawRallyGround). It is the only place the FALL BACK move is
-- explained, since the button for it appears only once a body is already standing here -- so the tile
-- has to teach the rule before the player is in a position to use it. Rides on the terrain info like the
-- objective does, which is what makes it open on a tile with one of your own units on it: that is the
-- state the read is for. `lead` is false when the objective section already took the title.
-- Returns true if it appended anything.
local function appendRally(blocks, info, lead)
    local r = info.rally
    if not r then return false end
    if not lead then blocks[#blocks + 1] = { kind = "sep" } end
    blocks[#blocks + 1] = { kind = lead and "title" or "head", text = "Rally Ground", color = PARTY_COLOR }
    -- Two different sentences off one tile, because the tile is two different offers. Empty ground with
    -- a slot open is the CLICKABLE one -- the move is made right here, for nothing -- so it leads with
    -- that and never buries it under the fall-back rule, which needs a body standing here to be true at
    -- all. Occupied (or with the line full) it teaches fall-back exactly as it always did.
    if r.slotOpen then
        blocks[#blocks + 1] = { kind = "desc",
            text = "Your own lines, and a slot is open. Click to send a reserve in on this tile -- it costs no turn." }
    else
        blocks[#blocks + 1] = { kind = "desc",
            text = "Your own lines. A unit standing here can fall back and send a reserve in its place, at the cost of its turn." }
    end
    blocks[#blocks + 1] = { kind = "stat", label = "In reserve", value = tostring(r.reserves),
        valueColor = PARTY_COLOR }
    return true
end

-- Build the ordered content blocks for the hovered tile. The occupant is the priority: when a
-- unit or trap stands on the tile it leads (its name is the title, its stats first), and the
-- terrain is demoted to a section below. An empty tile shows the terrain alone. Block kinds:
--   title { text, color }              -- headline (occupant name, or terrain when empty)
--   desc  { text }                     -- terrain flavour/mechanics
--   sep   {}                           -- divider + gap
--   head  { text, color }              -- section heading (demoted terrain name)
--   stat  { label, value, valueColor } -- label (left) + value (right)
--   bar   { label, cur, max, color }   -- resource pool bar
-- Is there anything to describe? Asked in three places (measure, draw, and buildBlocks' own guard),
-- and it was written out longhand in two of them -- so a new source of content had to be added to
-- each by hand or the box measured one thing and drew another.
local function describable(info)
    if not info then return false end
    return (info.blocks and #info.blocks > 0) or info.cell or (info.unit and info.unit.char)
        or info.trap or info.wall or info.prop or info.reinforce or info.objective or info.rally
end

local function buildBlocks(info)
    -- A CALLER THAT IS NOT A TILE brings its own blocks. The block vocabulary below -- title, stat,
    -- bar with a reserved tail, head, sep, desc -- is the game's readout grammar rather than anything
    -- about ground, and the box that renders it clamps, docks and measures itself; a campaign screen
    -- describing a roster body (ui/body_tooltip.lua) wants all of that and none of the terrain. So it
    -- assembles its own list and hands it in, rather than a second renderer growing beside this one.
    if info.blocks then return info.blocks end

    local blocks = {}
    local unit = info.unit
    if unit and unit.char then
        appendUnit(blocks, unit, info.preview, info.intent)
        -- Terrain is only appended for a battlefield tile hover (info.cell present); a turn-order
        -- strip hover passes just the unit, so it shows the character alone. Hazards read between the
        -- occupant and the terrain.
        if info.cell then
            appendHazard(blocks, info)
            blocks[#blocks + 1] = { kind = "sep" }
            appendTerrain(blocks, info, true)
        end
    elseif info.trap then
        local trap = info.trap
        local sideCol = trap.side == "party" and PARTY_COLOR or ENEMY_COLOR
        blocks[#blocks + 1] = { kind = "title", text = (trap.name or "Trap"), color = sideCol }
        blocks[#blocks + 1] = { kind = "stat", label = "Owner",
            value = trap.side == "party" and "Ally" or "Enemy", valueColor = sideCol }
        if trap.health and trap.maxHealth then
            -- Side-coloured like a unit's HP bar: same rule everywhere, and it keeps the bar clear of
            -- the amber slice a pending strike paints on it.
            local block = { kind = "bar", label = "HP", stat = "health", cur = trap.health,
                max = trap.maxHealth, color = sideCol }
            -- A pending trap strike previews the HP it would knock off (info.preview.damage).
            if info.preview and (info.preview.damage or 0) > 0 then
                block.delta = -info.preview.damage
                block.lethal = info.preview.lethal
            end
            blocks[#blocks + 1] = block
        end
        -- What crossing this trap does: its blueprint flavour, then the raw damage / status a victim
        -- eats (dry-run via Trap.preview) -- so a revealed trap reads as a threat, not just an HP bar.
        local tdef = trap.def or {}
        if tdef.description and tdef.description ~= "" then
            blocks[#blocks + 1] = { kind = "desc", text = tdef.description }
        end
        local tp = trap.id and Trap.preview(trap.id, trap.amount)
        if tp and tp.damage > 0 then
            blocks[#blocks + 1] = { kind = "stat", label = "Damage", value = tostring(tp.damage) }
        end
        for _, st in ipairs(tp and tp.statuses or {}) do
            local def = st.def or {}
            blocks[#blocks + 1] = { kind = "stat", label = "Applies",
                value = def.name or st.id or "status", valueColor = def.color or VALUE }
        end
        if info.cell then
            appendHazard(blocks, info)
            blocks[#blocks + 1] = { kind = "sep" }
            appendTerrain(blocks, info, true)
        end
    elseif info.wall then
        -- A wall reads like a trap that makes no secret of itself: owner, the HP it takes to tear
        -- down, and -- the two things the terrain box below would otherwise lie about -- the movement
        -- and sight it OVERRIDES on this tile. The countdown matters as much as the HP: a conjured
        -- barrier fades on its own, so "wait it out" is a real answer to it and the player needs the
        -- number to weigh that against spending a turn breaking through.
        local wall = info.wall
        local sideCol = wall.side == "party" and PARTY_COLOR or ENEMY_COLOR
        blocks[#blocks + 1] = { kind = "title", text = (wall.name or "Wall"), color = sideCol }
        blocks[#blocks + 1] = { kind = "stat", label = "Raised by",
            value = wall.side == "party" and "Ally" or "Enemy", valueColor = sideCol }
        if wall.health and wall.maxHealth then
            local block = { kind = "bar", label = "HP", stat = "health", cur = wall.health,
                max = wall.maxHealth, color = sideCol }
            if info.preview and (info.preview.damage or 0) > 0 then
                block.delta = -info.preview.damage
                block.lethal = info.preview.lethal
            end
            blocks[#blocks + 1] = block
        end
        local wdef = wall.def or {}
        if wdef.description and wdef.description ~= "" then
            blocks[#blocks + 1] = { kind = "desc", text = wdef.description }
        end
        blocks[#blocks + 1] = { kind = "stat", label = "Movement",
            value = wall.blocksMove and "Impassable" or "Passable",
            valueColor = wall.blocksMove and ENEMY_COLOR or VALUE }
        blocks[#blocks + 1] = { kind = "stat", label = "Line of sight", value = coverText(wall.sightCost) }
        -- Timed walls only: one with no `remaining` stands until it is struck down or dispelled, and
        -- printing an empty clock for it would read as "soon".
        if wall.remaining then
            blocks[#blocks + 1] = { kind = "status", name = "Fades in", color = MUTED,
                remaining = wall.remaining }
        end
        if info.cell then
            appendHazard(blocks, info)
            blocks[#blocks + 1] = { kind = "sep" }
            appendTerrain(blocks, info, true)
        end
    elseif info.prop then
        -- A prop reads like a trap with the Owner row struck out: it belongs to nobody, which is the
        -- single most important thing about a powder keg and so is said in the tinting rather than a
        -- row -- neutral, not party-blue or enemy-red. HP, then what BREAKING it does (dry-run through
        -- Prop.preview), because "break it" is the only verb it has and the blast is the whole reason
        -- to hover it at all.
        local prop = info.prop
        local pdef = prop.def or {}
        local tint = pdef.color and { pdef.color[1], pdef.color[2], pdef.color[3] } or VALUE
        blocks[#blocks + 1] = { kind = "title", text = (prop.name or "Object"), color = tint }
        if prop.health and prop.maxHealth then
            local block = { kind = "bar", label = "HP", stat = "health", cur = prop.health,
                max = prop.maxHealth, color = tint }
            if info.preview and (info.preview.damage or 0) > 0 then
                block.delta = -info.preview.damage
                block.lethal = info.preview.lethal
            end
            blocks[#blocks + 1] = block
        end
        if pdef.description and pdef.description ~= "" then
            blocks[#blocks + 1] = { kind = "desc", text = pdef.description }
        end
        local pp = prop.id and Prop.preview(prop.id, prop.amount)
        if pp and pp.damage > 0 then
            blocks[#blocks + 1] = { kind = "stat", label = "Blast", value = tostring(pp.damage) }
            blocks[#blocks + 1] = { kind = "stat", label = "Radius", value = tostring(pdef.radius or 1) }
        end
        for _, st in ipairs(pp and pp.statuses or {}) do
            local def = st.def or {}
            blocks[#blocks + 1] = { kind = "stat", label = "Applies",
                value = def.name or st.id or "status", valueColor = def.color or VALUE }
        end
        if info.cell then
            appendHazard(blocks, info)
            blocks[#blocks + 1] = { kind = "sep" }
            appendTerrain(blocks, info, true)
        end
    elseif info.reinforce then
        -- A telegraphed landing tile: no body stands here yet, so the box describes the muster that is
        -- about to walk onto it -- what, from which edge, and the countdown to arrival (the same clock
        -- the tile itself carries). It closes on the deny-by-standing rule, because that is the only
        -- move the marker asks the player to make.
        local r = info.reinforce
        blocks[#blocks + 1] = { kind = "title", text = "Reinforcements", color = MUSTER_COLOR }
        blocks[#blocks + 1] = { kind = "desc", text = "An enemy muster is marching onto this tile." }
        local char = r.char
        if char and char.name then
            blocks[#blocks + 1] = { kind = "stat", label = "Incoming", value = char.name,
                valueColor = ENEMY_COLOR }
        end
        blocks[#blocks + 1] = { kind = "stat", label = "Marches in from",
            value = EDGE_LABEL[r.edge] or "the field edge" }
        -- A SCRIPTED arrival (a guided fight's authored reinforcement) carries no countdown, and the
        -- box is shorter by exactly the two lines it cannot honour: it is due on the next beat of the
        -- lesson rather than at a tick, and it takes its cell whatever stands there -- so there is no
        -- number to quote and no ground worth holding against it. Everything above still reads true.
        if r.ticksUntil then
            -- ceil to match the whole-tick number drawn inside the tile (ui/battle_map.lua drawMusterCount),
            -- so the tooltip and the marker never quote two different counts for the one arrival.
            blocks[#blocks + 1] = { kind = "status", name = "Lands in", color = MUSTER_COLOR,
                remaining = math.ceil(r.ticksUntil) }
            blocks[#blocks + 1] = { kind = "desc", text = "Stand a unit on this tile to turn the arrival back." }
        else
            blocks[#blocks + 1] = { kind = "desc", text = "It walks on as the next action resolves." }
        end
        if info.cell then
            appendHazard(blocks, info)
            blocks[#blocks + 1] = { kind = "sep" }
            appendTerrain(blocks, info, true)
        end
    else
        -- Marked objective ground leads: it outranks both a hazard and the terrain, being the reason
        -- the tile is worth walking onto at all. appendHazard adds its own divider above itself when
        -- the objective already filled the box.
        local objLed = appendObjective(blocks, info)
        local rallyLed = appendRally(blocks, info, not objLed)
        local hazLed = appendHazard(blocks, info)
        if objLed or rallyLed or hazLed then blocks[#blocks + 1] = { kind = "sep" } end
        appendTerrain(blocks, info, false)
    end
    return blocks
end

-- Sum the height of `blocks` at `innerW`, caching each wrapped desc's line count on the block itself
-- so the draw pass lays it out exactly as measured (the box height can never drift from its content).
local function measureBlocks(blocks, innerW, body)
    local titleH, bodyH, barH = titleFont:getHeight(), body:getHeight(), 6
    local h = 9 -- top pad
    for _, b in ipairs(blocks) do
        if b.kind == "title" then h = h + titleH + 3
        elseif b.kind == "desc" then
            local _, lines = body:getWrap(b.text, innerW)
            b.lines = math.max(1, #lines)
            h = h + b.lines * bodyH + 2
        elseif b.kind == "sep" then h = h + 8
        elseif b.kind == "head" then h = h + bodyH + 3
        elseif b.kind == "intent" then h = h + bodyH + 1 -- label, glyph + word, on one stat-row line
        elseif b.kind == "pair" then h = h + bodyH + 1 -- two stat rows sharing one line
        -- A previewed pool reserves a lane above its row for the callout pill, so the projection
        -- floats in space made for it instead of over the row's own "cur / max".
        elseif b.kind == "bar" then h = h + bodyH + barH + 4 + (b.delta and (PoolCallout.H + GLYPH_GAP) or 0)
        elseif b.kind == "barPair" then h = h + bodyH + barH + 4 -- two pools on one line, neither previewed
        else h = h + bodyH + 1 end -- stat
    end
    return h + 9 -- bottom pad
end

-- The assembled block list for `info`, without measuring or drawing any of it -- the same list both
-- of those walk. Exported for the headless suite (tests/tile_tooltip_spec.lua): the blocks ARE what
-- the player reads, and they can be read here without a window or a font, exactly as
-- ui/body_tooltip.lua's own list is.
function TileTooltip.blocks(info)
    if not describable(info) then return {} end
    return buildBlocks(info)
end

-- The height the box for `info` would need at `width`. Shares buildBlocks + the measure walk with
-- draw, so it can't disagree with what gets drawn. Lets a caller stacking several boxes into a fixed
-- column work out what fits BEFORE it commits any of them to the screen (states/battle.lua).
function TileTooltip.measure(info, width)
    if not describable(info) then return 0 end
    local _, body = fonts()
    return measureBlocks(buildBlocks(info), ((width or 210) - 9 * 2), body)
end

-- WHAT OF A HOVERED BODY'S READOUT STANDS when the column it docks into also has to hold the ground
-- underfoot and the exchange being aimed at it: `{ occupant = bool, intent = bool }`. Pure -- it
-- measures, it never draws -- so the fight's arrangement can be pinned without a window
-- (tests/tile_hover_fit_spec.lua). `budget` is the free height of the column, `gap` the space kept
-- between two stacked boxes.
--
-- TWO VALVES, IN ORDER, and the order is the whole of it. The terrain box never yields (states/battle
-- .lua's drawTileTooltip says why), so the occupant was the entire valve: a body's readout either
-- stood or vanished. Aiming a blow puts an exchange box in the same column, and an occupant box
-- carrying the intent section overran what was left of it by a few dozen pixels -- so pointing a
-- weapon at a foe deleted its armour, its reach and its pools at the one moment they are being read,
-- and pointing at the tile beside it brought them all back.
--
-- The INTENT SECTION yields first because it is the one part of that box with somewhere else to be
-- read: the same prediction is a badge on the body, a mark on its turn card, and a hover note on
-- each of those. The stats above it have no second reading anywhere. Only when even the trimmed box
-- will not fit does the whole of it go, which is the rule exactly as it was.
function TileTooltip.dockPlan(terrainInfo, objInfo, width, budget, gap)
    gap = gap or 8
    local plan = { occupant = objInfo ~= nil, intent = objInfo ~= nil and objInfo.intent ~= nil }
    if not objInfo then return plan end

    local terrainH = TileTooltip.measure(terrainInfo, width) + gap
    if TileTooltip.measure(objInfo, width) + gap + terrainH <= budget then return plan end

    if plan.intent then
        -- Measured off a COPY. The plan is a read, and a caller that asked what would fit and got its
        -- own table quietly emptied would be a foul thing to find from the far side of a draw call.
        local trimmed = {}
        for k, v in pairs(objInfo) do trimmed[k] = v end
        trimmed.intent = nil
        plan.intent = false
        if TileTooltip.measure(trimmed, width) + gap + terrainH <= budget then return plan end
    end

    plan.occupant = false
    return plan
end

-- ONE "label ....... value" ROW, laid into whatever column it is handed -- the full inner width for a
-- stat or a status, or half of it for either side of a paired row. The dotted leader walks whatever
-- gap is left between the label and the value, which is exactly what keeps a 130px half legible: the
-- eye follows the dots across rather than measuring the whitespace.
--
-- `half` is `{ label, value, valueColor, labelColor, hourglass }`. A row with no value prints its
-- label alone (a status that opts out of its countdown), and `hourglass` sets the game's mark for
-- "measured in ticks" ahead of the number, which every duration in the game wears.
local function drawLeaderRow(body, half, x, w, ty)
    if not half or not half.label then return end
    local bodyH = body:getHeight()
    love.graphics.setFont(body)
    local lc = half.labelColor or MUTED
    love.graphics.setColor(lc[1], lc[2], lc[3], 1)
    love.graphics.print(half.label, x, ty)
    if not half.value then return end
    local vc = half.valueColor or VALUE
    local valueLeft = x + w - body:getWidth(half.value)
    local leaderRight = valueLeft - 6
    if half.hourglass then
        local gw = 7
        leaderRight = valueLeft - GLYPH_GAP - gw - 6
        Glyphs.hourglass(valueLeft - GLYPH_GAP - gw, ty + 2, gw, bodyH - 4, MUTED[1], MUTED[2], MUTED[3], 1)
    end
    Theme.leader(x + body:getWidth(half.label) + 6, leaderRight, ty + bodyH - 3)
    love.graphics.setColor(vc[1], vc[2], vc[3], 1)
    love.graphics.printf(half.value, x, ty, w, "right")
end

-- Draw the tooltip for the hovered tile `info` anchored near (mx, my). `maxRight` caps the box's
-- right edge so it never slides under the combat panel (defaults to the screen width). When
-- `opts.dock` is set the box is parked in the bottom-left gutter instead of following the cursor,
-- so it never covers the board highlights (the blast footprint) the player is reading. No-op when
-- there is no tile to describe.
function TileTooltip.draw(info, mx, my, maxRight, opts)
    if not describable(info) then return end
    local title, body, small = fonts()
    local pad, w = 9, (opts and opts.width) or 210
    local innerW = w - pad * 2
    maxRight = maxRight or Scale.WIDTH

    local blocks = buildBlocks(info)
    local titleH, bodyH = title:getHeight(), body:getHeight()
    local barH = 6 -- pool bar thickness
    local h = measureBlocks(blocks, innerW, body)

    -- Position near the cursor; flip left and clamp so the box stays within [4, maxRight].
    local bx = mx + 14
    local maxX = maxRight - w - 4
    if bx > maxX then bx = mx - w - 14 end
    bx = math.max(4, math.min(bx, maxX))
    local by = math.max(4, math.min(my + 16, Scale.HEIGHT - h - 4))

    -- Docked mode parks the box at a fixed spot (bottom-aligned) instead of following the cursor, so
    -- it never sits over the board highlights the player is reading. `opts.dockX` sets the left edge
    -- (the caller places it inside the left column); `opts.dockBottom` is the Y the box bottom aligns
    -- to (defaults to the screen bottom) so the caller can stack several docked boxes; `opts.dockTop`
    -- floors the top so a tall box can't ride up over the buttons above it.
    if opts and opts.dock then
        bx = opts.dockX or 8
        local bottomY = opts.dockBottom or (Scale.HEIGHT - 8)
        by = math.max(opts.dockTop or 4, bottomY - h)
    end

    Theme.set(Theme.panel)
    love.graphics.rectangle("fill", bx, by, w, h, 4, 4)
    Theme.set(Theme.frame) -- bone-gold trim; faction/terrain still rides the title colour + the Side row
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", bx, by, w, h, 4, 4)

    -- Pool projections are collected while the rows are drawn and floated after them, so a pill
    -- always layers over the box rather than under the row below it.
    local callouts = PoolCallout.new()

    -- ONE POOL ROW -- its tag and its mark, its "cur / max", and the track under them -- laid into
    -- whatever column it is handed: the full inner width for health, which carries the forecast
    -- pill and must have room for it, or half of it for the two spendable pools, which share a
    -- line. Returns the height it used, callout lane and all, so the caller's cursor can never
    -- come apart from measureBlocks.
    local function drawPoolBar(b, x, w, ty)
        -- Step past the lane measureBlocks reserved for this row's callout pill (if any).
        if b.delta then ty = ty + PoolCallout.H + GLYPH_GAP end
        local rowTop = ty
        love.graphics.setFont(small)
        -- The pool's own mark just after its HP/MP/SP tag -- the same heart / gem / drop the turn
        -- strip and the cost badges use, tinted like the label rather than the bar so the row
        -- reads as one caption. `b.stat` is absent only for a pool with no shape of its own.
        love.graphics.setColor(MUTED[1], MUTED[2], MUTED[3], 1)
        love.graphics.print(b.label, x, ty)
        local glyph = b.stat and Glyphs.RESOURCE[b.stat]
        if glyph then
            glyph(x + small:getWidth(b.label) + GLYPH_GAP, ty + 2,
                BAR_GLYPH_W, bodyH - 4, MUTED[1], MUTED[2], MUTED[3], 1)
        end
        -- Value text stays "cur / max" no matter what is aimed: the projection is quoted by the
        -- floating callout instead, so the numbers under the cursor hold still while the aim
        -- moves. `b.max` is the ceiling (max less anything reserved); a reservation appends its
        -- size.
        local curN = math.floor(b.cur + 0.5)
        local valueText = curN .. " / " .. b.max
        -- A reservation names ITSELF where it is not the battle's own: what holds a summon back is
        -- "res.", what a wound has taken off the top says so in the word the player is being
        -- charged in (ui/body_tooltip.lua). Same slice of bar, two different debts.
        if b.reserved then
            valueText = valueText .. " (" .. b.reserved .. " " .. (b.reservedLabel or "res.") .. ")"
        end
        love.graphics.setColor(VALUE[1], VALUE[2], VALUE[3], 1)
        love.graphics.printf(valueText, x, ty, w, "right")
        local barY = ty + bodyH
        -- The track spans the pool's TRUE maximum, so the reserved slice occupies real width at
        -- its far end and the unreserved fill visibly shrinks by exactly what was committed.
        local scale = b.fullMax or b.max
        local ratio = (scale > 0) and math.max(0, math.min(1, b.cur / scale)) or 0
        Theme.set(Theme.barTrack)
        love.graphics.rectangle("fill", x, barY, w, barH, 2, 2)
        if b.reserved and scale > 0 then
            -- The locked-away tail: the pool colour, dimmed and hatched by opacity alone.
            local resW = w * (b.reserved / scale)
            love.graphics.setColor(b.color[1] * 0.5, b.color[2] * 0.5, b.color[3] * 0.5, 0.7)
            love.graphics.rectangle("fill", x + w - resW, barY, resW, barH, 2, 2)
        end
        if b.delta and scale > 0 then
            -- Show the change as a second segment: the "after" fill in the pool colour, then the
            -- lost slice in amber (damage) or the gained slice in green (heal) beside it. The
            -- lost slice can't be red -- an enemy's HP bar is red, and red-on-red reads as nothing.
            local afterVal = math.max(0, math.min(b.max, b.cur + b.delta))
            local afterRatio = math.max(0, math.min(1, afterVal / scale))
            -- Queue the projection for the floating pass: the same pill the acting card's pool
            -- stack wears (ui/pool_callout.lua), anchored on the edge the pending slice ends at.
            callouts:add({
                anchorX = x + w * afterRatio, anchorY = barY, barH = barH,
                aboveY = rowTop,
                key = b.stat, text = tostring(math.floor(afterVal + 0.5)),
                color = (b.delta > 0 and Colors.HEALING)
                    or (b.lethal and Colors.LETHAL) or Colors.PENDING,
            })
            if b.delta < 0 then
                local loseCol = b.lethal and Colors.LETHAL or Colors.PENDING
                love.graphics.setColor(b.color[1], b.color[2], b.color[3], 0.95)
                love.graphics.rectangle("fill", x, barY, w * afterRatio, barH, 2, 2)
                love.graphics.setColor(loseCol[1], loseCol[2], loseCol[3], 0.95)
                love.graphics.rectangle("fill", x + w * afterRatio, barY,
                    w * (ratio - afterRatio), barH, 2, 2)
            else
                local gain = Colors.HEALING
                love.graphics.setColor(b.color[1], b.color[2], b.color[3], 0.95)
                love.graphics.rectangle("fill", x, barY, w * ratio, barH, 2, 2)
                love.graphics.setColor(gain[1], gain[2], gain[3], 0.9)
                love.graphics.rectangle("fill", x + w * ratio, barY,
                    w * (afterRatio - ratio), barH, 2, 2)
            end
        else
            love.graphics.setColor(b.color[1], b.color[2], b.color[3], 0.95)
            love.graphics.rectangle("fill", x, barY, w * ratio, barH, 2, 2)
        end
        Theme.set(Theme.barOutline, Theme.barOutline[4] or 1)
        love.graphics.rectangle("line", x, barY, w, barH, 2, 2)
        return (b.delta and (PoolCallout.H + GLYPH_GAP) or 0) + bodyH + barH + 4
    end

    local ty = by + pad
    for _, b in ipairs(blocks) do
        if b.kind == "title" then
            love.graphics.setFont(title)
            local off = drawSwatch(b, bx + pad, ty + 1, titleH - 2)
            love.graphics.setColor(b.color[1], b.color[2], b.color[3], 1)
            love.graphics.print(b.text, bx + pad + off, ty)
            -- The side word on the name's own line, in the body face and sat on the serif's optical
            -- centre, so the line reads "who this is ......... which side it is on".
            if b.right then
                local rc = b.rightColor or MUTED
                love.graphics.setFont(body)
                love.graphics.setColor(rc[1], rc[2], rc[3], 1)
                love.graphics.printf(b.right, bx + pad, ty + math.floor((titleH - bodyH) / 2), innerW, "right")
            end
            ty = ty + titleH + 3
        elseif b.kind == "desc" then
            love.graphics.setFont(body)
            love.graphics.setColor(DESC[1], DESC[2], DESC[3], 1)
            love.graphics.printf(b.text, bx + pad, ty, innerW, "left")
            ty = ty + b.lines * bodyH + 2
        elseif b.kind == "sep" then
            Theme.set(Theme.frame, 0.24)
            love.graphics.line(bx + pad, ty + 4, bx + w - pad, ty + 4)
            ty = ty + 8
        elseif b.kind == "head" then
            love.graphics.setFont(body)
            local off = drawSwatch(b, bx + pad, ty + 1, bodyH - 2)
            love.graphics.setColor(b.color[1], b.color[2], b.color[3], 1)
            love.graphics.print(b.text, bx + pad + off, ty)
            ty = ty + bodyH + 3
        elseif b.kind == "bar" then
            ty = ty + drawPoolBar(b, bx + pad, innerW, ty)
        elseif b.kind == "barPair" then
            -- Two pools sharing a line. Neither can carry a forecast (only health is ever
            -- previewed), so neither reserves a callout lane and the two halves are the same
            -- height -- which is what lets one of them stand for the row.
            local half = math.floor((innerW - PAIR_GAP) / 2)
            drawPoolBar(b.left, bx + pad, half, ty)
            ty = ty + drawPoolBar(b.right, bx + pad + half + PAIR_GAP, half, ty)
        elseif b.kind == "intent" then
            -- The mark beside its name, both in the kind's colour: the SAME glyph the board badge and
            -- the turn card wear (ui/glyphs.lua INTENT), so what is learned here is legible there.
            local glyph = Glyphs.INTENT[b.glyphKind] or Glyphs.INTENT.wait
            local gw = bodyH - 3
            love.graphics.setFont(body)
            -- The section's own heading is this row's label (appendIntent says why), so the mark and
            -- its word sit at the value end where every other answer in the box sits.
            local wordW = body:getWidth(b.name)
            local markX = bx + pad + innerW - wordW - gw - GLYPH_GAP
            if b.label then
                love.graphics.setColor(MUTED[1], MUTED[2], MUTED[3], 1)
                love.graphics.print(b.label, bx + pad, ty)
                Theme.leader(bx + pad + body:getWidth(b.label) + 6, markX - 6, ty + bodyH - 3)
            else
                markX = bx + pad
            end
            glyph(markX, ty + 2, gw, gw, b.color[1], b.color[2], b.color[3], 1)
            love.graphics.setColor(b.color[1], b.color[2], b.color[3], 1)
            love.graphics.print(b.name, markX + gw + GLYPH_GAP, ty)
            ty = ty + bodyH + 1
        elseif b.kind == "status" then
            -- A standing clock on the tile rather than on a body (a wall's "Fades in", a muster's
            -- "Lands in"): the name in its own colour, the count under the hourglass. Same row the
            -- stats are drawn with -- the duration is the value.
            drawLeaderRow(body, { label = b.name, labelColor = b.color,
                value = b.remaining and fmtDuration(b.remaining) or nil, hourglass = true },
                bx + pad, innerW, ty)
            ty = ty + bodyH + 1
        elseif b.kind == "pair" then
            -- Two rows sharing a line, each laid into its own half with its own leader. The gutter
            -- between them is what stops the left half's value and the right half's label reading as
            -- one run of text.
            local half = math.floor((innerW - PAIR_GAP) / 2)
            drawLeaderRow(body, b.left, bx + pad, half, ty)
            drawLeaderRow(body, b.right, bx + pad + half + PAIR_GAP, half, ty)
            ty = ty + bodyH + 1
        else -- stat: label left, value right, a dotted leader walking between them (as ui/item_tooltip)
            drawLeaderRow(body, b, bx + pad, innerW, ty)
            ty = ty + bodyH + 1
        end
    end

    -- Clamped to the box's inner edges, so a pill on a nearly-full pool can't hang off the tooltip.
    callouts:draw(bx + 6, bx + w - 6)

    love.graphics.setColor(1, 1, 1)
    -- Report the drawn box so the caller can anchor a companion panel (the action preview) to it.
    return { x = bx, y = by, w = w, h = h }
end

return TileTooltip
