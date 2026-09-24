-- The generated wiki (tools/wiki_gen.lua), held to the promises the pages make.
--
-- The wiki is the game's public reference now rather than a mirror of docs/, which means a defect
-- here is a defect a player reads. And every defect this kind of generator has is a SILENT one: an
-- item that lands in no bucket simply is not on any page, a name with a pipe in it shifts every cell
-- after it one column left, a class that grows its first item never gets a page. None of those raise,
-- none of them look wrong in a diff of 400KB, and all of them are one assertion each.
--
-- Renders in memory (M.render), so nothing here touches the filesystem or the wiki clone.

local Wiki = require("tools.wiki_gen")
local Item = require("models.item")
local Class = require("models.class")
local Character = require("models.character")

-- Render once: 852 items x 11 forge levels is the expensive half, and every case below asks the same
-- pages a different question.
local pages, byClass, classIds, bodyKinds, bodies = Wiki.render()

local byName = {}
for _, p in ipairs(pages) do byName[p.name] = p.body end

-- THE ANCHOR A HEADING GETS, implemented a SECOND time on purpose.
--
-- The generator derives every in-page link from the heading text it also titles the section with, so
-- asking it whether its own links match its own headings would be asking a rule to grade itself. This
-- is the same rule written out independently: lowercase, drop everything that is not alphanumeric, a
-- space, a hyphen or an underscore, then spaces to hyphens. If the two ever disagree the link case
-- below goes red, which is the only way this file can catch the generator's slug rule drifting.
local function slug(heading)
    local s = tostring(heading):lower()
    s = s:gsub("[^%w%s%-_]", "")
    s = s:gsub("%s", "-")
    return s
end

-- Every anchor a page offers, with the renderer's duplicate rule applied to the headings.
--
-- TWO KINDS, because the pages carry two kinds. A heading is addressed by the slug of its own text,
-- which is the rule written out above. An item's ROW is addressed by an empty <a> the renderer writes
-- into the row's name cell -- markdown gives a table row no anchor of its own, so an item link would
-- otherwise have to settle for the section heading above the table and drop the reader at the top of
-- it.
--
-- READ BACK OUT OF THE RENDERED TEXT, exactly like the heading rule beside it: this scrapes the <a>
-- tags the page actually contains rather than asking the generator which anchors it meant to write.
-- An item link pointing at a row whose anchor was never printed is then a red case here, which is the
-- whole reason this file re-derives anything at all.
local function anchorsOf(body)
    local out, seen = {}, {}
    for line in (body .. "\n"):gmatch("([^\n]*)\n") do
        local heading = line:match("^#+%s+(.-)%s*$")
        if heading then
            local base = slug(heading)
            local n = seen[base]
            seen[base] = (n or 0) + 1
            out[n and (base .. "-" .. tostring(n)) or base] = true
        end
        for id in line:gmatch('<a%s+name="([^"]+)"') do out[id] = true end
    end
    return out
end

-- The bestiary's sections, split back out of the rendered pages: charId -> { page, heading, body }.
-- Parsed rather than asked of the generator, for the same reason the drop column is parsed back out
-- of its tables -- what a reader gets is the rendered page, not the table it was built from.
local function bestiarySections()
    local out = {}
    for _, page in ipairs(pages) do
        if page.name:match("^Bestiary%-") then
            local heading, id, buf
            local function flush()
                if id then out[id] = { page = page.name, heading = heading, body = table.concat(buf, "\n") } end
            end
            for line in (page.body .. "\n"):gmatch("([^\n]*)\n") do
                local h = line:match("^## (.-)%s*$")
                if h then
                    flush()
                    heading, id, buf = h, nil, {}
                elseif buf then
                    if not id then id = line:match("^`(character_[a-z_0-9]+)`") end
                    buf[#buf + 1] = line
                end
            end
            flush()
        end
    end
    return out
end

local sections = bestiarySections()

-- The Statuses page, split back into its entries: statusId -> the text from its <a> to the next one.
local function statusSections()
    local out, id, buf = {}, nil, nil
    local function flush() if id then out[id] = table.concat(buf, "\n") end end
    for line in ((byName["Statuses"] or "") .. "\n"):gmatch("([^\n]*)\n") do
        local sid = line:match('^<a name="(status_[%w_]+)"')
        if sid then flush(); id, buf = sid, {} elseif buf then buf[#buf + 1] = line end
    end
    flush()
    return out
end

-- An item's own table row, found by the anchor its name cell carries.
local function itemRow(itemId)
    local def = Item.defs[itemId]
    local page = byName["Items-" .. tostring(def.class or "unclassed"):gsub("_(%a)", function(c)
        return "-" .. c:upper() end):gsub("^%a", string.upper)]
    if not page then return nil end
    return page:match('[^\n]*<a name="' .. itemId .. '"[^\n]*')
end

-- Every `id` fenced in backticks, across every page. The item cell prints the blueprint id as the
-- row's last line, which is what makes a row addressable at all.
local function fencedIds(body)
    local out = {}
    for id in body:gmatch("`([a-z_]+)`") do out[#out + 1] = id end
    return out
end

return {
    {
        name = "every item in the game appears on exactly one class page",
        fn = function()
            local seen = {}
            for _, page in ipairs(pages) do
                if page.name:match("^Items%-") then
                    for _, id in ipairs(fencedIds(page.body)) do
                        if Item.defs[id] then
                            assert(not seen[id], id .. " is printed on two class pages")
                            seen[id] = page.name
                        end
                    end
                end
            end
            local missing = {}
            for id in pairs(Item.defs) do
                if not seen[id] then missing[#missing + 1] = id end
            end
            table.sort(missing)
            assert(#missing == 0, #missing .. " items reach no page, e.g. " .. tostring(missing[1]))
        end,
    },
    {
        -- The bug this is really about: a class whose first item is authored gets no page unless the
        -- catalogue drives the page list. It does -- but the index and the sidebar are built from the
        -- same walk, so this also pins that nothing is listed that was never written.
        name = "every class that owns an item has a page, and every page is linked",
        fn = function()
            for _, id in ipairs(classIds) do
                local page = "Items-" .. (id:gsub("_", "-"):gsub("(%a)([%w]*)", function(a, b)
                    return a:upper() .. b
                end))
                assert(byName[page], "no page for class " .. id .. " (expected " .. page .. ")")
                assert(byName.Items:find("(" .. page .. ")", 1, true),
                    page .. " is not linked from the Items index")
                assert(byName._Sidebar:find("(" .. page .. ")", 1, true),
                    page .. " is not linked from the sidebar")
            end
            for _, p in ipairs(pages) do
                if p.name:match("^Items%-") then
                    local class = p.name:gsub("^Items%-", ""):gsub("%-", "_"):lower()
                    assert(byClass[class], p.name .. " is a page for a class that owns nothing")
                end
            end
        end,
    },
    {
        -- A pipe inside a name, a description or a flavor line ends the cell it is in and shifts every
        -- column after it. It is escaped once, in cell() -- and the only way to know it stayed escaped
        -- is to count the columns of every row against its own header.
        name = "no table row is broken by an unescaped pipe",
        fn = function()
            local function columns(line)
                -- Count the separators that are NOT escaped: a `\|` is content.
                local n = 0
                for i = 1, #line do
                    if line:sub(i, i) == "|" and line:sub(i - 1, i - 1) ~= "\\" then n = n + 1 end
                end
                return n
            end
            local checked = 0
            for _, page in ipairs(pages) do
                local width
                for line in (page.body .. "\n"):gmatch("([^\n]*)\n") do
                    if line:sub(1, 1) == "|" then
                        local n = columns(line)
                        if not width then
                            width = n
                        else
                            assert(n == width, page.name .. ": a row has " .. n
                                .. " columns where its table has " .. width .. " -- " .. line:sub(1, 90))
                            checked = checked + 1
                        end
                    else
                        width = nil -- a blank line or a heading ends the table
                    end
                end
            end
            assert(checked > 800, "expected to walk the whole catalogue's rows, walked " .. checked)
        end,
    },
    {
        -- Item.growth resolves a magnitude by baking a real instance at each forge level, so a Stats
        -- cell is the only number on the page that could silently become a transcription. If an item
        -- with a known curve stops printing both ends of it, the generator has started reading the
        -- blueprint instead of the model.
        name = "a forged magnitude prints both ends of its ladder",
        fn = function()
            local page = byName["Items-Knight"]
            assert(page, "the Knight page exists")
            local growth = Item.growth("weapon_iron_sword")
            local stat = growth.stats[1]
            assert(stat, "the iron sword grows on something")
            local want = stat.label .. " " .. stat.values[0] .. " → " .. stat.values[growth.maxLevel]
            assert(page:find(want, 1, true), "expected the iron sword's ladder to read '" .. want .. "'")
        end,
    },
    {
        -- The legend quotes a band, and a quoted band is a second statement of something the data
        -- already says. It is measured off the catalogue, so this only has to check it was not
        -- replaced by a constant again (it was Class.CLASS_LEVEL_CAP once, and one unlockLevel of 9
        -- made that sentence false on a page that printed the 9).
        name = "the rank legend names the band the catalogue actually occupies",
        fn = function()
            local Spoils = require("models.spoils")
            local lo, hi
            for _, def in pairs(Item.defs) do
                local r = Spoils.depthOf(def)
                lo = (lo == nil or r < lo) and r or lo
                hi = (hi == nil or r > hi) and r or hi
            end
            local band = lo .. "–" .. hi
            assert(byName.Items:find(band, 1, true), "the index should quote the band " .. band)
            assert(byName["Items-Knight"]:find(band, 1, true), "a class page should quote it too")
        end,
    },
    {
        -- Nothing on the wiki is a design document. The purge is the point: if a page ever starts
        -- carrying prose that is not read out of a blueprint, it is being hand-written again.
        name = "every page says it is generated",
        fn = function()
            for _, page in ipairs(pages) do
                if page.name ~= "_Sidebar" then
                    local first = page.body:sub(1, 200)
                    assert(first:find("GENERATED from data/", 1, true),
                        page.name .. " must open with the generated banner")
                end
            end
        end,
    },
    {
        -- Class.roots() is seven; the creature bucket is the eighth root and is not a career. The
        -- index groups on exactly that distinction, so a class that stopped being playable would
        -- move sections rather than disappear.
        name = "the index groups the catalogue by where a class sits on the ladder",
        fn = function()
            local index = byName.Items
            assert(index:find("## Root classes", 1, true), "roots have a section")
            assert(index:find("## Subclasses", 1, true), "subclasses have a section")
            assert(index:find("## Crossings", 1, true), "crossings have a section")
            assert(index:find("## Not a career", 1, true), "the creature bucket has a section")
            local roots = 0
            for id in pairs(Class.roots()) do
                if byClass[id] then roots = roots + 1 end
            end
            assert(roots == 7, "seven playable roots own items, counted " .. roots)
        end,
    },
    {
        -- THE RIFT PAGE IS A DESIGN DOCUMENT THAT CANNOT GO STALE, which is only true while every
        -- figure on it is still read out of the model. These are the claims it makes that a change
        -- elsewhere could quietly falsify: a row per floor in order, a section per floor, a boss named
        -- on each, and a company level band that never goes backwards.
        name = "the rift page carries every floor, its boss and a climbing level band",
        fn = function()
            local Descent = require("models.descent")
            local page = byName["The-Rift"]
            assert(page, "the rift page exists")

            local rows, last = 0, 0
            for line in (page .. "\n"):gmatch("([^\n]*)\n") do
                local floor, lo, hi = line:match("^| %*%*(%d+)%*%* |.* | (%d+)–(%d+) |")
                if floor then
                    rows = rows + 1
                    assert(tonumber(floor) == rows, "the stack is out of order at row " .. rows)
                    assert(tonumber(lo) >= last,
                        "the company level band goes backwards on floor " .. floor)
                    assert(tonumber(hi) >= tonumber(lo),
                        "floor " .. floor .. " ends below where it starts")
                    last = tonumber(lo)
                end
            end
            assert(rows == Descent.FLOORS,
                "the stack lists " .. rows .. " floors against " .. Descent.FLOORS)

            for floor = 1, Descent.FLOORS do
                assert(page:find("## Floor " .. floor .. " —", 1, true),
                    "floor " .. floor .. " has no section")
            end
            local _, bosses = page:gsub("%*%*Boss%*%* —", "")
            assert(bosses == Descent.FLOORS,
                "every floor names what is on its stair; found " .. bosses)

            -- The bottom is not a circle and bars nothing; Acedia's stair is open on purpose. Two
            -- different facts, and the page must not print one word for both.
            assert(page:find("the stair stands open", 1, true), "Sloth's open stair is named as one")
        end,
    },

    {
        -- WHAT THIS GUARDS IS THE COLUMN BEING TRUE, not the column existing. "Dropped by" is read by
        -- a player deciding what to go and kill, so a name in it is a promise; and the failure mode of
        -- a generated column is silence -- it renders a tidy dash and nobody can tell whether that
        -- means "nothing drops it" or "the lookup broke". So the cells are PARSED back out of the
        -- rendered tables and checked against the same measurement that filled them, in both
        -- directions: every body-backed item names its body, and everything else names nobody.
        name = "a found item names the body that hands it over, and only when one does",
        fn = function()
            local Drops = require("tools.drop_report")
            local Character = require("models.character")
            local Descent = require("models.descent")
            local index = Drops.sources()

            -- Split a rendered row into cells. `cell()` escapes an authored pipe as \| , so those are
            -- parked before the split and restored after -- otherwise a name with a pipe in it would
            -- silently shift every assertion one column left, which is the exact bug the sibling case
            -- about unescaped pipes exists to catch.
            local function cells(line)
                local out = {}
                for part in (line:gsub("\\|", "\1")):gmatch("[^|]+") do
                    out[#out + 1] = (part:gsub("\1", "|"):gsub("^%s+", ""):gsub("%s+$", ""))
                end
                return out
            end

            -- Walk every table on every class page and hand back id -> the row's "Dropped by" cell.
            -- The column set differs per table (an empty column is dropped), so the header is re-read
            -- at the top of each one rather than assumed.
            local found = {}
            for _, page in ipairs(pages) do
                if page.name:match("^Items%-") then
                    local dropIdx = nil
                    for line in (page.body .. "\n"):gmatch("([^\n]*)\n") do
                        if line:match("^| Item |") then
                            dropIdx = nil
                            for i, head in ipairs(cells(line)) do
                                if head == "Dropped by" then dropIdx = i end
                            end
                        elseif line:match("^| %-%-%-") then -- separator
                        elseif line:match("^| ") then
                            local row = cells(line)
                            local id = row[1] and row[1]:match("`([a-z_]+)`")
                            if id and Item.defs[id] then
                                local c = dropIdx and row[dropIdx] or "—"
                                found[id] = (c == "—") and "" or c
                            end
                        else
                            dropIdx = nil
                        end
                    end
                end
            end

            -- Which body the boss route is expected to name: the circle's general stands behind its
            -- guardian, its lieutenant two floors up.
            local function bossName(q)
                for _, sin in ipairs(Descent.SINS) do
                    if sin.id == q.sin then
                        local slot = (q.which == "general") and sin.guardian or sin.minor
                        local def = slot and slot.lead and Character.defs[slot.lead]
                        return def and def.name or nil
                    end
                end
                return nil
            end

            local named, blank = 0, 0
            for id, row in pairs(index) do
                local printed = found[id]
                if printed then -- an item the pages actually carry
                    local body = row.route == "drops" or row.route == "carried"
                    if body or row.route == "boss" then
                        named = named + 1
                        assert(printed ~= "",
                            id .. " is reached by route '" .. row.route
                            .. "' but its Dropped by cell is empty")
                        local want
                        if body then
                            local def = Character.defs[row.bodies[1]]
                            want = def and def.name or row.bodies[1]
                        else
                            want = bossName(row.boss)
                        end
                        assert(want and printed:find(want, 1, true),
                            id .. " should name " .. tostring(want)
                            .. " but its cell reads '" .. printed .. "'")
                        if row.route == "carried" then
                            assert(printed:find("(carried)", 1, true),
                                id .. " is only carried, never authored, and must say so")
                        end
                    else
                        blank = blank + 1
                        assert(printed == "",
                            id .. " comes off no named body (route '" .. row.route
                            .. "') yet its cell claims '" .. printed .. "'")
                    end
                end
            end

            -- The measurement is worth nothing if it graded an empty set -- the failure this whole case
            -- is built against is the lookup returning nothing and every cell going quietly blank.
            assert(named > 0, "no item on any page names a body; the drop index reached no rows")
            assert(blank > 0, "nothing came off the band; the index is not being read")
        end,
    },

    {
        -- THE BESTIARY'S OWN COMPLETENESS, the sibling of the items case at the top of this file and
        -- the same silent failure: a body whose race the registry does not know lands in no bucket
        -- and simply is not on any page. Nothing raises, nothing looks wrong, and a name the rift
        -- page links at points at a heading that was never written.
        name = "every body in the game has exactly one bestiary entry",
        fn = function()
            local onDisk, entries = 0, 0
            for id in pairs(Character.defs) do
                onDisk = onDisk + 1
                assert(sections[id], id .. " has no section on any bestiary page")
            end
            for _ in pairs(sections) do entries = entries + 1 end
            assert(entries == onDisk,
                entries .. " bestiary entries against " .. onDisk .. " blueprints")

            -- And the pages agree with the catalogue that drove them: every kind has a page, every
            -- page is reachable from the index, the sidebar and the front page.
            local counted = 0
            for _, kind in ipairs(bodyKinds) do
                local page = "Bestiary-" .. kind:sub(1, 1):upper() .. kind:sub(2)
                assert(byName[page], "no page for kind " .. kind .. " (expected " .. page .. ")")
                for _, host in ipairs({ "Bestiary", "_Sidebar", "Home" }) do
                    assert(byName[host]:find("(" .. page .. ")", 1, true),
                        page .. " is not linked from " .. host)
                end
                counted = counted + #bodies[kind]
            end
            assert(counted == onDisk, "the kind buckets hold " .. counted .. " of " .. onDisk)
        end,
    },

    {
        -- EVERY LINK THIS WIKI WRITES, WALKED. The pages cross-reference in three directions now --
        -- an item's drop cell into the bestiary, a body's kit back into the shelves, the rift's
        -- compositions into both -- and all three are built from ids rather than typed, which means
        -- the failure mode is not a typo but a RENAME: a body that moves kind, a class that stops
        -- owning an item, a heading whose wording changes. A dead wiki link raises nothing and looks
        -- like a link.
        name = "no page links at a page or an anchor that does not exist",
        fn = function()
            local anchors = {}
            for _, page in ipairs(pages) do anchors[page.name] = anchorsOf(page.body) end

            local walked = 0
            for _, page in ipairs(pages) do
                for target in page.body:gmatch("%]%(([^%)]+)%)") do
                    if not target:match("^https?:") then
                        walked = walked + 1
                        local where, anchor = target:match("^([^#]*)#?(.*)$")
                        local host = (where ~= "" and where) or page.name
                        assert(anchors[host], page.name .. " links at a page that does not exist: "
                            .. target)
                        if anchor ~= "" then
                            assert(anchors[host][anchor], page.name .. " links at " .. target
                                .. ", but " .. host .. " has no such heading")
                        end
                    end
                end
            end
            -- A floor under a four-figure count, not a fence around the current one: what this
            -- guards is the walk reaching the pages at all, and a spec that reddens because a class
            -- was retired would be measuring the catalogue's size instead.
            assert(walked > 1000, "expected to walk the wiki's cross-links, walked " .. walked)
        end,
    },

    {
        -- WHAT A BODY IS HOLDING AND WHAT IT LEAVES, round-tripped. The generator writes these as
        -- links built off the item's own `class` and `type`, so the two ways they go wrong are a link
        -- to the wrong shelf and an item quietly dropped out of the list -- and the second is the one
        -- that looks fine. So each authored id is required to appear as a named link on the body's
        -- section AND the page it points at is required to actually carry that id.
        name = "a body's kit and drop list reach the pages those items are really on",
        fn = function()
            local checked = 0
            for charId, def in pairs(Character.defs) do
                local section = sections[charId]
                local want = {}
                for _, entry in ipairs(def.startingItems or {}) do
                    local id = type(entry) == "table" and (entry.id or entry[1]) or entry
                    if type(id) == "string" then want[id] = true end
                end
                for _, id in ipairs(def.drops or {}) do want[id] = true end

                for id in pairs(want) do
                    local itemDef = Item.defs[id]
                    assert(itemDef, charId .. " names an item that does not exist: " .. id)
                    local name = (itemDef.name or id):gsub("|", "\\|")
                    local link = section.body:match("%[" .. name:gsub("%p", "%%%0")
                        .. "%]%(([^%)#]+)")
                    assert(link, charId .. "'s entry never names " .. id
                        .. " (" .. tostring(itemDef.name) .. ")")
                    assert(byName[link], charId .. " links " .. id .. " at " .. link
                        .. ", which is not a page")
                    assert(byName[link]:find("`" .. id .. "`", 1, true),
                        charId .. " links " .. id .. " at " .. link .. ", which does not carry it")
                    checked = checked + 1
                end
            end
            assert(checked > 300, "expected to walk the bodies' kits and lists, walked " .. checked)
        end,
    },

    {
        -- THE RIFT IS THE WAY IN TO THE BESTIARY, which is the whole reason its compositions are
        -- links: a reader asking what stands on floor nine asks what those things ARE in the same
        -- breath. Every floor seats something, so a floor section with no link into the bestiary
        -- means the composition resolver has started handing back bare names again.
        name = "every floor of the rift links the bodies standing on it",
        fn = function()
            local Descent = require("models.descent")
            local page = byName["The-Rift"]
            local section, floors = nil, 0
            local function close()
                if section then
                    floors = floors + 1
                    assert(section.body:find("](Bestiary-", 1, true),
                        "floor " .. section.floor .. " names no body the bestiary carries")
                end
            end
            for line in (page .. "\n"):gmatch("([^\n]*)\n") do
                local floor = line:match("^## Floor (%d+)")
                if floor then
                    close()
                    section = { floor = floor, body = "" }
                elseif section then
                    section.body = section.body .. line .. "\n"
                end
            end
            close()
            assert(floors == Descent.FLOORS,
                "walked " .. floors .. " floor sections against " .. Descent.FLOORS)
        end,
    },

    {
        -- EVERY STATUS HAS AN ENTRY, the same silent failure as an item landing in no bucket: an id
        -- with no <a> is a status every item cell links at and no page carries.
        name = "every status in the game has exactly one entry on the Statuses page",
        fn = function()
            local Status = require("models.status")
            local entries = statusSections()
            local onDisk, count = 0, 0
            for sid, def in pairs(Status.defs) do
                onDisk = onDisk + 1
                assert(entries[sid], sid .. " has no entry on the Statuses page")
                assert(entries[sid]:find("### " .. (def.name or sid):gsub("|", "\\|"), 1, true),
                    sid .. "'s entry is not titled " .. tostring(def.name))
            end
            for _ in pairs(entries) do count = count + 1 end
            assert(count == onDisk, count .. " status entries against " .. onDisk .. " blueprints")
            for _, host in ipairs({ "_Sidebar", "Home" }) do
                assert(byName[host]:find("(Statuses)", 1, true), "Statuses is not linked from " .. host)
            end
        end,
    },

    {
        -- BOTH DIRECTIONS, checked against the FIELDS rather than the source scan the generator uses,
        -- so the scan cannot grade itself: a piece that `inflicts` a status, opens the fight in one or
        -- wards one must link it from its own row, and that status's entry must link the piece back.
        name = "an item that inflicts, opens with or wards a status links it, and is linked back",
        fn = function()
            local Status = require("models.status")
            local entries = statusSections()
            local checked = 0
            for itemId, def in pairs(Item.defs) do
                local named = {}
                local ab = def.activeAbility
                if type(ab) == "table" and type(ab.inflicts) == "table"
                    and type(ab.inflicts.id) == "string" then
                    named[ab.inflicts.id] = true
                end
                if type(def.openingBoon) == "table" and type(def.openingBoon.id) == "string" then
                    named[def.openingBoon.id] = true
                end
                for _, sid in ipairs(def.statusImmunity or {}) do named[sid] = true end
                for sid in pairs(named) do
                    if Status.defs[sid] then
                        local row = itemRow(itemId)
                        assert(row, itemId .. " has no row to link " .. sid .. " from")
                        assert(row:find("(Statuses#" .. sid .. ")", 1, true),
                            itemId .. "'s row does not link " .. sid)
                        assert(entries[sid]:find("#" .. itemId .. ")", 1, true),
                            sid .. "'s entry does not link back to " .. itemId)
                        checked = checked + 1
                    end
                end
            end
            -- Most of the catalogue lands its statuses inside an effect function, which only the
            -- generator's source scan reads; the fields are the ~20 a spec can check from outside.
            assert(checked >= 15, "expected to walk the items' statuses, walked " .. checked)
        end,
    },
}
