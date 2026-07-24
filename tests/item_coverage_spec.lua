-- A ratchet on BESPOKE item test coverage.
--
-- Read this alongside tests/item_contract_spec.lua, which is the other half and the more important
-- one: that file sweeps all 515 items and asserts the universal contract (they build at every forge
-- level, they never lie in a preview, they never corrupt the board when fired, their costs are
-- enforced). So no item is unverified -- every one of them has a floor.
--
-- What this file counts is the items that have a case of their OWN, saying what that particular item
-- is for. The sweep can prove Second Wind does not crash; only a bespoke test can prove it rises at
-- half health. Writing 316 of those at once is not realistic, but letting the gap GROW is a choice,
-- and this is the file that stops it: a new item must be named by some spec, or the build goes red
-- with the item's own id. The backlog is grandfathered in tests/support/untested_items.lua and can
-- only shrink.
--
-- WHAT "COVERED" MEANS HERE, precisely, because the limits matter:
--
--   An item counts as covered when its blueprint id appears as a quoted string in any tests/*.lua
--   file. That is a proxy, and a weak one -- naming an item in a fixture is not the same as
--   asserting anything about it. What this spec actually guarantees is that somebody OPENED the
--   file and pointed a test at the item. It cannot tell a real behavioural case from an id that
--   wandered into a spawn list.
--
--   So: this is a ratchet against drift, not a proof of coverage. It is deliberately cheap to
--   satisfy -- the point is that satisfying it puts an author in the spec file, where writing the
--   real assertion is then the obvious next move. tests/items_spec.lua is the model for what a real
--   item case looks like; tests/support/fixture.lua is what makes one cheap to write.
--
-- Reads the spec sources through love.filesystem, so it runs headless with the rest of the suite.

local Item = require("models.item")

local ALLOWLIST_PATH = "tests/support/untested_items.lua"

-- Every id named anywhere in tests/, as a set. One pass over the spec sources, shared by the cases
-- below so the directory is not walked twice.
local mentioned
local function mentionedIds()
    if mentioned then return mentioned end
    mentioned = {}
    for _, file in ipairs(love.filesystem.getDirectoryItems("tests")) do
        if file:match("%.lua$") and file ~= "item_coverage_spec.lua" then
            local src = love.filesystem.read("tests/" .. file)
            -- The allowlist is a list of ids by construction; counting it as coverage would make
            -- every grandfathered item look tested and the ratchet would assert nothing at all.
            if src and ("tests/" .. file) ~= ALLOWLIST_PATH then
                for id in src:gmatch('"([%w_]+)"') do mentioned[id] = true end
            end
        end
    end
    -- tests/support/ holds fixtures rather than specs, but an id named there is still an id an
    -- author pointed at, so it counts the same -- except in the allowlist itself, excluded above.
    for _, file in ipairs(love.filesystem.getDirectoryItems("tests/support")) do
        local path = "tests/support/" .. file
        if file:match("%.lua$") and path ~= ALLOWLIST_PATH then
            local src = love.filesystem.read(path)
            if src then for id in src:gmatch('"([%w_]+)"') do mentioned[id] = true end end
        end
    end
    return mentioned
end

local function allowlist()
    local list = require("tests.support.untested_items")
    local set = {}
    for _, id in ipairs(list) do set[id] = true end
    return list, set
end

local function sortedItemIds()
    local out = {}
    for id in pairs(Item.defs) do out[#out + 1] = id end
    table.sort(out)
    return out
end

return {
    {
        -- The ratchet itself. A brand-new item that no spec names fails here, by name, with the
        -- two ways out spelled in the message: write the test, or (knowingly) add it to the backlog.
        name = "every item is named by some test, or is on the grandfathered backlog",
        fn = function()
            local seen = mentionedIds()
            local _, allowed = allowlist()
            local missing = {}
            for _, id in ipairs(sortedItemIds()) do
                if not seen[id] and not allowed[id] then missing[#missing + 1] = id end
            end
            assert(#missing == 0, #missing .. " item(s) ship with no test and are not on the backlog: "
                .. table.concat(missing, ", ")
                .. " -- write a case naming the id (see tests/items_spec.lua, and"
                .. " tests/support/fixture.lua for the fixtures), or add it to " .. ALLOWLIST_PATH
                .. " if the debt is deliberate")
        end,
    },
    {
        -- The other half of the ratchet: once an item HAS a test, its backlog line must go. Without
        -- this the list would keep granting exemptions to items that no longer need one, and the
        -- count would stop meaning anything.
        name = "the backlog holds no item that has since gained a test",
        fn = function()
            local seen = mentionedIds()
            local list = allowlist()
            local stale = {}
            for _, id in ipairs(list) do
                if seen[id] then stale[#stale + 1] = id end
            end
            assert(#stale == 0, #stale .. " item(s) are tested but still listed as untested: "
                .. table.concat(stale, ", ") .. " -- delete those lines from " .. ALLOWLIST_PATH
                .. " (the backlog only ever shrinks)")
        end,
    },
    {
        -- A guard on the backlog itself: an id that no longer names a real item is a leftover from a
        -- rename or a deletion, and would sit there forever exempting nothing.
        name = "the backlog names only items that still exist",
        fn = function()
            local list = allowlist()
            local ghosts = {}
            for _, id in ipairs(list) do
                if not Item.defs[id] then ghosts[#ghosts + 1] = id end
            end
            assert(#ghosts == 0, "the backlog names " .. #ghosts .. " item(s) that no longer exist: "
                .. table.concat(ghosts, ", ") .. " -- delete those lines from " .. ALLOWLIST_PATH)
        end,
    },
    {
        -- Not an assertion about the code so much as a visible dial: the backlog is printed as a
        -- share of the whole so the number is in front of whoever runs the suite, rather than
        -- something you have to go and measure. Fails only if the debt somehow exceeds the roster.
        name = "item test coverage is reported as a running number",
        fn = function()
            local list = allowlist()
            local total = #sortedItemIds()
            local covered = total - #list
            assert(#list <= total, "the backlog cannot be longer than the item roster")
            print(string.format(
                "         items: %d/%d under the universal contract (100%%), %d/%d with a bespoke case (%.0f%%)",
                total, total, covered, total, covered / total * 100))
        end,
    },
}
