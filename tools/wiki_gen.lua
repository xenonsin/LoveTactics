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

local M = {}

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

-- WHERE ONE COMES FROM, which is the question `price` and `dropTier` answer between them. Only
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
    if def.dropTier then return "Found" end
    if hasTag(def, "signature") then return "Signature relic" end
    if def.ephemeral then return "Crafted in the field" end
    if def.class == "creature" then return "Monster kit" end
    return "—"
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
-- legend said "1-8" because that is Class.CLASS_LEVEL_CAP, and one item (a dropTier of 9) makes that
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
        .. "See [Items](Items) for the whole catalogue.")
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
    local byClass, classIds = catalogue()
    local pages = {
        { name = "Home", body = homePage(byClass, classIds) },
        { name = "_Sidebar", body = sidebarPage(byClass, classIds) },
        { name = "Items", body = indexPage(byClass, classIds) },
    }
    for _, id in ipairs(classIds) do
        pages[#pages + 1] = { name = pageOf(id), body = classPage(id, byClass[id]) }
    end
    return pages, byClass, classIds
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
