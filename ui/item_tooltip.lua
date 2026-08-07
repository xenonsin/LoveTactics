-- Shared hover tooltip for an inventory item: a dark panel showing the item's name, type,
-- description, tags, and the stats of its active ability (target, range, speed, cost), plus
-- passive stats for armor/utility items. Positioned near the mouse and clamped on-screen.
-- The combat panel (ui/combat_panel.lua) exposes itemAt(px, py); the owning battle state draws
-- this last, so the tooltip sits above the board AND the panel.
--
--   ItemTooltip.draw(item, mx, my, maxRight, actor)   -- actor (optional) gates the ability cost:
--                                                     -- it renders red + a note when unaffordable
--
-- `actor` is a live combat unit and so exists only during a fight. Out of a fight the owner is a plain
-- character, and the question changes with it: not "can they pay for this right now" (a pool that is
-- merely empty refills before the next battle) but "could this body EVER pay for this", which is the
-- one the Loadout screen has to answer before the fight rather than during it. That is `owner`:
--
--   ItemTooltip.draw(item, mx, my, maxRight, nil, char)  -- owner: warns on a price it can never meet
--
-- `draw` is measure-then-paint, and both halves are public for a caller that has to place the box
-- itself rather than hang it off a cursor:
--
--   ItemTooltip.measure(item, actor, owner) -> layout -- the expensive half; memoizable per item
--   ItemTooltip.paint(layout, x, y, opts) -> box    -- pinned exactly at (x, y); opts.accent = border
--
-- The draft unit sheet uses them to open one tooltip per carried piece at once (states/draft.lua).
--
-- Whatever the tooltip NAMES it also defines: a sibling column (ui/glossary_panel.lua, gathered by
-- models/glossary.lua) opens beside the box carrying one line on each status the item can inflict and
-- each keyword its ability declares. It is drawn from here so every caller in the game gets it.
--
-- Content is assembled once into an ordered list of blocks that is both measured and drawn, so
-- the computed box height can never drift from what's rendered.

local Scale = require("scale")
local Combat = require("models.combat")
local Character = require("models.character")
local Item = require("models.item")
local Trait = require("models.trait")
local Discipline = require("models.discipline")
local Trap = require("models.trap")
local Hazard = require("models.hazard")
local Glossary = require("models.glossary")
local RangeDiagram = require("ui.range_diagram")
local FootprintDiagram = require("ui.footprint_diagram") -- the drawn AREA shape (line/arc/cone/blast)
local GlossaryPanel = require("ui.glossary_panel")
local Glyphs = require("ui.glyphs")
local Colors = require("ui.colors")
local Theme = require("ui.theme")

local ItemTooltip = {}

-- The box's fixed width. Public so a caller that has to choose a side for itself (the debug menu
-- floats the tooltip beside its dropdown) can ask whether the box fits before anchoring it.
ItemTooltip.WIDTH = 244

local titleFont, bodyFont, smallFont, powerFont
local function fonts()
    titleFont = titleFont or Theme.display(15)
    bodyFont = bodyFont or Theme.body(12)
    smallFont = smallFont or Theme.body(11)
    powerFont = powerFont or Theme.display(22) -- the headline Power value
    return titleFont, bodyFont, smallFont, powerFont
end

-- Accent color per item type (title + type-line tint).
-- Accent per item type, pitched bright to read on the dark tooltip ground (ui/theme.lua).
local TYPE_COLOR = {
    weapon = { 0.789, 0.361, 0.354 },
    armor = { 0.391, 0.549, 0.812 },
    consumable = { 0.361, 0.671, 0.480 },
    ability = { 0.568, 0.414, 0.786 },
    utility = { 0.865, 0.707, 0.341 },
}
local DEFAULT_COLOR = Theme.ink

-- Cost value tint per resource stat (matches the item-grid cost badges). Health is PARTY blue: a
-- cost only ever prices the player's own actor, whose HP bar is blue.
local RES_COLOR = {
    mana = Colors.MANA,
    stamina = Colors.STAMINA,
    health = Colors.PARTY,
}

local TARGET_LABEL = { enemy = "Enemy", ally = "Ally", self = "Self", tile = "Tile" }

-- Text tints, all pitched for the parchment ground (ui/theme.lua): the neutral rows are the theme's
-- ink/muted, and every coloured row is darkened so its hue reads on the light stock.
local MUTED = Theme.muted
local VALUE = Theme.ink
local DESC = Theme.ink
local FLAVOR = Theme.muted -- the story line at the foot: dimmer than DESC, so it reads as an aside
local WARN = { 0.789, 0.361, 0.354 } -- the row at fault + the note, when the ability can't be cast
local MET = { 0.361, 0.671, 0.480 }  -- a satisfied requirement (matches the grid's connector line)
local TITLE = { 0.865, 0.707, 0.341 } -- the item NAME: bone-gold, matching the mock (not the type accent)
local POWER = { 0.865, 0.707, 0.341 } -- the headline value (Damage/Power): gold, matching the mock
local HEAL = { 0.467, 0.725, 0.566 }  -- ability heal row
local SUMMON = { 0.568, 0.414, 0.786 } -- ability "Summons" row (matches the ability item accent)
local DISC = { 0.568, 0.414, 0.786 } -- the discipline row: a taxonomy label, tinted like the caster accent
local CLASS = Theme.muted -- the base-class row: the same taxonomy slot, cooler/dimmer than a discipline
local BRACE = { 0.391, 0.549, 0.812 } -- a shield's Defend brace-defense (matches the Defending badge tint)
-- The range-diagram band tint: green for a friendly cast, red for a hostile one (matches the
-- board's green/red targeting overlays and the action preview's SUPPORT/OFFENSE accents).
local RANGE_FRIENDLY = { 0.361, 0.671, 0.480 }
local RANGE_HOSTILE = { 0.789, 0.361, 0.354 }
local GLYPH_GAP = 4 -- between a stat row's glyph and the value it marks
local STAT_GAP = 8  -- least space kept between a stat row's label and its value column

local function titleCase(s)
    return (tostring(s):gsub("^%l", string.upper))
end

-- The longest cooldown any reflex on this item declares, in ticks (nil when none of them has one).
-- Read off the trait BLUEPRINTS rather than off a bearer, so a shop shelf can quote the number with
-- nobody wearing the thing -- which is the whole point of the row: "then it goes on cooldown" is a
-- sentence with a number missing, and the number belongs to the item, not to the battle.
-- Only `cooldown` counts. `magnitude` on the same defs is the effect's own size (the Stayed Hand's
-- health fraction, Adrenal Surge's initiative pull), and reading it here would print a nonsense
-- duration -- the same trap Combat.itemCooldown avoids.
local function declaredCooldown(item)
    local best
    for _, id in ipairs((item and item.traits) or {}) do
        local def = Trait.defs[id]
        local ticks = def and def.cooldown
        if ticks and ticks > 0 and (not best or ticks > best) then best = ticks end
    end
    return best
end

-- The flavor line is set in a REAL italic cut (Alegreya Italic, via Theme.bodyItalic) -- LOVE cannot
-- synthesize a slant, so an italic aside needs a genuine italic face or it renders upright. Memoized at
-- the body size the tooltip wraps at. (This replaces an old shear-transform fake italic, from before the
-- game shipped a font asset.)
local flavorFontCached
local function flavorFont()
    flavorFontCached = flavorFontCached or Theme.bodyItalic(12)
    return flavorFontCached
end
-- A hair off the right edge so an italic tail clears the border; measure and draw MUST share it, or a
-- measured box height silently stops matching the text inside it.
local FLAVOR_GUARD = 3

-- Draw `text` as a sheared italic aside, wrapped into a `w`-wide column at (x, y). Returns the
-- height consumed, so callers laying out their own column can advance past it -- the shop and
-- forge panels print flavor under an item's description without the block system. `font`
-- defaults to the tooltip's own body font; a caller with its own type scale passes that instead, so
-- the flavor matches the column it sits in.
function ItemTooltip.printFlavor(text, x, y, w, font)
    font = font or flavorFont()
    local textW = w - FLAVOR_GUARD
    local _, wrapped = font:getWrap(text, textW)
    love.graphics.setFont(font)
    love.graphics.setColor(FLAVOR[1], FLAVOR[2], FLAVOR[3], 1)
    love.graphics.printf(text, x, y, textW, "left")
    return math.max(1, #wrapped) * font:getHeight()
end

-- The taxonomy `item` falls under, drawn as a tinted label right-aligned in a `w`-wide column at
-- (x, y): its discipline if it carries one, otherwise its base shelf `class`. Draws nothing and
-- returns false only for a class-less, discipline-less item (a natural weapon, a universal good), so a
-- caller can put it on a line it shares with other text. `font` defaults to the tooltip's small face.
--
-- The inline detail columns -- the shop shelf, the forge -- build their own text rather than hovering
-- this tooltip, so they call this instead of repeating the lookup: one owner for both the wording and
-- the tint means the deeper cut (and the shelf under it) read identically wherever an item is shown.
function ItemTooltip.printDiscipline(item, x, y, w, font)
    local name = item and Discipline.displayName(item.discipline)
    local tint = DISC
    if not name and item then
        name = Item.classDisplayName(item.class)
        tint = CLASS
    end
    if not name then return false end
    local _, _, small = fonts()
    love.graphics.setFont(font or small)
    love.graphics.setColor(tint[1], tint[2], tint[3], 1)
    love.graphics.printf(name, x, y, w, "right")
    return true
end

-- The value column of a stat row: it starts after the label and runs to the row's right edge, so a
-- long value (a weapon's tag list, an armor's resists) wraps inside the tooltip instead of running
-- past its border. Returns the column's x offset from the row's left edge, its width, and the
-- wrapped lines. Measure and draw MUST both size themselves from this, or the box height stops
-- matching the rows inside it.
local function statLayout(font, label, value, innerW)
    local x = font:getWidth(label) + STAT_GAP
    local w = math.max(1, innerW - x)
    local _, lines = font:getWrap(tostring(value), w)
    return x, w, math.max(1, #lines)
end

-- Sorted keys of a map, so pairs-driven rows (armor bonuses/resists) render deterministically.
local function sortedKeys(t)
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys)
    return keys
end

-- Build the ordered content blocks for `item`. Block kinds:
--   title  { text, color }              -- item name, tinted by type
--   type   { text }                     -- e.g. "ABILITY"
--   power  { label, value }             -- headline primary stat (label caption + big value)
--   desc   { text }                     -- wrapped mechanical description (docs/item-text.md)
--   flavor { text }                     -- wrapped story line, sheared italic; always last
--   sep    {}                           -- thin divider + gap between sections
--   head   { text }                     -- ability name heading
--   stat   { label, value, valueColor, icon } -- label (left) + value (right); `icon` ("hourglass")
--                                        marks the VALUE with that glyph, in the value's own colour
--   note   { text }                     -- muted wrapped aside (e.g. "Consumed on use")
--   warn   { text }                     -- red wrapped line (e.g. "Not enough mana")
-- `actor` (optional) is the unit the ability is priced and gated against: whatever stops it from
-- being cast right now (Combat.itemBlockReason) reddens the offending row and closes the ability
-- section with a `warn` block spelling the reason out. `owner` (optional) is the out-of-battle
-- character carrying it, and asks the permanent version of the same question instead.
local function buildBlocks(item, actor, innerW, out, owner)
    local blocks = {}
    -- The one reason this item can't be activated (nil when it can, or when it's passive).
    local blocked = Combat.itemBlockReason(actor, item)
    -- Every price on the item this body's pools could never meet, however rested -- keyed by pool, so
    -- the cost row that names one can turn red on its own. Empty in a fight, where `blocked` above is
    -- the sharper reading (it knows what is actually in the pool this turn).
    local unpayable = owner and Combat.unpayableCosts(owner, item) or {}
    local unpayableStat = {}
    for _, short in ipairs(unpayable) do unpayableStat[short.stat] = true end
    -- ...and the other half of "this will not work": a requirement the grid does not answer from where
    -- the item sits (Combat.adjacencyGap). Same source for the Requires row's colour below and for the
    -- warning at the foot, so the row and the line can never disagree about whether it is met.
    local adjacent = owner and Combat.adjacencyGap(owner, item) or nil

    -- The header is a TWO-COLUMN row (the mock's flex `.th`): the bone-gold NAME + muted type eyebrow on
    -- the left, and -- when the item has one -- the big headline value + its label on the RIGHT, on the
    -- SAME row as the name (not a separate row below). One block draws both columns.
    local header = { kind = "header", name = item.name or "Item",
        typeText = (item.type and item.type:upper()) or "ITEM" }
    blocks[#blocks + 1] = header

    -- Primary stat: the one magnitude that defines the item (a blade's Power, armor's defense), quoted at
    -- its current upgrade level. `primaryLabel` names the stat so the armor bonus block can skip it below
    -- and not print the same number twice.
    local primaryValue, primaryLabel, primaryKey = Item.primaryStat(item)
    if primaryValue then
        header.value = primaryValue
        header.valueLabel = primaryLabel:upper()
    end

    if item.description and item.description ~= "" then
        blocks[#blocks + 1] = { kind = "desc", text = item.description }
    end

    -- The taxonomy this item belongs to (a shop taxonomy; docs/classes.md). If it carries a discipline
    -- -- the locked deeper cut -- that names the row; otherwise its base shelf `class` does, since a
    -- discipline is sparse (most items carry none) but nearly everything sits on some shelf. Only a
    -- truly class-less good (a natural weapon, a universal supply) shows neither.
    local discName = Discipline.displayName(item.discipline)
    if discName then
        blocks[#blocks + 1] = { kind = "sep" }
        blocks[#blocks + 1] = { kind = "stat", label = "Discipline", value = discName, valueColor = DISC }
    elseif item.class then
        blocks[#blocks + 1] = { kind = "sep" }
        blocks[#blocks + 1] = { kind = "stat", label = "Class", value = Item.classDisplayName(item.class), valueColor = CLASS }
    end

    if item.tags and #item.tags > 0 then
        blocks[#blocks + 1] = { kind = "sep" }
        blocks[#blocks + 1] = { kind = "stat", label = "Tags", value = table.concat(item.tags, ", ") }
    end

    -- A stackable consumable shows how many uses remain -- for a real stack (>1) and for a spent
    -- one (0, tinted red; the trailing warn explains the slot is kept but can't be used).
    local qty = item.quantity or 1
    if Combat.isDepleted(item) then
        blocks[#blocks + 1] = { kind = "sep" }
        blocks[#blocks + 1] = { kind = "stat", label = "Quantity", value = "x0", valueColor = WARN }
    elseif qty > 1 then
        blocks[#blocks + 1] = { kind = "sep" }
        blocks[#blocks + 1] = { kind = "stat", label = "Quantity", value = "x" .. qty }
    end

    local ab = item.activeAbility
    if ab then
        blocks[#blocks + 1] = { kind = "sep" }
        blocks[#blocks + 1] = { kind = "head", text = item.name or "Active Ability" }

        -- What the ability DOES, in prose, sat right under its heading -- above the stat rows and the
        -- unlock gate. An item's top `description` speaks for the item as a whole (a shield's passive
        -- guard); a signature's conditional payoff is its own effect and needs saying where the player
        -- is looking when they read "Weather 4 blows". Optional: a plain spell whose whole item IS the
        -- ability lets the top description carry it and omits this (docs/item-text.md).
        if ab.description and ab.description ~= "" then
            blocks[#blocks + 1] = { kind = "desc", text = ab.description }
        end

        -- Ability output beyond the headline Power (drawn up top): a healing ability shows its heal
        -- amount, plus any status it applies. A dry-run against a zero-defense stand-in tells damage
        -- from heal and surfaces the statuses; with no actor (an Armory hover) it runs against a
        -- neutral caster so the derived numbers still show, just without the actor's stats folded in.
        -- The run itself happens once in `draw` and is handed down, since the glossary column beside
        -- this tooltip reads the very same statuses off it.
        if out then
            if out.heal > 0 then
                blocks[#blocks + 1] = { kind = "stat", label = "Heal",
                    value = "+" .. out.heal, valueColor = HEAL }
            end
            for _, st in ipairs(out.statuses) do
                local def = st.def or {}
                blocks[#blocks + 1] = { kind = "stat", label = "Applies",
                    value = def.name or st.id or "status", valueColor = def.color or VALUE }
                -- How long the mark rides the target -- the same clock the badge counts down. A
                -- Vulnerable opener, a Ward, or an Immunity is bought FOR its window, so the tooltip
                -- has to price that window like it prices a hazard's lifespan just above. A
                -- self-expiring status (hideDuration, e.g. Defending) carries a meaningless countdown
                -- and opts out, exactly as its hover tooltip does.
                local dur = (st.opts and st.opts.duration) or def.duration
                if dur and dur > 0 and not def.hideDuration then
                    blocks[#blocks + 1] = { kind = "stat", label = "Duration", icon = "hourglass",
                        value = tostring(dur) }
                end
            end
            -- Board effects the dry run recorded rather than performed. A summon still standing
            -- reddens the row that names it -- that creature is the reason the cast is refused.
            if out.summon then
                local def = Character.defs[out.summon]
                blocks[#blocks + 1] = { kind = "stat", label = "Summons",
                    value = (def and def.name) or "a double",
                    valueColor = (blocked and blocked.kind == "active" and WARN) or SUMMON }
                -- A timed summon fades on its own; an ability that omits `duration` says so, since
                -- "until it dies" is the load-bearing difference between the wolf and the elemental.
                blocks[#blocks + 1] = { kind = "stat", label = "Duration",
                    value = out.summonDuration and tostring(out.summonDuration) or "Until slain" }
            end
            -- A trap-placing ability names the trap it summons and spells out what crossing it does:
            -- its blueprint flavour, then the raw damage / status a victim eats (dry-run via
            -- Trap.preview), and how much punishment the armed trap soaks before it breaks.
            if out.trap then
                local tdef = Trap.defs[out.trap] or {}
                local tp = Trap.preview(out.trap, out.trapAmount)
                blocks[#blocks + 1] = { kind = "stat", label = "Places",
                    value = tdef.name or "a trap", valueColor = SUMMON }
                if tdef.description and tdef.description ~= "" then
                    blocks[#blocks + 1] = { kind = "note", text = tdef.description }
                end
                if tp and tp.damage > 0 then
                    blocks[#blocks + 1] = { kind = "stat", label = "Trap damage",
                        value = tostring(tp.damage), valueColor = POWER }
                end
                for _, st in ipairs(tp and tp.statuses or {}) do
                    local def = st.def or {}
                    blocks[#blocks + 1] = { kind = "stat", label = "Trap applies",
                        value = def.name or st.id or "status", valueColor = def.color or VALUE }
                end
                if tdef.health then
                    blocks[#blocks + 1] = { kind = "stat", label = "Trap HP", value = tostring(tdef.health) }
                end
            end
            -- A hazard-laying ability (Sanctuary, Rain, Quicksand, a Fireball's embers) names the ground
            -- it paints, what standing in it does (dry-run via Hazard.preview), and how long it lasts --
            -- the lifespan quoted at this upgrade level, since the item hands it in.
            if out.hazard then
                local hdef = Hazard.defs[out.hazard] or {}
                local hp = Hazard.preview(out.hazard, out.hazardAmount)
                blocks[#blocks + 1] = { kind = "stat", label = "Places",
                    value = hdef.name or "a hazard", valueColor = SUMMON }
                if hdef.description and hdef.description ~= "" then
                    blocks[#blocks + 1] = { kind = "note", text = hdef.description }
                end
                for _, st in ipairs(hp and hp.statuses or {}) do
                    local def = st.def or {}
                    blocks[#blocks + 1] = { kind = "stat", label = "Applies",
                        value = def.name or st.id or "status", valueColor = def.color or VALUE }
                    -- A ticking status (Regeneration heals, Burn sears) quotes its per-turn magnitude;
                    -- a flat one (Wet, Mired) carries none and shows just its name.
                    if st.magnitude and st.magnitude > 0 then
                        blocks[#blocks + 1] = { kind = "stat", label = "Per turn", value = tostring(st.magnitude) }
                    end
                end
                if out.hazardDuration then
                    blocks[#blocks + 1] = { kind = "stat", label = "Duration", value = tostring(out.hazardDuration) }
                end
            end
            if out.knockback then
                blocks[#blocks + 1] = { kind = "stat", label = "Knockback",
                    value = out.knockback .. (out.knockback == 1 and " tile" or " tiles") }
            end
            if out.pull then
                blocks[#blocks + 1] = { kind = "stat", label = "Pull", value = "To adjacent" }
            end
            if out.steal then
                blocks[#blocks + 1] = { kind = "stat", label = "Steals", value = "One item" }
            end
            if out.reveal then
                blocks[#blocks + 1] = { kind = "stat", label = "Reveals", value = "Enemy kit", valueColor = SUMMON }
            end
        end

        if ab.target then
            blocks[#blocks + 1] = { kind = "stat", label = "Target",
                value = TARGET_LABEL[ab.target] or titleCase(ab.target) }
        end
        local rangeText = tostring(ab.range or 1)
        if ab.minRange and ab.minRange > 1 then
            -- A weapon with a dead zone shows the band it can hit (e.g. "2-3") rather than just the max.
            rangeText = ab.minRange .. "-" .. (ab.range or 1)
        end
        blocks[#blocks + 1] = { kind = "stat", label = "Range", value = rangeText }
        -- A little diamond map of that reach beneath the number: the caster at the centre, the
        -- tiles it can strike tinted green (a friendly cast) or red (a hostile one). Skipped for a
        -- self-only ability (range 0), which has no reach to draw.
        local diagram = RangeDiagram.layout(ab, innerW)
        if diagram then
            blocks[#blocks + 1] = { kind = "rangediag", layout = diagram,
                color = Combat.isSupportAbility(ab) and RANGE_FRIENDLY or RANGE_HOSTILE }
        end
        -- The AREA footprint: the tiles the cast actually sweeps (a spear's line, an axe's arc, a
        -- blast's square), drawn around the caster. Shape is structured `aoe` data, so it belongs in
        -- a picture, not the description. Skipped for a single-target cast (no aoe) and for a
        -- board-dependent footprint (aoe.cells), which FootprintDiagram cannot picture off-board.
        local aoe = ab.aoe
        if aoe and not aoe.cells and (aoe.shape or (aoe.radius and aoe.radius > 0)) then
            blocks[#blocks + 1] = { kind = "footprintdiag", aoe = aoe, box = 60,
                color = Combat.isSupportAbility(ab) and RANGE_FRIENDLY or RANGE_HOSTILE }
        end
        if ab.speed then
            blocks[#blocks + 1] = { kind = "stat", label = "Speed", value = tostring(ab.speed) }
        end
        -- A channeled spell (a big AOE like Meteor Storm) winds up before it fires: the caster is
        -- exposed and the effect resolves on its next slot, so the tell is a real cost worth quoting.
        -- A CHARGEABLE one (The First Motion) quotes the whole range it may be held for rather than
        -- just its floor -- the depth is the player's to choose, so the cheapest and deepest holds are
        -- both facts about the item. The note spells out the tradeoff (foes can scatter; hard control
        -- breaks it). The hourglass rides it because this is a duration (ui/glyphs.lua).
        local windLo, windHi = Item.windupRange(ab)
        if windHi > 0 then
            blocks[#blocks + 1] = { kind = "stat", label = "Wind-up", icon = "hourglass",
                value = (windHi > windLo) and (windLo .. "-" .. windHi) or tostring(windLo) }
            blocks[#blocks + 1] = { kind = "note", text = "Winds up before it fires; disrupted by hard control or forced movement" }
        end
        -- Price the cast for THIS actor: a cost-reducing status (Haste) is already folded into
        -- Combat.abilityCosts, so the tooltip quotes what will actually be paid. A cast drawing on
        -- two pools gets a row each: they are two separate demands on two separate bars, and the
        -- one that is actually short has to be able to turn red on its own.
        local costs = actor and Combat.abilityCosts(actor, ab) or Item.costs(ab)
        for i, cost in ipairs(costs) do
            local short = (blocked and blocked.kind == "cost" and blocked.stat == cost.stat)
                or unpayableStat[cost.stat]
            blocks[#blocks + 1] = { kind = "stat", label = i == 1 and "Cost" or "",
                value = cost.amount .. " " .. titleCase(cost.stat),
                valueColor = short and WARN or RES_COLOR[cost.stat] }
        end
        -- A charge/counter item quotes what it currently holds -- the purse the cast spends (the
        -- Gleaning Rod's banked charges, the Reliquary of Tallies' owed dead) -- red at 0, where the
        -- cast is refused (blocked.kind == "empty"). The same count the grid badge shows.
        if ab.counter then
            local n = ab.counter(actor, item) or 0
            -- Red only when an empty count refuses the cast; a non-gating readout (the Long Count's turn
            -- tally, `counterGates = false`) quotes 0 as an ordinary value. `counterLabel` lets a scaling
            -- weapon name its count something truer than "Charges" (the Long Count calls them "Turns").
            local gated = ab.counterGates ~= false
            blocks[#blocks + 1] = { kind = "stat", label = ab.counterLabel or "Charges", icon = "charges",
                value = tostring(n), valueColor = (n <= 0 and gated) and WARN or VALUE }
        end
        -- A reservation is spent AND locked: the share of the pool's MAXIMUM this ability pays on the
        -- cast and keeps locked away for as long as what it summons survives.
        if ab.reserve then
            local pct = math.floor((ab.reserve.percent or 0) * 100 + 0.5)
            local value = pct .. "% of max " .. ab.reserve.stat
            local reserve = actor and Combat.abilityReserve(actor, ab)
            if reserve then value = reserve.amount .. " " .. titleCase(reserve.stat) .. " (" .. pct .. "%)" end
            blocks[#blocks + 1] = { kind = "stat", label = "Reserves", value = value,
                valueColor = (blocked and blocked.kind == "reserve" and WARN)
                    or RES_COLOR[ab.reserve.stat] or VALUE }
            blocks[#blocks + 1] = { kind = "note", text = "Spent on cast, unrecoverable until the summon is gone" }
        end
        -- An adjacency requirement always shows, green once the grid satisfies it and red while it
        -- doesn't -- the same green as the connector line the item grid draws to the neighbor.
        --
        -- THREE STATES rather than two once an `owner` is known, because green is a claim and there is
        -- a case it cannot honestly make. Out of battle `blocked` is always nil, so this row used to
        -- render green on every loadout tooltip in the game -- reporting "requirement met" over a Rain
        -- of Arrows sitting three cells from the nearest bow. Red is the gap (`adjacent`); green is a
        -- requirement genuinely answered where the item sits; and an item still in the STASH gets
        -- neither, since a piece that is nowhere is neither met nor unmet -- it is placeable, which is
        -- what the plain ink says.
        if ab.requiresAdjacent then
            local unmet = (blocked and blocked.kind == "adjacency") or adjacent ~= nil
            local color = MET
            if unmet then color = WARN
            elseif owner and not Character.slotIndex(owner, item) then color = VALUE end
            blocks[#blocks + 1] = { kind = "stat", label = "Requires",
                value = titleCase(Combat.adjacencyLabel(ab.requiresAdjacent)),
                valueColor = color }
        end
        if ab.consumesItem then
            blocks[#blocks + 1] = { kind = "note", text = "Consumed on use" }
        end
        -- A signature ability names its in-battle requirement even when it is ready, so the mechanic
        -- reads at a glance. While it is still locked the `warn` below carries the same requirement WITH
        -- its progress, so this note steps aside to avoid saying it twice.
        if ab.unlock and not blocked then
            blocks[#blocks + 1] = { kind = "note", text = "Signature -- " .. (ab.unlock.text or "charges as you fight") }
        end
        -- Why this can't be cast right now, closing the ability section it applies to.
        if blocked then
            blocks[#blocks + 1] = { kind = "warn", text = blocked.text }
        end
    end

    -- A CHARGE POOL this item banks into or spends from -- Zeal, Defiance, Tempo, Arcane, the monk's
    -- chi -- named and counted, in the same charges glyph the purse row above wears. Deliberately
    -- OUTSIDE the ability section that closes just above: half the pool items have no ability at all
    -- (the Crusader's Tabard, the Vow of the March), and a charm whose entire function is to accrue is
    -- the one that most needs to say how much it is holding.
    --
    -- Quoted as n of max because banking past a full pool is silently discarded, so the ceiling is the
    -- number that says when to stop saving and spend. Named for the pool rather than called "Charges",
    -- since these are shared bars the whole grid banks into -- "Zeal 5 of 8" tells you which of the
    -- unit's pools moved; a row reading "Charges" over two different pools would not.
    -- Falling back to a stacking TRAIT's count (Trait.stackReadout) when there is no pool: the
    -- Butcher's Tally and the Blood Fever Mail bank bodies with no ability to hang a counter on, and
    -- the strap is literally named for notches it was not showing. Named for the trait, since that is
    -- what the count belongs to and what the description above has already introduced.
    local pool, poolMax, poolLabel = Combat.itemChargeReadout(actor, item)
    if not pool then pool, poolMax, poolLabel = Trait.stackReadout(actor, item) end
    if pool and not (ab and ab.counter) then
        blocks[#blocks + 1] = { kind = "sep" }
        blocks[#blocks + 1] = { kind = "stat", label = poolLabel, icon = "charges",
            value = pool .. " of " .. poolMax }
    end

    -- What this item's triggered reflex (a Riposte Blade's parry) costs in TIME. Always quoted when the
    -- item has one, because the length is the item's own property and the description cannot carry it:
    -- "then it goes on cooldown" is a sentence with the number missing, and a player deciding whether to
    -- buy the thing is deciding on exactly that number.
    --
    -- While the reflex IS spent the same row counts down instead ("3 of 8", red) and a note says so --
    -- the words behind the item grid's cooldown clock. Not a `blocked` reason: nothing is being cast, so
    -- there is nothing to refuse. Bare ticks under the hourglass, like every other duration.
    local cooling = Combat.itemCooldown(actor, item)
    local cdTicks = declaredCooldown(item)
    if cooling or cdTicks then
        blocks[#blocks + 1] = { kind = "sep" }
        if cooling then
            local left = math.max(0, math.ceil(cooling.remaining))
            blocks[#blocks + 1] = { kind = "stat", label = "Cooldown", icon = "hourglass",
                value = left .. " of " .. math.max(left, math.ceil(cooling.total)), valueColor = WARN }
            blocks[#blocks + 1] = { kind = "note",
                text = (cooling.trait.name or "Its reflex") .. " has fired; it cannot trigger again until the cooldown runs out." }
        else
            blocks[#blocks + 1] = { kind = "stat", label = "Cooldown", icon = "hourglass",
                value = tostring(cdTicks) }
        end
    end

    -- Passive armor: flat stat bonuses + tag-keyed damage resistances. The stat that already leads as
    -- the headline (defense, usually) is skipped here so the same number is not printed twice; the
    -- block shows the extras (a second defense, the movement penalty).
    local bonusShown = false
    if item.bonus and next(item.bonus) then
        for _, stat in ipairs(sortedKeys(item.bonus)) do
            if stat ~= primaryKey then
                local amount = item.bonus[stat]
                if not bonusShown then blocks[#blocks + 1] = { kind = "sep" }; bonusShown = true end
                blocks[#blocks + 1] = { kind = "stat", label = titleCase(stat),
                    value = (amount >= 0 and "+" or "") .. tostring(amount) }
            end
        end
    end
    if item.resist and next(item.resist) then
        if not bonusShown then blocks[#blocks + 1] = { kind = "sep" } end
        local parts = {}
        for _, tag in ipairs(sortedKeys(item.resist)) do
            parts[#parts + 1] = tag .. " " .. tostring(item.resist[tag])
        end
        blocks[#blocks + 1] = { kind = "stat", label = "Resist", value = table.concat(parts, ", ") }
    end

    -- A guard charm reserves a share of the bearer's health for the whole battle, and the armor above is
    -- what that locked health buys. Named as a cost (WARN) with the lock spelled out, because a reserve
    -- is not a wound you heal off -- Combat.unreservedMax lowers the ceiling, so the health cannot come
    -- back. Quotes the percentage; against a known actor it resolves to that body's own number, exactly
    -- as an ability's reserve row does above.
    if item.healthReserve and item.healthReserve.percent then
        local pct = math.floor(item.healthReserve.percent * 100 + 0.5)
        local value = "-" .. pct .. "% Health"
        local amount = actor and actor.char and Combat.healthReserveAmount(actor.char, item)
        if amount and amount > 0 then value = "-" .. amount .. " Health (" .. pct .. "%)" end
        blocks[#blocks + 1] = { kind = "sep" }
        blocks[#blocks + 1] = { kind = "stat", label = "Reserves", value = value, valueColor = WARN }
        blocks[#blocks + 1] = { kind = "note",
            text = "Reserved health is locked away for the battle; it cannot be healed back." }
    end

    -- Wait-swap: an item that changes how this holder's Wait acts (a shield's Defend, a focus charm,
    -- an overwatch scope) spells out the swap and how much it grants. A shield's brace-defense is
    -- resolved to the item's upgrade level, so it quotes what the current (forged) shield actually braces.
    local wb = item.waitBehavior
    if wb and wb.kind and wb.kind ~= "delay" then
        blocks[#blocks + 1] = { kind = "sep" }
        if wb.kind == "defend" then
            blocks[#blocks + 1] = { kind = "stat", label = "Wait becomes", value = "Defend" }
            if wb.defense then
                blocks[#blocks + 1] = { kind = "stat", label = "Brace defense",
                    value = "+" .. tostring(wb.defense), valueColor = BRACE }
            end
            blocks[#blocks + 1] = { kind = "note",
                text = "Defend ends your turn to brace: raises physical defense until your next turn." }
        elseif wb.kind == "focus" then
            blocks[#blocks + 1] = { kind = "stat", label = "Wait becomes", value = "Focus" }
            if wb.mana then
                blocks[#blocks + 1] = { kind = "stat", label = "Restores", value = "+" .. tostring(wb.mana) .. " Mana" }
            end
            blocks[#blocks + 1] = { kind = "note", text = "Focus ends your turn to recover mana." }
        elseif wb.kind == "overwatch" then
            blocks[#blocks + 1] = { kind = "stat", label = "Wait becomes", value = "Overwatch" }
            blocks[#blocks + 1] = { kind = "note", text = "Overwatch ends your turn to fire on the first foe that moves into range." }
        elseif wb.kind == "gather" then
            blocks[#blocks + 1] = { kind = "stat", label = "Wait becomes", value = "Gather" }
            if wb.power then
                blocks[#blocks + 1] = { kind = "stat", label = "Stored force",
                    value = "+" .. tostring(wb.power) .. " Attack", valueColor = BRACE }
            end
            blocks[#blocks + 1] = { kind = "note",
                text = "Gather ends your turn to coil: your next landed blow carries the stored force." }
        elseif wb.kind == "perform" then
            blocks[#blocks + 1] = { kind = "stat", label = "Wait becomes", value = "Perform" }
            -- The whole cycle, in order, because the ORDER is the cost: reaching the air you want means
            -- spending the turns to walk through the ones you did not. A tooltip that listed only the
            -- next air would hide the actual decision the item asks for.
            for i, song in ipairs(wb.songs or {}) do
                blocks[#blocks + 1] = { kind = "stat", label = (i == 1 and "Airs" or ""), value = song.name or "?" }
            end
            if wb.duration then
                blocks[#blocks + 1] = { kind = "stat", label = "Each holds", icon = "hourglass",
                    value = tostring(wb.duration) }
            end
            if wb.earshot then
                blocks[#blocks + 1] = { kind = "stat", label = "Earshot", value = tostring(wb.earshot) .. " tiles" }
            end
            blocks[#blocks + 1] = { kind = "note",
                text = "Perform ends your turn to sound the next air, for you and every ally in earshot." }
        end
    end

    -- Utility passives.
    if item.visionRadius or item.detectRadius then
        blocks[#blocks + 1] = { kind = "sep" }
        if item.visionRadius then
            blocks[#blocks + 1] = { kind = "stat", label = "Vision", value = "+" .. tostring(item.visionRadius) }
        end
        if item.detectRadius then
            blocks[#blocks + 1] = { kind = "stat", label = "Trap detect", value = tostring(item.detectRadius) }
        end
    end

    -- Everything that stops this item working for this body, at the foot of everything mechanical: a
    -- price the pools will never meet, and a requirement the grid does not answer.
    --
    -- Deliberately NOT inside the ability section that `blocked` closes, even though each usually has a
    -- row up there naming the same fact: a price may come from a TRAIT, which the tooltip prints no
    -- cost row for at all (a Counter-Magic charm on a body with no mana is the quietest dead slot in
    -- the game, since a trait never even offers itself to be clicked). One place to look, whichever
    -- part is at fault.
    if #unpayable > 0 or adjacent then
        blocks[#blocks + 1] = { kind = "sep" }
        for _, short in ipairs(unpayable) do
            blocks[#blocks + 1] = { kind = "warn", text = short.text }
        end
        if adjacent then blocks[#blocks + 1] = { kind = "warn", text = adjacent.text } end
    end

    -- The story line has the tooltip's last word, below everything mechanical (docs/item-text.md).
    if item.flavor and item.flavor ~= "" then
        blocks[#blocks + 1] = { kind = "sep" }
        blocks[#blocks + 1] = { kind = "flavor", text = item.flavor }
    end

    return blocks
end

-- Measure `item` into a layout the paint pass can render without recomputing any of it: the ordered
-- blocks with their wrapped line counts, the box's size, and the one ability dry run everything quotes.
--
-- Split out from `draw` because a caller showing SEVERAL tooltips at once (the draft unit sheet opens
-- one per carried piece) has to know how tall each box is BEFORE it can decide where any of them goes.
-- It is also the expensive half -- the dry run and the wrapping live here -- so such a caller can
-- memoize the layout per item and repaint it every frame for free.
function ItemTooltip.measure(item, actor, owner)
    if not item then return nil end
    local title, body, small, power = fonts()
    local pad, w = 9, ItemTooltip.WIDTH
    local innerW = w - pad * 2

    -- One dry run per hover, shared: the blocks below quote its numbers and the glossary column beside
    -- the box names the statuses it turned up.
    local out = Combat.abilityOutput(actor, item) or false
    local blocks = buildBlocks(item, actor, innerW, out, owner)
    local titleH, bodyH, smallH, powerH = title:getHeight(), body:getHeight(), small:getHeight(), power:getHeight()

    -- Measure: sum each block's height (wrapping desc against innerW, cached for the draw pass).
    local h = pad
    for _, b in ipairs(blocks) do
        if b.kind == "header" then
            -- reserve the taller of the two columns: title+eyebrow (left) vs value+label (right)
            local leftH = titleH + 3 + smallH
            h = h + math.max(leftH, b.value and (powerH + smallH) or 0) + 4
        elseif b.kind == "desc" or b.kind == "warn" then
            local _, lines = body:getWrap(b.text, innerW)
            b.lines = math.max(1, #lines)
            h = h + b.lines * bodyH + 2
        elseif b.kind == "flavor" then
            -- Wrapped in the italic face, exactly as ItemTooltip.printFlavor draws it.
            local _, lines = flavorFont():getWrap(b.text, innerW - FLAVOR_GUARD)
            b.lines = math.max(1, #lines)
            h = h + b.lines * bodyH + 2
        elseif b.kind == "note" then
            local _, lines = body:getWrap(b.text, innerW)
            b.lines = math.max(1, #lines)
            h = h + b.lines * bodyH + 1
        elseif b.kind == "sep" then h = h + 8
        elseif b.kind == "head" then h = h + bodyH + 2
        elseif b.kind == "rangediag" then h = h + b.layout.height + 4
        elseif b.kind == "footprintdiag" then h = h + smallH + 2 + b.box + 4
        else -- stat: the value wraps in the column left over beside the label
            local vx, vw, lines = statLayout(body, b.label, b.value, innerW)
            b.valueX, b.valueW, b.lines = vx, vw, lines
            h = h + b.lines * bodyH + 1
        end
    end
    h = h + pad

    return { item = item, actor = actor, out = out, blocks = blocks, w = w, h = h }
end

-- Paint a measured `layout` with its top-left pinned exactly at (bx, by) -- no cursor offset, no
-- clamping: the caller placing it has already chosen the spot. `opts.accent` overrides the border tint
-- (the draft cluster rings the piece the pointer is on, so a hovered icon and its box are visibly the
-- same thing). Returns the box's { x, y, w, h }, which is what GlossaryPanel.draw anchors off.
function ItemTooltip.paint(layout, bx, by, opts)
    if not layout then return nil end
    local title, body, small, power = fonts()
    local pad, w = 9, layout.w
    local innerW = w - pad * 2
    local blocks = layout.blocks
    local titleH, bodyH, smallH, powerH = title:getHeight(), body:getHeight(), small:getHeight(), power:getHeight()
    local h = layout.h

    Theme.set(Theme.panel)
    love.graphics.rectangle("fill", bx, by, w, h, 4, 4)
    -- bone-gold border: the mock frames the tooltip in trim, not the type accent
    local accent = opts and opts.accent
    if accent then love.graphics.setColor(accent[1], accent[2], accent[3], accent[4] or 1)
    else Theme.set(Theme.frame) end
    love.graphics.setLineWidth(accent and 2 or 1)
    love.graphics.rectangle("line", bx, by, w, h, 4, 4)
    love.graphics.setLineWidth(1)

    local ty = by + pad
    for _, b in ipairs(blocks) do
        if b.kind == "header" then
            -- Left column: bone-gold name, muted type eyebrow beneath it.
            love.graphics.setFont(title)
            love.graphics.setColor(TITLE[1], TITLE[2], TITLE[3], 1)
            love.graphics.print(b.name, bx + pad, ty)
            love.graphics.setFont(small)
            love.graphics.setColor(MUTED[1], MUTED[2], MUTED[3], 0.9)
            love.graphics.print(b.typeText, bx + pad, ty + titleH + 3)
            -- Right column (same row as the name): the big headline value, its label beneath it.
            if b.value then
                love.graphics.setFont(power)
                love.graphics.setColor(POWER[1], POWER[2], POWER[3], 1)
                love.graphics.printf(tostring(b.value), bx + pad, ty - 1, innerW, "right")
                love.graphics.setFont(small)
                love.graphics.setColor(MUTED[1], MUTED[2], MUTED[3], 1)
                love.graphics.printf(b.valueLabel, bx + pad, ty + powerH - 2, innerW, "right")
            end
            local leftH = titleH + 3 + smallH
            ty = ty + math.max(leftH, b.value and (powerH + smallH) or 0) + 4
        elseif b.kind == "desc" then
            love.graphics.setFont(body)
            love.graphics.setColor(DESC[1], DESC[2], DESC[3], 1)
            love.graphics.printf(b.text, bx + pad, ty, innerW, "left")
            ty = ty + b.lines * bodyH + 2
        elseif b.kind == "sep" then
            -- A faint group divider. Kept subtle (the mock leans on dotted leaders + spacing, not bold
            -- rules) so the dense real tooltip still groups without a ladder of hard lines.
            Theme.set(Theme.frame, 0.24)
            love.graphics.line(bx + pad, ty + 4, bx + w - pad, ty + 4)
            ty = ty + 8
        elseif b.kind == "head" then
            love.graphics.setFont(body)
            Theme.set(Theme.accentAmber)
            love.graphics.print(b.text, bx + pad, ty)
            ty = ty + bodyH + 2
        elseif b.kind == "rangediag" then
            -- Centre the diamond in the content column, a hair below the Range number.
            local gx = bx + pad + math.floor((innerW - b.layout.width) / 2)
            RangeDiagram.draw(b.layout, gx, ty + 2, b.color)
            ty = ty + b.layout.height + 4
        elseif b.kind == "footprintdiag" then
            -- A "Shape" caption over the drawn footprint, so it never reads as a second reach map.
            love.graphics.setFont(small)
            love.graphics.setColor(MUTED[1], MUTED[2], MUTED[3], 0.9)
            love.graphics.print("Shape", bx + pad, ty)
            local gx = bx + pad + math.floor((innerW - b.box) / 2)
            FootprintDiagram.draw(b.aoe, gx, ty + smallH + 2, b.box, b.color)
            ty = ty + smallH + 2 + b.box + 4
        elseif b.kind == "flavor" then
            ItemTooltip.printFlavor(b.text, bx + pad, ty, innerW)
            ty = ty + b.lines * bodyH + 2
        elseif b.kind == "note" then
            love.graphics.setFont(body)
            love.graphics.setColor(MUTED[1], MUTED[2], MUTED[3], 1)
            love.graphics.printf(b.text, bx + pad, ty, innerW, "left")
            ty = ty + b.lines * bodyH + 1
        elseif b.kind == "warn" then
            love.graphics.setFont(body)
            love.graphics.setColor(WARN[1], WARN[2], WARN[3], 1)
            love.graphics.printf(b.text, bx + pad, ty, innerW, "left")
            ty = ty + b.lines * bodyH + 2
        else -- stat: label left, value right, a dotted leader walking the eye between them
            love.graphics.setFont(body)
            love.graphics.setColor(MUTED[1], MUTED[2], MUTED[3], 1)
            love.graphics.print(b.label, bx + pad, ty)
            local vc = b.valueColor or VALUE
            local cx = bx + pad + b.valueX
            local valueLeft = cx + b.valueW - body:getWidth(b.value)
            if b.icon == "hourglass" or b.icon == "charges" then valueLeft = valueLeft - GLYPH_GAP - 7 end
            Theme.leader(bx + pad + body:getWidth(b.label) + 6, valueLeft - 6, ty + bodyH - 3)
            love.graphics.setColor(vc[1], vc[2], vc[3], 1)
            love.graphics.printf(b.value, cx, ty, b.valueW, "right")
            -- An optional glyph riding just ahead of the VALUE (never the label), tinted to match it:
            -- glyph-then-number is how the grid's badges quote a tick, so a tooltip row quoting one
            -- reads the same way. Placed off the value's own width, since the value is right-aligned.
            if b.icon == "hourglass" then
                local gw = 7
                local vx = cx + b.valueW - body:getWidth(b.value)
                Glyphs.hourglass(vx - GLYPH_GAP - gw, ty + 2, gw, bodyH - 4, vc[1], vc[2], vc[3], 1)
            elseif b.icon == "charges" then
                local gw = 7
                local vx = cx + b.valueW - body:getWidth(b.value)
                Glyphs.charges(vx - GLYPH_GAP - gw, ty + 2, gw, bodyH - 4, vc[1], vc[2], vc[3], 1)
            end
            ty = ty + b.lines * bodyH + 1
        end
    end

    love.graphics.setColor(1, 1, 1)
    return { x = bx, y = by, w = w, h = h }
end

-- Draw the tooltip for `item` anchored near (mx, my). `maxRight` caps the box's right edge so it
-- never slides under a side panel (defaults to the screen width). No-op when item is nil.
function ItemTooltip.draw(item, mx, my, maxRight, actor, owner)
    local layout = ItemTooltip.measure(item, actor, owner)
    if not layout then return end
    local w, h = layout.w, layout.h
    maxRight = maxRight or Scale.WIDTH

    -- Position near the cursor; flip left and clamp so the box stays within [4, maxRight].
    local bx = mx + 14
    local maxX = maxRight - w - 4
    if bx > maxX then bx = mx - w - 14 end
    bx = math.max(4, math.min(bx, maxX))
    local by = math.max(4, math.min(my + 16, Scale.HEIGHT - h - 4))

    local box = ItemTooltip.paint(layout, bx, by)

    -- The definitions for every proper noun this tooltip just dropped -- the statuses it applies, the
    -- keywords its ability declares -- in a sibling column beside the box. Drawn last, and positioned
    -- off the box we just measured, so it lands next to the tooltip rather than under the cursor.
    GlossaryPanel.draw(Glossary.forItem(item, actor, layout.out), box, maxRight)
    return box
end

return ItemTooltip
