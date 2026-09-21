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

-- Render once: 852 items x 11 forge levels is the expensive half, and every case below asks the same
-- pages a different question.
local pages, byClass, classIds = Wiki.render()

local byName = {}
for _, p in ipairs(pages) do byName[p.name] = p.body end

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
        -- replaced by a constant again (it was Class.CLASS_LEVEL_CAP once, and one dropTier of 9
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
}
