-- The WIKI, generated from the data layer: run with
--
--     & "E:\LOVE\lovec.exe" . wiki-gen [OUTDIR]
--
-- The wiki used to be a mirror of docs/ -- thirty-eight design documents, sixteen thousand lines of
-- argument about why the game is shaped the way it is, published verbatim to a public page. That is
-- the wrong artifact in the wrong place twice over: the arguments are for whoever is CHANGING the
-- game and they live beside the code where a change can be made in the same commit, while a wiki is
-- read by somebody who wants to know what an item DOES. So the wiki stops mirroring the reasons and
-- starts mirroring the things. docs/ is untouched and still the design source; it is simply no longer
-- published.
--
-- WHY GENERATED, AND WHY FROM THE MODEL RATHER THAN THE FILES. Every number here is read the way the
-- game reads it -- Item.instantiate bakes a real instance at each forge level and Item.growth charts
-- it, so a damage curve on this page is the curve a player's weapon actually has, not a transcription
-- of a literal that a later rescale would leave behind. A hand-written page about 852 items is wrong
-- the week after it is written; this one cannot be, because there is nowhere for it to disagree.
--
-- BY CLASS, THEN BY TYPE, which is the shape of the question a reader arrives with. `class` is the
-- vendor shelf (models/item.lua) and never an equip gate, so a class page is "what the Knight's house
-- sells and what the rift gives up wearing its name" -- which is also how the shop, the drop pool and
-- the growth ladder all bucket the catalogue. `type` is the second cut because it decides what the
-- numbers MEAN: a weapon's stats are a swing, an armour's are what a swing is subtracted by.
--
-- A COLUMN THAT IS EMPTY ACROSS A WHOLE SECTION IS DROPPED. 148 traits spread over 207 of 852 items,
-- `hands` over 73, `maxStack` over consumables alone -- so a fixed column set would print five empty
-- columns on most tables and bury the two that matter. The row is built as a map and the header is
-- derived from what the rows actually filled, which means a new field shows up the day it is authored
-- and costs nothing on every page that does not use it.
--
-- Writes into the PROJECT tree via io.open (love.filesystem.write can only reach the save dir),
-- exactly as tools/icon_build.lua and tools/audio_commission.lua do. tools/wiki-sync.sh publishes
-- the result; this tool never touches the wiki clone or the network.

local Item = require("models.item")
local Class = require("models.class")
local Trait = require("models.trait")
local Spoils = require("models.spoils")
local Character = require("models.character")
local Race = require("models.race")
local Descent = require("models.descent")

local M = {}

-- WHICH BODY HANDS A FOUND ITEM OVER, built once per run and read by dropCell.
--
-- The measurement is NOT made here. tools/drop_report owns it (M.sources), because "which body drops
-- this" has to have one answer in the tree: the report grades the authoring and these pages print it,
-- and if each computed its own the two would drift the first time the route precedence moved -- a page
-- naming a body the report calls unreachable, with nothing anywhere to show the disagreement.
--
-- It is a MEASUREMENT and not a read of the blueprints, which is the part that matters for a reader.
-- An item named on a body's `drops` list is not actually obtainable unless some encounter seats that
-- body, and 122 of the 173 character blueprints are never placed at all. So a name on these pages
-- means a body you can really meet, and the silence where there is no name is honest too.
local DROPS = {}

-- The second half of that same sweep: charId -> { biomes = { [biome] = true }, ungated, encounters }.
-- The bestiary's "Where" is read off it, so an item page and a body page cannot disagree about which
-- ground a thing stands on -- they are two renderings of one measurement.
local PLACED = {}

local OUT_DEFAULT = "wiki"

-- The five buckets data/items/ is organised into, in reading order: what you swing, what you wear,
-- what you carry, what you cast, what you drink. An unknown type falls into a trailing "Other"
-- section rather than vanishing -- a bucket nobody has taught this tool about is still content.
local TYPES = {
    { id = "weapon",     title = "Weapons" },
    { id = "armor",      title = "Armor" },
    { id = "utility",    title = "Utility" },
    { id = "ability",    title = "Abilities" },
    { id = "consumable", title = "Consumables" },
}

-- Column order, once, for every table on every page. `align` is the markdown separator's business.
local COLUMNS = {
    { key = "item",   head = "Item" },
    { key = "stats",  head = "Stats" },
    { key = "use",    head = "Use" },
    { key = "traits", head = "Traits" },
    { key = "hands",  head = "Hands",  align = ":--:" },
    { key = "stack",  head = "Stack",  align = ":--:" },
    { key = "tags",   head = "Tags" },
    { key = "rank",   head = "Rank",   align = ":--:" },
    { key = "source", head = "Source" },
    { key = "drops",  head = "Dropped by" },
    { key = "notes",  head = "Notes" },
}

-- ---------------------------------------------------------------------------
-- formatting
-- ---------------------------------------------------------------------------

local function projectPath(rel)
    return love.filesystem.getSource() .. "/" .. rel
end

-- A markdown table cell: a pipe would end the column and a newline would end the row, so both are
-- neutralised here rather than at each of the fifteen places that build a cell.
local function cell(s)
    s = tostring(s or "")
    s = s:gsub("|", "\\|")
    s = s:gsub("%s*\n%s*", " ")
    return s
end

-- "plague_knight" -> "Plague-Knight". The page slug is derived from the ID and never from the display
-- name: a name is authored prose and may grow an apostrophe or a slash, and a filename may not.
local function slugOf(classId)
    local out = {}
    for word in tostring(classId):gmatch("[^_]+") do
        out[#out + 1] = word:sub(1, 1):upper() .. word:sub(2)
    end
    return table.concat(out, "-")
end

local function pageOf(classId)
    return "Items-" .. slugOf(classId)
end

local function bestiaryPageOf(kind)
    return "Bestiary-" .. slugOf(kind)
end

-- THE ANCHOR A HEADING GETS, computed the way the renderer that serves these pages computes it:
-- lowercased, every character that is neither alphanumeric nor a space nor a hyphen or underscore
-- dropped, then spaces to hyphens. "Acedia, the Unrelieved" -> `acedia-the-unrelieved`, and the em
-- dash in "Floor 3 — Gluttony" leaves the two spaces around it behind as `floor-3--gluttony`.
--
-- WRITTEN ONCE AND USED FOR BOTH ENDS. Every in-page link this tool emits is built from the same
-- heading text the section is titled with, through this function -- so a link cannot point at a
-- heading that is spelled differently, and tests/wiki_spec walks every one of them back to its
-- heading. (Lua's %w is ASCII under the C locale, which is what strips the multi-byte punctuation.)
local function anchorOf(heading)
    local s = tostring(heading):lower()
    s = s:gsub("[^%w%s%-_]", "")
    s = s:gsub("%s", "-")
    return s
end

-- Which section of its class page an item's row is in. The class page titles its sections off TYPES,
-- and its own counts line already links them this way -- this is that link, addressable from off-page.
local function typeAnchorOf(def)
    local t = (def and def.type) or "other"
    for _, e in ipairs(TYPES) do
        if e.id == t then return anchorOf(e.title) end
    end
    return anchorOf(t:sub(1, 1):upper() .. t:sub(2))
end

-- An item, named and addressed: the row this links to is the one the item's own class page prints.
-- Section-deep rather than row-deep because a markdown table row cannot carry an anchor -- the reader
-- lands on the right table of the right page and the row is the one bearing the name in the link.
local function itemLink(id)
    local def = Item.defs[id]
    if not def then return "`" .. cell(id) .. "`" end
    return "[" .. cell(def.name or id) .. "](" .. pageOf(def.class or "unclassed")
        .. "#" .. typeAnchorOf(def) .. ")"
end

-- A list of item ids as links, nil when the list is empty -- which is what lets a caller hand the
-- result straight to a line that is only printed when there is something to print.
local function itemLinks(ids)
    local parts = {}
    for _, entry in ipairs(ids or {}) do
        local id = entry
        if type(entry) == "table" then id = entry.id or entry[1] end
        if type(id) == "string" then parts[#parts + 1] = itemLink(id) end
    end
    if #parts == 0 then return nil end
    return table.concat(parts, " · ")
end

-- ---------------------------------------------------------------------------
-- the bestiary's address book
-- ---------------------------------------------------------------------------

-- WHERE EVERY BODY LIVES, resolved before a single page is rendered, because both directions of the
-- link need it: an item's "Dropped by" cell and the Rift's composition rows are written BEFORE the
-- bestiary pages exist, and both have to name the page and the anchor the body will get.
--
-- BY KIND rather than by race (models/race.lua). Race is the fine axis and kind is the coarse one it
-- rolls up to -- `race = "wolf"` with `kind = "beast"` is a refinement the model explicitly leaves
-- room for, and it must not scatter the wolves onto a page of their own the day somebody takes it. So
-- the pages are cut on the axis that is stable, and the race is printed on the body's own line.
local BODY_KINDS = {}   -- ordered kind ids
local BODIES = {}       -- kind -> { charId, ... }, in page order
local KIND_OF = {}      -- charId -> kind
local HEADING = {}      -- charId -> the text its section is titled with
local ANCHOR = {}       -- charId -> the anchor that heading gets

local function kindName(kind)
    local def = Race.defs[kind]
    return (def and def.name) or slugOf(kind)
end

-- THE RACES THAT ROLL UP INTO A KIND, which is what a kind page has to say about itself instead of
-- quoting a race blurb. Six of the eight kinds are named after their one race and could have borrowed
-- its line; `humanoid` is not -- human and naga share it -- and a page whose description silently
-- vanishes for the one kind that is actually a rollup would be the axis breaking exactly where it
-- earns its keep.
local function racesOf(kind)
    local out = {}
    for id, def in pairs(Race.defs) do
        if def.kind == kind then out[#out + 1] = id end
    end
    table.sort(out, function(a, b)
        return ((Race.defs[a].name or a) < (Race.defs[b].name or b))
    end)
    return out
end

local function bodyName(charId)
    local def = Character.defs[charId]
    return (def and def.name) or charId
end

-- Tier first, then name: a page reads shallowest-first the way the rift is walked, and a body's tier
-- is the one number that says what meeting it costs.
local function bodyOrder(a, b)
    local da, db = Character.defs[a] or {}, Character.defs[b] or {}
    local ta, tb = da.tier or 99, db.tier or 99
    if ta ~= tb then return ta < tb end
    local na, nb = bodyName(a), bodyName(b)
    if na ~= nb then return na < nb end
    return a < b
end

local function bodyCatalogue()
    BODY_KINDS, BODIES, KIND_OF, HEADING, ANCHOR = {}, {}, {}, {}, {}
    for id, def in pairs(Character.defs) do
        -- A blueprint whose race the registry does not know still gets a page rather than vanishing,
        -- for the same reason an unknown item type does: a bucket nobody has taught this tool about
        -- is still content. tests/data_spec is what fails such a blueprint, not this.
        local kind = Race.kindOf(def.race) or "unknown"
        if not BODIES[kind] then BODIES[kind] = {}; BODY_KINDS[#BODY_KINDS + 1] = kind end
        BODIES[kind][#BODIES[kind] + 1] = id
        KIND_OF[id] = kind
    end
    table.sort(BODY_KINDS, function(a, b) return kindName(a) < kindName(b) end)
    for kind, list in pairs(BODIES) do
        table.sort(list, bodyOrder)
        -- TWO BODIES MAY LEGITIMATELY SHARE A DISPLAY NAME: a boss twin extends its companion and
        -- keeps her name (character_saber_bout is Saber, fought once and recruited once). Two sections
        -- titled `Saber` would read as a generator bug rather than as the twin it is, so a repeated
        -- name carries the blueprint id that tells them apart -- and only a repeated one, since the
        -- id is already printed under every heading and the other 171 do not need it twice.
        local count = {}
        for _, id in ipairs(list) do
            local nm = bodyName(id)
            count[nm] = (count[nm] or 0) + 1
        end
        for _, id in ipairs(list) do
            local nm = bodyName(id)
            HEADING[id] = (count[nm] > 1) and (nm .. " (`" .. id .. "`)") or nm
            ANCHOR[id] = anchorOf(HEADING[id])
        end
    end
end

-- A body, named and addressed. Falls back to the bare name for a blueprint the catalogue has not been
-- built for, which is what keeps a caller that runs before bodyCatalogue() honest rather than broken.
local function bodyLink(charId)
    local name = cell(bodyName(charId))
    local kind = KIND_OF[charId]
    if not kind or not ANCHOR[charId] then return name end
    return "[" .. name .. "](" .. bestiaryPageOf(kind) .. "#" .. ANCHOR[charId] .. ")"
end

-- THE RIFT'S FLOOR SECTIONS, titled in one place so that the page which writes them and the bestiary
-- which links at them cannot spell them differently. Read off the model in first-descent order, the
-- same order the rift page is laid out in (`Descent.INFERNO` -- once the Crown breaks the circles
-- shuffle, and the page says so).
local FLOOR_HEADS

local function floorHeads()
    if FLOOR_HEADS then return FLOOR_HEADS end
    FLOOR_HEADS = {}
    local run = Descent.new(nil, 1)
    for floor = 1, Descent.FLOORS do
        run.floor = floor
        local sin = Descent.sinAt(run, floor)
        FLOOR_HEADS[floor] = { sin = sin, circle = sin and sin.name or "The Hollow Crown" }
    end
    return FLOOR_HEADS
end

local function floorHeading(floor)
    return "Floor " .. floor .. " — " .. floorHeads()[floor].circle
end

local function floorLink(floor)
    return "[floor " .. floor .. "](The-Rift#" .. anchorOf(floorHeading(floor)) .. ")"
end

-- Which floors a circle holds, keyed by the ground it owns -- the unit the placement census reports a
-- body's reach in (`placed[id].biomes`). So "this thing stands in the forest" becomes "floors 3 and 4"
-- without a second table to go stale when a circle's depth moves.
local BIOME_FLOORS

local function biomeFloors()
    if BIOME_FLOORS then return BIOME_FLOORS end
    BIOME_FLOORS = {}
    for floor = 1, Descent.FLOORS do
        local sin = floorHeads()[floor].sin
        if sin and sin.biome then
            local row = BIOME_FLOORS[sin.biome]
            if not row then row = { sin = sin, floors = {} }; BIOME_FLOORS[sin.biome] = row end
            row.floors[#row.floors + 1] = floor
        end
    end
    return BIOME_FLOORS
end

-- ---------------------------------------------------------------------------
-- the cells of one item's row
-- ---------------------------------------------------------------------------

-- Name, what it does, and the id that addresses it. One cell rather than three columns because the
-- three are read as a unit and a row that splits them puts prose in the middle of a table of numbers.
--
-- `flavor` IS NOT ON IT, and that is a deliberate cut rather than an oversight. The line is authored
-- for the tooltip, where one item is being looked at and a sentence of voice is the reward for
-- stopping on it; in a table of forty rows it is forty sentences of voice between the reader and the
-- number they came for, and it triples the height of every row to say nothing a shelf decision turns
-- on. It stays on the blueprint and stays in the game. This page is the lookup, not the reading.
local function itemCell(def, id)
    local parts = { "**" .. cell(def.name or id) .. "**" }
    if def.description then parts[#parts + 1] = cell(def.description) end
    parts[#parts + 1] = "`" .. id .. "`"
    return table.concat(parts, "<br>")
end

-- Every magnitude the item carries, at forge 0 and fully forged. Read off Item.growth, so the pair is
-- the two ends of the ladder a player would actually pay for -- and a magnitude that does not move at
-- all prints once, which is the same distinction the Forge's own growth sheet draws.
local function statsCell(growth)
    if not growth then return "" end
    local parts = {}
    for _, s in ipairs(growth.stats) do
        local lo, hi = s.values[0], s.values[growth.maxLevel]
        parts[#parts + 1] = cell(s.label) .. " " .. tostring(lo) .. " → " .. tostring(hi)
    end
    for _, f in ipairs(growth.flat) do
        parts[#parts + 1] = cell(f.label) .. " " .. tostring(f.value)
    end
    return table.concat(parts, "<br>")
end

-- What it takes to use the thing: who it is aimed at, how far off you may stand, what it costs, how
-- long it takes, and what it tells the enemy first. Empty for a passive item, which is most armour
-- and a third of the utilities.
local function useCell(inst)
    local ab = inst.activeAbility
    if not ab then return "" end
    local bits = {}
    local target = Item.targetLabel(ab)
    if target then bits[#bits + 1] = cell(target) end
    -- A self-cast is handed exactly one legal cell, so a range there names nothing (Item.targetLabel's
    -- companion rule, kept by the tooltip too).
    if ab.range and ab.target ~= "self" then bits[#bits + 1] = "reach " .. tostring(ab.range) end
    if Item.aimsAtArea(ab) then
        local aoe = ab.aoe
        local shape = aoe.shape or (aoe.cells and "area") or "burst"
        local size = aoe.radius or aoe.length
        bits[#bits + 1] = cell(shape) .. (size and (" " .. tostring(size)) or "")
    end
    for _, c in ipairs(Item.costs(ab)) do
        bits[#bits + 1] = tostring(c.amount) .. " " .. cell(c.stat)
    end
    if ab.speed then bits[#bits + 1] = "speed " .. tostring(ab.speed) end
    local lo, hi = Item.windupRange(ab)
    if hi > 0 then
        bits[#bits + 1] = "wind-up " .. (lo == hi and tostring(lo) or (tostring(lo) .. "–" .. tostring(hi)))
    end
    return table.concat(bits, " · ")
end

-- The traits the item attaches to whoever carries it, named and described. Traits attach ONLY from
-- grid items, so this is the whole of where a trait comes from and the page can afford to spell each
-- one out rather than link away to a list.
local function traitsCell(def)
    if not def.traits then return "" end
    local parts = {}
    for _, tid in ipairs(def.traits) do
        local t = Trait.defs[tid]
        local name = (t and t.name) or tid
        local desc = t and t.description
        parts[#parts + 1] = "**" .. cell(name) .. "**" .. (desc and (" — " .. cell(desc)) or "")
    end
    return table.concat(parts, "<br>")
end

local function tagsCell(def)
    if not def.tags or #def.tags == 0 then return "" end
    local out = {}
    for i, t in ipairs(def.tags) do out[i] = "`" .. cell(t) .. "`" end
    return table.concat(out, " ")
end

local function hasTag(def, tag)
    for _, t in ipairs(def.tags or {}) do
        if t == tag then return true end
    end
    return false
end

-- WHERE ONE COMES FROM, which is the question `price` and `unlockLevel` answer between them. Only
-- abilities, consumables and a house's opening weapon carry a price at all; everything else is found
-- in the rift, and `unstocked` is the body's own trophy that no counter will deal OR buy back.
--
-- THE LAST THREE ARE THE PIECES THAT SIT ON NEITHER AXIS, and they were the whole of this column's
-- first draft being wrong: 46 items answered a bare dash, and every one of them was a real thing with
-- a real way in. A signature is a companion's bound relic and arrives with her; a reagent is brewed on
-- the field it is spent on (`ephemeral`); a creature's kit is never a player's at all. None has a
-- price or a tier BECAUSE none is dealt, which makes "no source field" a statement rather than a gap.
local function sourceCell(def)
    if def.price then return tostring(def.price) .. "g" end
    if def.unstocked then return "Rift only" end
    if def.unlockLevel then return "Found" end
    if hasTag(def, "signature") then return "Signature relic" end
    if def.ephemeral then return "Crafted in the field" end
    if def.class == "creature" then return "Monster kit" end
    return "—"
end

-- The body a player can go and kill for this piece.
--
-- `source` answers counter-or-rift; this answers WHICH BODY, which is the only form of that answer a
-- player can act on. Four routes reach the column differently:
--
--   drops    the body's authored list -- what it is KNOWN for, and the one route you can aim at
--   carried  the body is holding one, so you can take it off them. Real but incidental, and SAID SO,
--            because a reader who farms a body for its axe deserves to know it was never promised one
--   boss     a circle's lieutenant or general. Named as the body, with its position in the queue:
--            that list is walked unowned-first, so #7 is seven complete descents to that circle
--   band     the depth-banded draw, which is 302 of the 387 rift items. LEFT BLANK ON PURPOSE --
--            writing "random" 302 times would bury the 85 cells that name something, and the dash
--            already reads as "nothing is known for it" once the legend says so
--
-- A cell left empty is also a vote to drop the whole column (see renderTable), so a section where no
-- item comes off a named body prints no "Dropped by" column at all rather than a stripe of dashes.
local MAX_BODIES = 4

-- Whose list is it: the circle's general stands behind its guardian, the lieutenant two floors up.
local function bossBody(sin, which)
    local slot = (which == "general") and sin.guardian or sin.minor
    return slot and slot.lead or nil
end

local function dropCell(id)
    local row = DROPS[id]
    if not row then return "" end

    if row.route == "boss" then
        local q = row.boss
        for _, sin in ipairs(Descent.SINS) do
            if sin.id == q.sin then
                local body = bossBody(sin, q.which)
                local who = body and bodyLink(body) or cell(sin.name .. " " .. q.which)
                local rank = (q.which == "general") and "general" or "lieutenant"
                return "**" .. who .. "**<br>" .. cell(sin.name) .. " " .. rank
                    .. ", #" .. tostring(q.pos) .. " in the queue"
            end
        end
        return ""
    end

    if row.route ~= "drops" and row.route ~= "carried" then return "" end

    local names, carriedOnly = {}, 0
    for _, charId in ipairs(row.bodies) do
        local nm = bodyLink(charId)
        if row.byRoute[charId] == "carried" then
            nm = nm .. " *(carried)*"
            carriedOnly = carriedOnly + 1
        end
        names[#names + 1] = nm
    end
    if #names == 0 then return "" end

    local shown = names
    if #names > MAX_BODIES then
        shown = {}
        for i = 1, MAX_BODIES do shown[i] = names[i] end
        shown[#shown + 1] = "*+" .. tostring(#names - MAX_BODIES) .. " more*"
    end
    return table.concat(shown, "<br>")
end

-- Everything that changes what the piece IS rather than what its numbers are. Each of these is rare
-- enough that the column disappears on most tables and loud enough that it must not be a footnote on
-- the ones where it does not.
local function notesCell(def)
    local parts = {}
    if def.bound then parts[#parts + 1] = "bound to its bearer" end
    if def.noSteal then parts[#parts + 1] = "cannot be stolen" end
    if def.dropOnly then parts[#parts + 1] = "never in a starting kit" end
    if def.curse then parts[#parts + 1] = "born cursed (`" .. cell(def.curse) .. "`)" end
    if def.openingBoon then parts[#parts + 1] = "opens the fight with a boon" end
    if def.encounterCleared then parts[#parts + 1] = "acts between fights" end
    if def.statusImmunity then
        local names = {}
        for k in pairs(def.statusImmunity) do names[#names + 1] = k end
        table.sort(names)
        parts[#parts + 1] = "immune to " .. cell(table.concat(names, ", "))
    end
    if def.immune then
        local names = {}
        for _, k in ipairs(def.immune) do names[#names + 1] = k end
        table.sort(names)
        parts[#parts + 1] = "immune to " .. cell(table.concat(names, ", "))
    end
    if def.rules then
        local names = {}
        for _, k in ipairs(Item.RULE_NAMES) do
            if def.rules[k] ~= nil then names[#names + 1] = k end
        end
        if #names > 0 then parts[#parts + 1] = "rewrites a rule: " .. cell(table.concat(names, ", ")) end
    end
    return table.concat(parts, "<br>")
end

-- One item, as a map of column key to cell. Anything this returns empty is a vote to drop that column
-- from the section, so a cell must be "" and never a dash when the item simply has no such field.
local function rowOf(id)
    local def = Item.defs[id]
    local inst = Item.instantiate(id, 1, 0)
    return {
        item   = itemCell(def, id),
        stats  = statsCell(Item.growth(id)),
        use    = useCell(inst),
        traits = traitsCell(def),
        hands  = def.hands and tostring(def.hands) or "",
        stack  = (def.type == "consumable") and tostring(Item.maxStack(def)) or "",
        tags   = tagsCell(def),
        rank   = tostring(Spoils.depthOf(def)),
        source = sourceCell(def),
        drops  = dropCell(id),
        notes  = notesCell(def),
    }
end

-- ---------------------------------------------------------------------------
-- pages
-- ---------------------------------------------------------------------------

local function banner(line)
    return "<!-- GENERATED from data/ by `. wiki-gen` (tools/wiki_gen.lua)."
        .. " Edit the blueprint, not this page. " .. (line or "") .. " -->"
end

-- The markdown table for one type section, with the columns nobody filled left out.
local function renderTable(out, rows)
    local live = {}
    for _, col in ipairs(COLUMNS) do
        for _, row in ipairs(rows) do
            if row[col.key] and row[col.key] ~= "" then live[#live + 1] = col; break end
        end
    end
    local heads, seps = {}, {}
    for i, col in ipairs(live) do
        heads[i] = col.head
        seps[i] = col.align or "---"
    end
    out[#out + 1] = "| " .. table.concat(heads, " | ") .. " |"
    out[#out + 1] = "| " .. table.concat(seps, " | ") .. " |"
    for _, row in ipairs(rows) do
        local cells = {}
        for i, col in ipairs(live) do cells[i] = row[col.key] ~= "" and row[col.key] or "—" end
        out[#out + 1] = "| " .. table.concat(cells, " | ") .. " |"
    end
end

-- THE RANK BAND THE CATALOGUE ACTUALLY OCCUPIES, measured rather than quoted. The first cut of the
-- legend said "1-8" because that is Class.CLASS_LEVEL_CAP, and one item (a unlockLevel of 9) makes that
-- sentence false on a page that prints the 9. A ladder's ends are a property of what was authored onto
-- it, so they are read off the authored set every time the pages are built.
local RANK_LO, RANK_HI

local function rankSpan()
    if not RANK_LO then
        for _, def in pairs(Item.defs) do
            local r = Spoils.depthOf(def)
            RANK_LO = (RANK_LO == nil or r < RANK_LO) and r or RANK_LO
            RANK_HI = (RANK_HI == nil or r > RANK_HI) and r or RANK_HI
        end
    end
    return tostring(RANK_LO) .. "–" .. tostring(RANK_HI)
end

-- Gather the catalogue once: class id -> type id -> sorted list of item ids.
local function catalogue()
    local byClass, classIds = {}, {}
    for id, def in pairs(Item.defs) do
        local class = def.class or "unclassed"
        if not byClass[class] then byClass[class] = { types = {}, count = 0 }; classIds[#classIds + 1] = class end
        local bucket = byClass[class]
        local t = def.type or "other"
        bucket.types[t] = bucket.types[t] or {}
        local list = bucket.types[t]
        list[#list + 1] = id
        bucket.count = bucket.count + 1
    end
    table.sort(classIds, function(a, b)
        return (Class.displayName(a) or a) < (Class.displayName(b) or b)
    end)
    for _, class in pairs(byClass) do
        for _, list in pairs(class.types) do
            table.sort(list, function(a, b)
                local an, bn = Item.defs[a].name or a, Item.defs[b].name or b
                if an == bn then return a < b end
                return an < bn
            end)
        end
    end
    return byClass, classIds
end

-- The type sections a class actually has, in TYPES order, with anything unknown trailing.
local function typesOf(bucket)
    local order, seen = {}, {}
    for _, t in ipairs(TYPES) do
        if bucket.types[t.id] then order[#order + 1] = t; seen[t.id] = true end
    end
    local rest = {}
    for tid in pairs(bucket.types) do
        if not seen[tid] then rest[#rest + 1] = tid end
    end
    table.sort(rest)
    for _, tid in ipairs(rest) do
        order[#order + 1] = { id = tid, title = tid:sub(1, 1):upper() .. tid:sub(2) }
    end
    return order
end

-- WHAT A CLASS IS, in one line under its heading: a root holds from the first morning, an earned one
-- names the rungs it is bought with. Read off the blueprint (Class.parents / gateLevel) rather than
-- authored here, which is the whole point of the fold -- there is no second list to disagree.
local function classLine(classId)
    local parents = Class.parents(classId)
    if #parents == 0 then
        if not Class.isPlayable(classId) then return "Not a career — kit that belongs to no job." end
        return "A **root** class: every body holds it from the first morning."
    end
    local def = Class.defs[classId]
    local bits = {}
    for _, p in ipairs(parents) do
        local need = def and def.requires and def.requires[p]
        bits[#bits + 1] = (Class.displayName(p) or p) .. (need and (" " .. tostring(need)) or "")
    end
    local kind = #parents == 1 and "subclass" or "crossing"
    return "An **earned " .. kind .. "**, opened by " .. table.concat(bits, " and ") .. "."
end

local function classPage(classId, bucket)
    local name = Class.displayName(classId) or classId
    local out = {}
    local function line(s) out[#out + 1] = s or "" end

    line(banner("Class: " .. classId))
    line()
    line("# " .. name .. " items")
    line()
    line(classLine(classId))
    local desc = Class.description(classId)
    if desc then line(); line("> " .. desc) end
    line()

    local order = typesOf(bucket)
    local counts = {}
    for _, t in ipairs(order) do
        counts[#counts + 1] = "[" .. t.title .. "](#" .. t.title:lower() .. ") " .. #bucket.types[t.id]
    end
    line("**" .. bucket.count .. " items** — " .. table.concat(counts, " · "))
    line()
    line("Rank is the " .. rankSpan() .. " ladder a piece sits on: how deep in the rift it "
        .. "falls, or how far up the class it is sold. Stats read *forge 0 → fully forged*. "
        .. "**Dropped by** names the body you can go and take one off — follow it to that body's own "
        .. "entry for the rest of what it carries; blank means no body is known for it and it comes "
        .. "out of the rift's depth-banded draw instead. "
        .. "See [Items](Items) for the whole catalogue and [Bestiary](Bestiary) for the bodies.")
    line()

    for _, t in ipairs(order) do
        line("## " .. t.title)
        line()
        local rows = {}
        for _, id in ipairs(bucket.types[t.id]) do rows[#rows + 1] = rowOf(id) end
        renderTable(out, rows)
        line()
    end

    return table.concat(out, "\n")
end

local function indexPage(byClass, classIds)
    local out = {}
    local function line(s) out[#out + 1] = s or "" end

    local total = 0
    for _, b in pairs(byClass) do total = total + b.count end

    line(banner("Index."))
    line()
    line("# Items")
    line()
    line("Every one of the **" .. total .. " items** in the game, split by the class that owns it and "
        .. "then by what kind of thing it is.")
    line()
    line("A class is the **vendor shelf** a piece sits on and never an equip gate — anyone can carry "
        .. "anything. That is what lets a player build a bespoke class by mixing shelves.")
    line()
    line("**Rank** is the " .. rankSpan() .. " ladder every piece is placed on. A priced "
        .. "item is sold once the roster's best holder of its class has climbed that far; an unpriced "
        .. "one falls out of the rift at that depth. **Source** is `120g` for something a counter "
        .. "deals, *Found* for something the rift gives up, *Rift only* for a body's own trophy that "
        .. "is shown on the rack and never sold, and *Monster kit* for what is not a player's at all.")
    line()
    line("**Dropped by** answers the question *Source* cannot: which body actually hands the piece "
        .. "over, and **every name there is a link into the [Bestiary](Bestiary)** — to that body's "
        .. "stat block, the rest of its kit, and the floors it stands on. "
        .. "A name there is a body some encounter really seats, measured rather than read off "
        .. "the blueprints — an authored list on a body nothing ever fields is not a way in. A body "
        .. "marked *(carried)* is holding one rather than being known for it, and a circle's "
        .. "lieutenant or general names its place in a queue that is walked unowned-first, so *#7* is "
        .. "seven complete descents to that circle. **A blank is a real answer**: most of the "
        .. "catalogue comes off no particular body and falls out of the depth-banded draw, which is "
        .. "by design — not everything is meant to be farmable.")
    line()

    local groups = {
        { title = "Root classes", test = function(id) return Class.isRoot(id) and Class.isPlayable(id) end },
        { title = "Subclasses", test = function(id) return Class.arity(id) == 1 end },
        { title = "Crossings", test = function(id) return Class.arity(id) >= 2 end },
        { title = "Not a career", test = function(id) return not Class.isPlayable(id) end },
    }
    local placed = {}

    local function section(title, ids)
        if #ids == 0 then return end
        line("## " .. title)
        line()
        local heads = { "Class", "What it does" }
        for _, t in ipairs(TYPES) do heads[#heads + 1] = t.title end
        heads[#heads + 1] = "Total"
        line("| " .. table.concat(heads, " | ") .. " |")
        local seps = { "---", "---" }
        for _ = 1, #TYPES + 1 do seps[#seps + 1] = ":--:" end
        line("| " .. table.concat(seps, " | ") .. " |")
        for _, id in ipairs(ids) do
            local b = byClass[id]
            local cells = {
                "**[" .. cell(Class.displayName(id) or id) .. "](" .. pageOf(id) .. ")**",
                cell((Class.description(id) or ""):gsub("%..*$", ".")),
            }
            for _, t in ipairs(TYPES) do
                local n = b.types[t.id] and #b.types[t.id] or 0
                cells[#cells + 1] = n > 0 and tostring(n) or "—"
            end
            cells[#cells + 1] = "**" .. b.count .. "**"
            line("| " .. table.concat(cells, " | ") .. " |")
        end
        line()
    end

    for _, g in ipairs(groups) do
        local ids = {}
        for _, id in ipairs(classIds) do
            if not placed[id] and g.test(id) then ids[#ids + 1] = id; placed[id] = true end
        end
        section(g.title, ids)
    end

    local rest = {}
    for _, id in ipairs(classIds) do if not placed[id] then rest[#rest + 1] = id end end
    section("Unknown class", rest)

    return table.concat(out, "\n")
end

-- ---------------------------------------------------------------------------
-- The Rift: one page, fifteen floors
-- ---------------------------------------------------------------------------

-- WHAT THE LEVEL COLUMN IS, and why it is simulated rather than read off a constant.
--
-- There is no constant for "the level the company is expected to be on floor N". There are three that
-- look like one and none of them is it: `Descent.floorLevel` is the minimum a set-piece may be grown
-- to, `Descent.dangerLevel` is what the world is minted at, and the lagged reading under that is what
-- a trash body actually spawns at. The company's own ladder is a property of the experience curve, so
-- it is walked here the way the curve walks it -- a floor's worth of fights at the award
-- `Experience.rewardScale` pays against that floor's stock, which throttles once the company pulls
-- ahead and is the whole reason the two ladders track.
--
-- Simulated at the units tests/reward_scale_spec uses, so a re-cut of STEP, the award or the stack
-- moves this column without anybody editing it. That is the point of the page being generated: the
-- moment the curve changes, the design document is already right.
local FIGHTS_PER_FLOOR = 8

local function expectedLevels()
    local Descent = require("models.descent")
    local Experience = require("models.experience")
    local Growth = require("models.growth")
    local income = 7 * Experience.PER_ACTION + 1.25 * Experience.PER_FELLING
    local xp, out = Experience.totalFor(2), {}
    for floor = 1, Descent.FLOORS do
        local entry = Experience.levelFor(xp)
        local stock = Growth.combatantLevel({}, Descent.dangerLevel({ floor = floor }))
        for _ = 1, FIGHTS_PER_FLOOR do
            xp = xp + income * Experience.rewardScale(Experience.levelFor(xp), stock)
        end
        out[floor] = { entry, Experience.levelFor(xp) }
    end
    return out
end

-- "character_petal_drift" x6 -> "Petal Drift x6", in authored order and counted. The composition is
-- resolved through the same call the arena builds a fight from, so a blueprint that sizes its swarm
-- off the depth is printed at the size this floor will really field.
--
-- EVERY NAME IS A LINK to the body's own bestiary entry, which is what makes this page a way IN to the
-- catalogue rather than a wall of names: the reader is asking "what is standing on floor nine" and the
-- next question is always "and what is that". A body the catalogue has no page for -- which cannot
-- happen while it is built from Character.defs -- degrades to the bare name rather than a broken link.
local function compositionIds(def, ctx)
    local Arena = require("models.arena")
    local ok, ids = pcall(Arena.resolveComposition, def and def.composition, ctx)
    if not ok or type(ids) ~= "table" then return {} end
    return ids
end

local function compositionText(ids)
    if #ids == 0 then return "—" end
    local order, count = {}, {}
    for _, id in ipairs(ids) do
        if not count[id] then order[#order + 1] = id; count[id] = 0 end
        count[id] = count[id] + 1
    end
    local parts = {}
    for _, id in ipairs(order) do
        parts[#parts + 1] = bodyLink(id) .. (count[id] > 1 and (" ×" .. count[id]) or "")
    end
    return table.concat(parts, ", ")
end

local function compositionOf(def, ctx)
    return compositionText(compositionIds(def, ctx))
end

-- EVERY FLOOR, GATHERED ONCE -- and gathered OUTSIDE the page that prints it, because the bestiary
-- reads the same walk.
--
-- WHAT STANDS ON A STAIR IS NOT IN THE ENCOUNTER POOL. A guardian, her escort, a ward and the Crown
-- itself are seated by Descent directly (floorObjectives / stairPlan), so a body census taken from
-- encounters alone -- which is what the placement sweep in tools/drop_report is -- calls a circle's
-- general unfielded. That is not a bug there: the report models exactly this hole as its separate
-- `boss` route. This is that route MEASURED rather than re-derived from the blueprint's slots, and
-- measured by the same walk the rift page prints, so the two pages cannot seat different bodies on
-- the same stair.
local RIFT_FLOORS, STAIR

local function riftFloors()
    if RIFT_FLOORS then return RIFT_FLOORS, STAIR end

    local Encounter = require("models.encounter")
    local Biome = require("models.biome")

    local levels = expectedLevels()
    local run = Descent.new(nil, 1)

    local floors, stair = {}, {}
    local function post(charId, floor, role)
        local list = stair[charId]
        if not list then list = {}; stair[charId] = list end
        for _, e in ipairs(list) do
            if e.floor == floor then return end
        end
        list[#list + 1] = { floor = floor, role = role }
    end

    for floor = 1, Descent.FLOORS do
        run.floor = floor
        local quest = Descent.floorQuest(run)
        local sin = Descent.sinAt(run, floor)
        -- The pool this floor draws from, asked in the unit it gates on: how deep the floor is, and
        -- which of its circle's two floors it is (models/encounter.lua's `depth` and `rung`).
        local ctx = { depth = floor, rung = Descent.floorWithinCircle(floor),
            biome = quest.map.biome, quest = quest }
        local combat, elite = {}, {}
        for _, entry in ipairs(Descent.floorPool(ctx)) do
            local def = Encounter.get(entry.id)
            if def and (entry.kind == "combat" or entry.kind == "elite") then
                local row = {
                    name = def.name or entry.id,
                    bodies = compositionOf(def, ctx),
                    weight = entry.weight,
                }
                if entry.kind == "combat" then combat[#combat + 1] = row else elite[#elite + 1] = row end
            end
        end
        local function heavyFirst(a, b)
            if a.weight ~= b.weight then return a.weight > b.weight end
            return a.name < b.name
        end
        table.sort(combat, heavyFirst)
        table.sort(elite, heavyFirst)

        local gate = sin and Descent.gateFor(sin)
        local ward
        for _, spec in ipairs(quest.map.objectives or {}) do
            if spec.wardFor then
                local ids = compositionIds(spec, ctx)
                for _, id in ipairs(ids) do post(id, floor, "ward") end
                ward = { name = spec.name or "The ward", bodies = compositionText(ids) }
            end
        end

        local bossIds = compositionIds(quest.map.objective, ctx)
        for _, id in ipairs(bossIds) do post(id, floor, "stair") end

        floors[floor] = {
            circle = sin and sin.name or "The Hollow Crown",
            general = sin ~= nil and Descent.isGeneralFloor(floor),
            biome = quest.map.biome,
            place = Biome.get(quest.map.biome).name,
            levels = levels[floor],
            boss = quest.map.objective and quest.map.objective.name or "—",
            bossBodies = compositionText(bossIds),
            -- SLOTH'S OPEN STAIR AND THE CROWN'S ABSENCE ARE NOT THE SAME ANSWER. Acedia authors
            -- `none` -- she is asleep and the way down stands open, which is a reading of her sin and
            -- the one gate worth protecting in review. The bottom is not a circle and bars nothing
            -- because there is nothing below it to bar. Printing one word for both would retire a
            -- design decision into a formatting accident.
            gate = (function()
                if not sin then return "—" end
                -- A circle with no gate authored, and Acedia's `none`, are the same answer in the
                -- model and both arrive here with a nil label: Descent.GATES.none names none on
                -- purpose, because there is nothing for a plate to draw. The word is this page's
                -- business rather than the model's.
                local label = gate and (Descent.GATES[gate.kind] or {}).label
                return label or "the stair stands open"
            end)(),
            ward = ward,
            combat = combat,
            elite = elite,
        }
    end

    RIFT_FLOORS, STAIR = floors, stair
    return RIFT_FLOORS, STAIR
end

local function floorsPage()
    local out = {}
    local function line(s) out[#out + 1] = s or "" end

    local floors = riftFloors()

    line(banner("The descent: models/descent.lua + data/encounters/."))
    line()
    line("# The Rift")
    line()
    line("One rift of **" .. Descent.FLOORS .. " floors** under the city — seven circles of "
        .. Descent.FLOORS_PER_CIRCLE .. " and the Hollow Crown beneath them. A circle owns a stratum: "
        .. "every floor it holds is fought on its ground and pays into its house, and the **last** of "
        .. "them is where its general is standing. The floors above it are held by her honour guard, "
        .. "promoted.")
    line()
    line("Laid out in the order a **first descent** walks (`Descent.INFERNO`). Once the Crown is "
        .. "broken the circles are shuffled, so the grounds and the generals below move with them — "
        .. "the depths do not.")
    line()
    line("**Every body named below is a link** into the [Bestiary](Bestiary): its stat block, what it "
        .. "is carrying, and what it is known to drop.")
    line()
    line("## The stack")
    line()
    line("| Floor | Circle | Ground | Company | On the stair | The gate |")
    line("| :--: | --- | --- | :--: | --- | --- |")
    for floor = 1, Descent.FLOORS do
        local f = floors[floor]
        line("| **" .. floor .. "** | " .. cell(f.circle) .. (f.general and " — her floor" or "")
            .. " | " .. cell(f.place) .. " | " .. f.levels[1] .. "–" .. f.levels[2]
            .. " | " .. cell(f.boss) .. " | " .. cell(f.gate) .. " |")
    end
    line()

    local function fightTable(title, rows)
        line("**" .. title .. "**")
        line()
        if #rows == 0 then
            line("_Nothing is eligible here._")
            line()
            return
        end
        line("| Encounter | Who stands in it | Weight |")
        line("| --- | --- | :--: |")
        for _, row in ipairs(rows) do
            line("| " .. cell(row.name) .. " | " .. cell(row.bodies) .. " | " .. row.weight .. " |")
        end
        line()
    end

    for floor = 1, Descent.FLOORS do
        local f = floors[floor]
        line("## " .. floorHeading(floor))
        line()
        line("> **" .. f.place .. "** (`" .. f.biome .. "`) · company level **"
            .. f.levels[1] .. "–" .. f.levels[2] .. "** · gate: " .. f.gate)
        line()
        line("**Boss** — " .. cell(f.boss) .. ": " .. cell(f.bossBodies))
        line()
        if f.ward then
            line("**Ward** — " .. cell(f.ward.name) .. ": " .. cell(f.ward.bodies)
                .. ". The stair holds until it falls.")
            line()
        end
        fightTable("Ordinary", f.combat)
        fightTable("Elite", f.elite)
    end

    return table.concat(out, "\n")
end

-- ---------------------------------------------------------------------------
-- The Bestiary: every body, by kind
-- ---------------------------------------------------------------------------
--
-- THE OTHER HALF OF THE CATALOGUE. The item pages answer "what does this thing do"; these answer "what
-- is standing in front of me, and what will it leave on the floor" -- and the two questions are asked
-- in the same breath, which is why every name on an item page links here and every item named here
-- links back. A player reading the Knight's shelf for a coat can follow the body that drops it to what
-- else that body carries; a player reading the rift's ninth floor can follow a name to its stat block.
--
-- NOT A TABLE, and that is the one place these pages break the wiki's idiom on purpose. A markdown
-- table row cannot carry an anchor, and an anchor per body is the whole point -- it is what "vice
-- versa" means. Sections cost a little vertical space and buy an address for all 173 bodies.
--
-- PLACEMENT IS PRINTED, NOT ASSUMED. `Where` is read off the same sweep the drop column is (the
-- placement census in tools/drop_report), so a body no encounter ever seats says so in as many words
-- rather than sitting on the page looking like something you might meet. Most of the blueprints in the
-- tree are in exactly that state, and a bestiary that hid it would be a bestiary of things that are
-- not there.

-- The body's own line, in the game's own words for these quantities (models/meal.lua's STAT_LABEL is
-- the same vocabulary; lower-cased here because this is running prose and not a stat panel).
local BODY_STATS = {
    { key = "health",       label = "health" },
    { key = "mana",         label = "mana" },
    { key = "stamina",      label = "stamina" },
    { key = "staminaRegen", label = "stamina regen" },
    { key = "damage",       label = "damage" },
    { key = "magicDamage",  label = "magic damage" },
    { key = "defense",      label = "defense" },
    { key = "magicDefense", label = "magic defense" },
    { key = "movement",     label = "movement" },
    { key = "speed",        label = "speed" },
    { key = "skill",        label = "skill" },
    { key = "luck",         label = "luck" },
}

-- READ THROUGH Character.instantiate, for the same reason a weapon's damage is read through
-- Item.growth: the blueprint is not the last word on a stat. A body that declares neither accuracy
-- stat is handed the pair every combat formula will actually see (Character.ACCURACY_STATS), and a
-- resource is split into a pool whose max is the number that matters -- so this prints what the game
-- has, not what the file says.
local function statsLine(charId)
    local ok, char = pcall(Character.instantiate, charId)
    if not ok or type(char) ~= "table" or type(char.stats) ~= "table" then return nil end
    local parts = {}
    for _, s in ipairs(BODY_STATS) do
        local v = char.stats[s.key]
        if type(v) == "table" then v = v.max end
        if type(v) == "number" then parts[#parts + 1] = s.label .. " " .. tostring(v) end
    end
    if #parts == 0 then return nil end
    return table.concat(parts, " · ")
end

-- A NEGATIVE IS A WEAKNESS, which is the one thing about this line a reader has to be told once. The
-- innate hide is a redistribution across the damage types (docs/bestiary.md): a creature pays for
-- everything it shrugs off, so these lines very nearly sum to nothing and the sign is the whole
-- content of each entry.
local function hideLine(def)
    if type(def.resist) ~= "table" then return nil end
    local keys = {}
    for k in pairs(def.resist) do keys[#keys + 1] = k end
    table.sort(keys)
    local parts = {}
    for _, k in ipairs(keys) do
        local v = def.resist[k]
        parts[#parts + 1] = cell(k) .. " " .. (v < 0 and ("−" .. tostring(-v)) or ("+" .. tostring(v)))
    end
    if #parts == 0 then return nil end
    return table.concat(parts, " · ")
end

-- WHAT IS IN ITS NINE CELLS. `startingItems` is a POSITIONAL grid, so it carries `false` for an empty
-- cell and may carry a { id, count } stack -- both skipped over here rather than printed as holes.
--
-- The blueprint's `defaultAction` is marked HERE rather than given a line of its own: it is almost
-- always one of these same items, and a second line naming it again read as a second item on every
-- body that carries one thing. A default that is NOT in the grid (a natural weapon, usually) still
-- earns its own mention, which bodyNotes makes under `unarmed`.
local function kitLine(def)
    local parts = {}
    for _, entry in ipairs(def.startingItems or {}) do
        local id = entry
        if type(entry) == "table" then id = entry.id or entry[1] end
        if type(id) == "string" then
            parts[#parts + 1] = itemLink(id)
                .. (id == def.defaultAction and " *(opens with)*" or "")
        end
    end
    if #parts == 0 then return nil end
    return table.concat(parts, " · ")
end

-- Only when the grid does not already carry it -- see kitLine.
local function defaultActionLine(def)
    local id = def.defaultAction
    if type(id) ~= "string" then return nil end
    for _, entry in ipairs(def.startingItems or {}) do
        local held = entry
        if type(entry) == "table" then held = entry.id or entry[1] end
        if held == id then return nil end
    end
    return itemLink(id)
end

local function immuneLine(def)
    local names = {}
    for _, k in ipairs(def.immune or {}) do names[#names + 1] = cell(k) end
    for k in pairs(def.statusImmunity or {}) do names[#names + 1] = cell(k) end
    if #names == 0 then return nil end
    table.sort(names)
    return table.concat(names, ", ")
end

-- WHERE YOU MEET IT, in floors. The census reports a body's reach as the set of GROUNDS its encounters
-- pass on (plus a flag for the ones that gate on no ground at all), and a circle owns its ground -- so
-- the two resolve to a list of floors without a second table anybody has to keep.
--
-- In first-descent order, like the rift page it links into: once the Crown breaks the circles shuffle
-- and these depths move with them. The GROUND is the durable half of the answer.
local ROLE_WORD = { stair = "on the stair", ward = "warding the stair" }

local function whereLine(charId)
    local _, stair = riftFloors()
    local row = PLACED[charId]
    local posts = stair[charId]
    if not row and not posts then return nil end

    local parts = {}
    -- The stair first: a body that is seated there is the floor's reason to exist, and it is the one
    -- placement a reader can count on rather than roll for. Grouped by role, because a lieutenant who
    -- is also her general's escort holds the same post on both of a circle's floors and printing that
    -- as two clauses reads as two different jobs.
    local roles, byRole = {}, {}
    for _, post in ipairs(posts or {}) do
        local word = ROLE_WORD[post.role] or "on the stair"
        if not byRole[word] then byRole[word] = {}; roles[#roles + 1] = word end
        table.insert(byRole[word], floorLink(post.floor))
    end
    for _, word in ipairs(roles) do
        parts[#parts + 1] = "**" .. cell(word) .. "** at " .. table.concat(byRole[word], ", ")
    end

    local grounds, names = biomeFloors(), {}
    for biome in pairs((row or {}).biomes or {}) do names[#names + 1] = biome end
    table.sort(names)
    for _, biome in ipairs(names) do
        local g = grounds[biome]
        if g then
            local fl = {}
            for _, n in ipairs(g.floors) do fl[#fl + 1] = floorLink(n) end
            parts[#parts + 1] = "**" .. cell(g.sin.name) .. "** (" .. table.concat(fl, ", ") .. ")"
        else
            parts[#parts + 1] = "**" .. cell(biome) .. "**"
        end
    end
    if row and row.ungated then
        parts[#parts + 1] = "**any circle** — its encounters gate on no ground"
    end
    if #parts == 0 then return nil end
    return table.concat(parts, " · ")
end

-- Is this body reachable at all: seated by an encounter, or standing on a stair. The two halves are
-- the two routes tools/drop_report already splits `drops`/`carried` from `boss` on.
local function isFielded(charId)
    local _, stair = riftFloors()
    return PLACED[charId] ~= nil or stair[charId] ~= nil
end

local MAX_ENCOUNTERS = 8

local function standsInLine(charId)
    local Encounter = require("models.encounter")
    local row = PLACED[charId]
    if not row then return nil end
    local names = {}
    for _, encId in ipairs(row.encounters or {}) do
        local def = Encounter.get(encId)
        names[#names + 1] = cell((def and def.name) or encId)
    end
    if #names == 0 then return nil end
    table.sort(names)
    if #names > MAX_ENCOUNTERS then
        local shown = {}
        for i = 1, MAX_ENCOUNTERS do shown[i] = names[i] end
        shown[#shown + 1] = "*+" .. tostring(#names - MAX_ENCOUNTERS) .. " more*"
        names = shown
    end
    return table.concat(names, " · ")
end

-- Everything that changes what the BODY is rather than what its numbers are -- the sibling of the
-- item pages' Notes column, and rare enough per body that the line is absent on most of them.
local function bodyNotes(def)
    local parts = {}
    if def.boss then parts[#parts + 1] = "a **boss**: no execute lands on it and no Charm takes it" end
    if def.revivable == false then parts[#parts + 1] = "no downed window — it does not come back" end
    if def.scaling == false then
        parts[#parts + 1] = "**blueprint-exact**: it never grows with the company"
    end
    local fp = def.footprint
    if type(fp) == "table" and (fp.w or 1) * (fp.h or 1) > 1 then
        parts[#parts + 1] = "stands on " .. tostring(fp.w or 1) .. "×" .. tostring(fp.h or 1) .. " tiles"
    end
    if def.unarmed == false then
        parts[#parts + 1] = "no natural weapon at all: it cannot strike"
    elseif type(def.unarmed) == "string" then
        parts[#parts + 1] = "strikes bare with " .. itemLink(def.unarmed)
    end
    if type(def.personalGrowth) == "table" then
        local keys = {}
        for k in pairs(def.personalGrowth) do keys[#keys + 1] = k end
        table.sort(keys)
        local bits = {}
        for _, k in ipairs(keys) do
            bits[#bits + 1] = "+" .. tostring(def.personalGrowth[k]) .. " " .. cell(k)
        end
        parts[#parts + 1] = "keeps " .. table.concat(bits, ", ") .. " a level in any class"
    end
    if type(def.traits) == "table" then
        local bits = {}
        for _, tid in ipairs(def.traits) do
            local t = Trait.defs[tid]
            bits[#bits + 1] = cell((t and t.name) or tid)
        end
        if #bits > 0 then parts[#parts + 1] = "born with " .. table.concat(bits, ", ") end
    end
    if #parts == 0 then return nil end
    return table.concat(parts, " · ")
end

-- THE QUEUE A CIRCLE'S LIEUTENANT OR GENERAL PAYS OUT OF, and the reason it is printed as a numbered
-- list rather than a set. Descent.DROPS is walked unowned-first, so an entry's POSITION is a count of
-- complete descents to that circle -- the fourth thing on a general's list is the fourth time you have
-- come all the way down and beaten her. That is the one fact about a boss's loot a player can plan on.
local function bossQueues()
    local out = {}
    for _, sin in ipairs(Descent.SINS) do
        local set = Descent.DROPS[sin.id] or {}
        for _, which in ipairs({ "minor", "general" }) do
            local slot = (which == "general") and sin.guardian or sin.minor
            local lead = slot and slot.lead
            if lead and set[which] and #set[which] > 0 then
                out[lead] = out[lead] or {}
                out[lead][#out[lead] + 1] = { sin = sin, which = which, items = set[which] }
            end
        end
    end
    return out
end

local function bodySection(out, charId, queues)
    local def = Character.defs[charId]
    local function line(s) out[#out + 1] = s or "" end
    local function fact(label, value)
        if value then line("- **" .. label .. "** — " .. value) end
    end

    line("## " .. cell(HEADING[charId] or bodyName(charId)))
    line()

    local meta = { "`" .. charId .. "`" }
    -- The race, but only where it says something the page title has not: a Beast on the Beast page is
    -- a word doing no work, and a Naga on the Humanoid page is the whole reason the axis is a rollup.
    local race = Race.get(def.race)
    local raceWord = (race and race.name) or def.race
    if raceWord and raceWord ~= kindName(KIND_OF[charId] or "") then
        meta[#meta + 1] = cell(raceWord)
    end
    if def.tier then meta[#meta + 1] = "tier " .. tostring(def.tier) end
    if def.archetype then meta[#meta + 1] = cell(def.archetype) .. " posture" end
    if def.class then
        meta[#meta + 1] = "[" .. cell(Class.displayName(def.class) or def.class) .. "]("
            .. pageOf(def.class) .. ") shelf"
    end
    line(table.concat(meta, " · "))
    line()

    fact("Body", statsLine(charId))
    fact("Hide", hideLine(def))
    fact("Immune", immuneLine(def))
    fact("Carries", kitLine(def))
    fact("Opens with", defaultActionLine(def))
    local sig = {}
    if def.signatureWeapon then sig[#sig + 1] = itemLink(def.signatureWeapon) end
    if def.signatureAbility then sig[#sig + 1] = itemLink(def.signatureAbility) end
    fact("Signature", #sig > 0 and table.concat(sig, " · ") or nil)
    fact("Drops", itemLinks(def.drops))

    for _, q in ipairs(queues[charId] or {}) do
        local rank = (q.which == "general") and "general" or "lieutenant"
        local bits = {}
        for pos, itemId in ipairs(q.items) do
            bits[#bits + 1] = tostring(pos) .. ". " .. itemLink(itemId)
        end
        fact("As " .. cell(q.sin.name) .. "'s " .. rank .. ", in queue order",
            table.concat(bits, " · "))
    end

    local where = whereLine(charId)
    fact("Where", where)
    fact("Stands in", standsInLine(charId))
    if not where then
        -- SAY EXACTLY WHAT WAS MEASURED, which is the rift: an encounter that passes somewhere, or a
        -- floor's stair. A scripted scene can still seat a body outside both (the prologue's demons
        -- are hand-placed by data/tutorials/village.lua), so "nothing in the game fields it" would be
        -- a stronger claim than this page has any way to check.
        line("- **Where** — *the rift never fields it.* Nothing a floor can roll seats this body and "
            .. "no stair is held by it, so nothing it carries or is known for is reachable down there.")
    end
    fact("Notes", bodyNotes(def))
    line()
end

local function kindPage(kind)
    local out = {}
    local function line(s) out[#out + 1] = s or "" end

    local list = BODIES[kind]
    local queues = bossQueues()
    local fielded = 0
    for _, id in ipairs(list) do if isFielded(id) then fielded = fielded + 1 end end

    line(banner("Bestiary: kind " .. kind .. "."))
    line()
    line("# " .. kindName(kind))
    line()
    local races = racesOf(kind)
    for _, rid in ipairs(races) do
        local rdef = Race.defs[rid]
        line("> **" .. cell(rdef.name or rid) .. "** — " .. cell(rdef.description or "—"))
    end
    if #races > 0 then line() end
    line("**" .. #list .. " bodies**, " .. fielded .. " of them fielded by the rift. "
        .. "Shallowest tier first.")
    line()
    line("*Carries* is the nine-cell grid the body walks in with — take it off the corpse and it is "
        .. "yours. *Drops* is what it is **known** for, which is the list you can go and farm. *Where* "
        .. "is measured, not authored: a body is listed on a floor only if some encounter that floor "
        .. "draws from really seats it, or the floor seats it on its stair. Every item links to its "
        .. "shelf; see [The Rift](The-Rift) for the floors and [Items](Items) for the catalogue.")
    line()

    local jump = {}
    for _, id in ipairs(list) do
        jump[#jump + 1] = "[" .. cell(HEADING[id] or bodyName(id)) .. "](#" .. ANCHOR[id] .. ")"
    end
    line(table.concat(jump, " · "))
    line()

    for _, id in ipairs(list) do bodySection(out, id, queues) end

    return table.concat(out, "\n")
end

local function bestiaryIndexPage()
    local out = {}
    local function line(s) out[#out + 1] = s or "" end

    local total, fielded = 0, 0
    for _, kind in ipairs(BODY_KINDS) do
        for _, id in ipairs(BODIES[kind]) do
            total = total + 1
            if isFielded(id) then fielded = fielded + 1 end
        end
    end

    line(banner("Bestiary index."))
    line()
    line("# Bestiary")
    line()
    line("Every one of the **" .. total .. " bodies** in the game — what it is made of, what it is "
        .. "holding, what it leaves behind, and which floors it stands on.")
    line()
    line("Split by **kind** (`models/race.lua`), which is the coarse axis every rule in the bestiary "
        .. "reads: a race may be as fine as *wolf*, and it rolls up to *beast* here so a refinement "
        .. "never scatters a page.")
    line()
    line("**" .. fielded .. " of the " .. total .. " are fielded by the rift** — seated on a board "
        .. "by an encounter that really passes, or standing on a floor's stair. The rest say so on "
        .. "their own entry rather than being quietly left off: a name here is a thing you can meet, "
        .. "and the silence where there is none is an answer too.")
    line()
    line("*Drops* is what a body is **known** for and the only list you can aim at. *Carries* is its "
        .. "own kit, which the spoils draw can also hand over — real, but never promised. A circle's "
        .. "lieutenant and general pay out of a **queue** instead, walked unowned-first, so a "
        .. "position on that list is a count of complete descents to that circle.")
    line()

    line("| Kind | Races | What it is | Bodies | Fielded |")
    line("| --- | --- | --- | :--: | :--: |")
    for _, kind in ipairs(BODY_KINDS) do
        local list = BODIES[kind]
        local n = 0
        for _, id in ipairs(list) do if isFielded(id) then n = n + 1 end end
        local races, names, blurbs = racesOf(kind), {}, {}
        for _, rid in ipairs(races) do
            local rdef = Race.defs[rid]
            names[#names + 1] = cell(rdef.name or rid)
            blurbs[#blurbs + 1] = cell((rdef.description or ""):gsub("%..*$", "."))
        end
        line("| **[" .. cell(kindName(kind)) .. "](" .. bestiaryPageOf(kind) .. ")** | "
            .. table.concat(names, ", ") .. " | " .. table.concat(blurbs, "<br>") .. " | "
            .. #list .. " | " .. n .. " |")
    end
    line()

    return table.concat(out, "\n")
end

local function homePage(byClass, classIds)
    local out = {}
    local function line(s) out[#out + 1] = s or "" end

    local total = 0
    for _, b in pairs(byClass) do total = total + b.count end

    line(banner("Front page."))
    line()
    line("# Project Tactics")
    line()
    line("A 2D tactics game built with [LÖVE2D](https://love2d.org/) (Lua). Seven houses, seven deadly "
        .. "sins, and one rift of fifteen floors under the city.")
    line()
    line("This wiki is a **reference to the game's data**, generated straight out of the blueprints by "
        .. "`. wiki-gen`. Every number on it is read the way the game reads it, so it cannot drift from "
        .. "what the game does. Nothing here is hand-written and nothing here should be hand-edited — "
        .. "change the blueprint and regenerate.")
    line()
    line("The design documents — why the game is shaped this way — live in the repository's `docs/` "
        .. "folder, beside the code they argue about.")
    line()
    line("## Pages")
    line()
    local bodies = 0
    for _, kind in ipairs(BODY_KINDS) do bodies = bodies + #BODIES[kind] end

    line("- **[The Rift](The-Rift)** — the fifteen floors: ground, the level the company is expected "
        .. "to be, what walks there, and what is standing on each stair.")
    line("- **[Bestiary](Bestiary)** — all " .. bodies .. " bodies, by kind: what each one carries, "
        .. "what it drops, and which floors it stands on.")
    for _, kind in ipairs(BODY_KINDS) do
        line("  - [" .. kindName(kind) .. "](" .. bestiaryPageOf(kind) .. ") — " .. #BODIES[kind])
    end
    line("- **[Items](Items)** — all " .. total .. " items, by class and type.")
    for _, id in ipairs(classIds) do
        line("  - [" .. (Class.displayName(id) or id) .. "](" .. pageOf(id) .. ") — " .. byClass[id].count)
    end

    return table.concat(out, "\n")
end

local function sidebarPage(byClass, classIds)
    local out = {}
    local function line(s) out[#out + 1] = s or "" end
    line("### Project Tactics")
    line()
    line("- [Home](Home)")
    line("- [The Rift](The-Rift)")
    line("- [Bestiary](Bestiary)")
    for _, kind in ipairs(BODY_KINDS) do
        line("  - [" .. kindName(kind) .. "](" .. bestiaryPageOf(kind) .. ")")
    end
    line("- [Items](Items)")
    for _, id in ipairs(classIds) do
        line("  - [" .. (Class.displayName(id) or id) .. "](" .. pageOf(id) .. ")")
    end
    return table.concat(out, "\n")
end

-- ---------------------------------------------------------------------------
-- run
-- ---------------------------------------------------------------------------

local function write(dir, page, body)
    local rel = dir .. "/" .. page .. ".md"
    local file, err = io.open(projectPath(rel), "w")
    if not file then error("wiki-gen: cannot write " .. rel .. ": " .. tostring(err)) end
    file:write(body, "\n")
    file:close()
    return rel
end

-- EVERY PAGE, RENDERED AND NOT WRITTEN: an ordered list of { name, body }. Split out from the run so
-- a spec can hold the pages to their own promises without a filesystem -- 852 items appearing exactly
-- once between them, every class page reachable from the index, no row broken by an unescaped pipe.
-- Ordered rather than a map so the report below counts the same thing twice running.
function M.render()
    -- The placement sweep, once, before any page is built. Required here rather than at the top of the
    -- file so the cost lands only when pages are actually rendered, and so a headless caller that only
    -- wants the models never drags the encounter layer in behind them.
    DROPS, PLACED = require("tools.drop_report").sources()

    -- The address book BEFORE any page, because both directions of every cross-link are written by
    -- pages that render before the bestiary does: an item's "Dropped by" cell and the rift's
    -- composition rows both have to name the page and anchor a body will get.
    bodyCatalogue()

    local byClass, classIds = catalogue()
    local pages = {
        { name = "Home", body = homePage(byClass, classIds) },
        { name = "_Sidebar", body = sidebarPage(byClass, classIds) },
        { name = "Items", body = indexPage(byClass, classIds) },
        { name = "The-Rift", body = floorsPage() },
        { name = "Bestiary", body = bestiaryIndexPage() },
    }
    for _, id in ipairs(classIds) do
        pages[#pages + 1] = { name = pageOf(id), body = classPage(id, byClass[id]) }
    end
    for _, kind in ipairs(BODY_KINDS) do
        pages[#pages + 1] = { name = bestiaryPageOf(kind), body = kindPage(kind) }
    end
    return pages, byClass, classIds, BODY_KINDS, BODIES
end

function M.run(args)
    local dir = (args and args[1]) or OUT_DEFAULT
    os.execute(string.format('mkdir "%s" 2>nul', projectPath(dir):gsub("/", "\\")))

    local pages, byClass, classIds = M.render()
    for _, page in ipairs(pages) do write(dir, page.name, page.body) end

    local total = 0
    for _, b in pairs(byClass) do total = total + b.count end
    print(string.format("wiki-gen: %d pages, %d items, %d classes -> %s/", #pages, total, #classIds, dir))
end

return M
