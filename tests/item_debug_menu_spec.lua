-- The right-click item debug menu (ui/panels/debug_menu.lua's DebugMenu.forItem) and the two model
-- functions under it: Item.paths, which says where a blueprint LIVES, and the Item.reload/Item.restamp
-- pair, which re-reads one off disk and brings a live copy up to date with it.
--
-- The menu itself is a UI widget, so what is pinned here is the part a screenshot cannot check: that
-- every catalog id can be traced back to a file that exists, that the root offers the four rows in the
-- order the affordance promises, that a reload is a no-op when the file has not changed, and -- the one
-- that would rot silently -- that a re-stamp carries runtime state across and clears what an edit cut.

local Item = require("models.item")
local Debug = require("models.debug")
local DebugMenu = require("ui.panels.debug_menu")

-- The rows of a list page, by label, so an assertion can read like the menu does.
local function labels(page)
    local out = {}
    for _, row in ipairs(page.rows) do out[#out + 1] = row.label end
    return out
end

local function rowNamed(page, prefix)
    for _, row in ipairs(page.rows) do
        if tostring(row.label):sub(1, #prefix) == prefix then return row end
    end
    return nil
end

-- Fonts are stubbed the way tests/advancement_spec.lua and tests/inn_spec.lua do it: DebugMenu.new
-- bakes one in the constructor (Theme.body) and love.graphics.newFont throws with no window. Nothing
-- here draws.
--
-- IT WAS NOT STUBBED AND STILL PASSED, which is worth recording because it is the more dangerous of the
-- two states. Theme.body memoizes by size, and several specs that run earlier in the alphabet stub
-- newFont around their own panel construction -- so a STUB font was landing in the shared cache at the
-- size this menu happens to ask for, and these three cases were reading it. Green for a reason that had
-- nothing to do with them: the spec failed on its own the whole time, and would have started failing in
-- the full run the moment an unrelated panel changed its font size.
local function stubFonts(fn)
    local gfx = love.graphics
    local real = gfx.newFont
    gfx.newFont = function()
        return {
            getHeight = function() return 18 end,
            getWidth = function(_, s) return #tostring(s or "") * 8 end,
            getWrap = function(_, text, _) return text, { text } end,
        }
    end
    local ok, err = pcall(fn)
    gfx.newFont = real
    if not ok then error(err, 0) end
end

local function menuFor(id, level)
    local menu
    stubFonts(function()
        menu = DebugMenu.forItem({ item = Item.instantiate(id, 1, level or 0), x = 100, y = 100 })
    end)
    return menu
end

return {
    {
        -- The whole affordance stands on this one mapping. An id whose path is missing is an item the
        -- menu can neither open nor reload, and nothing else in the game would ever notice.
        name = "every item blueprint knows the file it was read out of, and that file is there",
        fn = function()
            local n = 0
            for id in pairs(Item.defs) do
                local rel = Item.paths[id]
                assert(rel, "no source path recorded for " .. id)
                assert(rel:match("%.lua$"), id .. " path is not a lua file: " .. rel)
                assert(love.filesystem.getInfo(rel), "recorded path does not exist: " .. rel)
                -- The id IS the bare filename (models/registry.lua's contract), which is what lets a
                -- reload turn the path back into a require path without a second lookup.
                assert(rel:match("([^/]+)%.lua$") == id, "path does not end in the id: " .. rel)
                n = n + 1
            end
            assert(n > 100, "expected the whole item catalog, got " .. n)
        end,
    },
    {
        name = "the item menu opens on the four rows the affordance promises, in order",
        fn = function()
            assert(Debug.enabled, "this suite runs a development build; the menu is gated on it")
            local menu = menuFor("weapon_iron_sword")
            assert(menu, "the menu should open on a catalog item")
            local page = menu:top()
            assert(page.title == "Iron Sword", "the header names the item, got " .. tostring(page.title))
            local rows = labels(page)
            assert(rows[1] == "Open weapon_iron_sword.lua",
                "row 1 is the source file, got " .. tostring(rows[1]))
            assert(rows[2] == "Reload blueprint", "row 2 is the reload, got " .. tostring(rows[2]))
            assert(rows[3] == "Copy id", "row 3 is the id, got " .. tostring(rows[3]))
            assert(rows[4] == "Grade / price", "row 4 is the grade, got " .. tostring(rows[4]))
            assert(#rows == 4, "and nothing else")
        end,
    },
    {
        -- The three file rows are not board commands: closing on each one would make an
        -- open-edit-reload-look loop three right-clicks long.
        name = "the file rows keep the menu open and report themselves; the grade row descends",
        fn = function()
            local menu = menuFor("weapon_iron_sword")
            local page = menu:top()
            for i = 1, 3 do
                assert(page.rows[i].kind == "action", "row " .. i .. " acts")
                assert(page.rows[i].keep, "row " .. i .. " keeps the menu open")
            end
            assert(page.rows[4].kind == "submenu", "the grade row pushes a page")

            menu:activate(2) -- Reload blueprint
            assert(not menu.closed, "a keep row leaves the menu standing")
            assert(#menu.stack == 1, "and does not descend")
            assert(menu:top().notice, "it says what it did on the notice line")
            assert(menu:top().notice:find("reloaded", 1, true),
                "an unedited file reloads cleanly, got: " .. tostring(menu:top().notice))
        end,
    },
    {
        name = "the grade page reads the item's value against the price its authored slot implies",
        fn = function()
            local menu = menuFor("weapon_iron_sword")
            menu:activate(4)
            local page = menu:top()
            assert(#menu.stack == 2, "the grade row pushed a page")
            assert(page.title:find("Iron Sword", 1, true), "the page names its subject")
            for _, row in ipairs(page.rows) do
                assert(row.kind == "info", "a report has no controls on it: " .. tostring(row.label))
            end
            assert(rowNamed(page, "GRADE"), "the total leads")
            assert(rowNamed(page, "  active"), "the active half is named")
            assert(rowNamed(page, "  passive"), "the passive half is named")
            assert(rowNamed(page, "  slot (unlockQuests)"), "the authored slot is on the page")
            local price = rowNamed(page, "  price")
            assert(price and price.rhs == "80g", "the authored price is on the page, got " .. tostring(price and price.rhs))
            assert(rowNamed(page, "  price for that slot"), "and what that slot implies, to compare it against")
            -- Backing out of the report returns to the root rather than shutting the menu.
            menu:back()
            assert(not menu.closed and #menu.stack == 1, "back pops the page, not the menu")
        end,
    },
    {
        -- A hand-built instance (a bagged loot roll, a fabricated test item) has no blueprint to open,
        -- and a release build has no debug affordances at all. Both answer nil, so a host can write
        -- `menu = DebugMenu.forItem{...}` and let the nil say no.
        name = "the menu refuses an item the catalog does not know, and a release build entirely",
        fn = function()
            assert(DebugMenu.forItem({ item = { id = "weapon_not_a_real_item", name = "?" } }) == nil,
                "an unknown id has no file to open")
            assert(DebugMenu.forItem({ item = nil }) == nil, "and nothing at all is nothing to open")

            local was = Debug.enabled
            Debug.enabled = false
            local menu = menuFor("weapon_iron_sword")
            Debug.enabled = was
            assert(menu == nil, "a release build offers no debug menu")
        end,
    },
    {
        name = "reloading a blueprint that has not changed leaves the catalog exactly as it was",
        fn = function()
            local before = Item.defs.weapon_iron_sword
            local ok, err, stale = Item.reload("weapon_iron_sword")
            assert(ok, "the reload should succeed: " .. tostring(err))
            assert(stale == before, "it hands back the blueprint it replaced")
            local after = Item.defs.weapon_iron_sword
            assert(after.name == before.name and after.price == before.price,
                "an unedited file re-reads to the same figures")
            assert(after.activeAbility.speed == before.activeAbility.speed, "including inside the ability")
        end,
    },
    {
        name = "an unknown id reports rather than emptying the catalog",
        fn = function()
            local ok, err = Item.reload("weapon_not_a_real_item")
            assert(not ok, "there is no file to re-read")
            assert(type(err) == "string" and err:find("no source file", 1, true), "and it says so: " .. tostring(err))
        end,
    },
    {
        -- The point of the pair. A reload swaps the BLUEPRINT; every item already in a grid is a copy
        -- taken at instantiate time, so without the re-stamp the change is invisible and reads as a
        -- reload that failed.
        name = "a re-stamp brings a live copy up to date in place, keeping its identity",
        fn = function()
            local item = Item.instantiate("weapon_iron_sword", 1, 3)
            local marker = item                       -- the exact table a grid cell would be holding
            local stale = Item.defs.weapon_iron_sword

            -- Stand in for an edited file: a swapped-in blueprint with one figure moved and one field
            -- (the parry trait) cut out of it.
            local edited = {}
            for k, v in pairs(stale) do edited[k] = v end
            edited.price = 999
            edited.traits = nil
            Item.defs.weapon_iron_sword = edited

            local ok = Item.restamp(item, stale)
            Item.defs.weapon_iron_sword = stale -- put the real catalog back before anything else reads it

            assert(ok, "the re-stamp should report success")
            assert(item == marker, "the instance keeps its identity -- whoever holds it goes on holding it")
            assert(item.price == 999, "a changed figure lands on the live copy")
            assert(item.traits == nil, "and a field the edit CUT is cleared, not left standing")
            assert(item.level == 3, "the forge level survives, and the magnitudes are rebuilt at it")
            assert(item.name:find("+3", 1, true), "including the level suffix on the name")
        end,
    },
    {
        -- Runtime state is not the blueprint's to say, so the rebuild must carry it across rather than
        -- reset it: a half-used stack of potions must not refill itself because somebody hit reload.
        name = "a re-stamp carries runtime state across rather than resetting it",
        fn = function()
            local id
            for candidate, def in pairs(Item.defs) do
                if def.type == "consumable" and (def.maxStack or 1) > 1 then id = candidate break end
            end
            assert(id, "expected at least one stackable consumable in the catalog")

            local item = Item.instantiate(id, 3)
            item.unidentified = true -- written by models/identify.lua, never by a blueprint
            assert(Item.restamp(item, Item.defs[id]))
            assert(item.quantity == 3, "the stack keeps its count")
            assert(item.unidentified == true, "and an instance's own flags are not blown away")
        end,
    },
}
