-- The Armory (Loadout) stash filter: the pure half of ui/panels/party.lua's weapon-type / discipline
-- strip. Filtering the REAL stash can't rebuild the backing list the way the debug editor's throwaway
-- catalog does (that would drop the filtered-out items), so the panel shows a filtered VIEW and keeps
-- a pool-index -> stash-index map so every transfer still reaches the right owned item. This pins that
-- view + map + the match rule, none of which touch love.graphics.
--
-- Items are fabricated plain tables (just the fields the matchers read: `tags` for the weapon family,
-- `discipline`) so the test says what it means and can't drift when content is edited.

local Party = require("ui.panels.party")
local Item = require("models.item")

-- A bare panel with just the fields the filter methods read -- enough to call the pure logic without
-- building the whole love.graphics-bound screen (mirrors party_spec's regionCross/equipDelta cases).
local function panel(stash, filters)
    return setmetatable({ player = { stash = stash }, filters = filters }, Party)
end

-- Armory-shaped groups: `valueOf` reads an item's value for the group; `selected` is the picked set.
local function weaponGroup(selected)
    return { label = "Weapon", options = {}, selected = selected or {},
        valueOf = function(it) return Item.archetype(it) end }
end
local function disciplineGroup(selected)
    return { label = "Class", options = {}, selected = selected or {},
        valueOf = function(it) return it.discipline end }
end

local sword1 = { id = "s1", tags = { "sword" } }
local bow1   = { id = "b1", tags = { "bow" } }
local sword2 = { id = "s2", tags = { "sword" }, discipline = "duelist" }
local potion = { id = "p1", tags = {}, discipline = "apothecary" }

local function fourItemStash()
    return { sword1, bow1, sword2, potion }
end

return {
    {
        name = "no filters at all: the whole stash shows and indices pass straight through",
        fn = function()
            local p = panel(fourItemStash(), nil)
            local view = p:visibleStash()
            assert(#view == 4, "an unfiltered stash shows every item")
            assert(p.stashMap == nil, "with no filters there is no index map to keep")
            assert(p:stashIndex(3) == 3, "the pool index IS the stash index when nothing narrows it")
        end,
    },
    {
        name = "filters present but nothing picked: still the whole stash, with an identity map",
        fn = function()
            local p = panel(fourItemStash(), { weaponGroup(), disciplineGroup() })
            local view = p:visibleStash()
            assert(#view == 4, "an untouched strip restricts nothing")
            -- The map exists (a filter IS installed) but is the identity, so transfers are unaffected.
            assert(p:stashIndex(2) == 2 and p:stashIndex(4) == 4, "empty selections map 1:1")
        end,
    },
    {
        name = "a weapon-type chip narrows the view and maps its cells back to the real stash",
        fn = function()
            local p = panel(fourItemStash(), { weaponGroup({ sword = true }), disciplineGroup() })
            local view = p:visibleStash()
            assert(#view == 2, "only the two swords survive the 'sword' filter")
            assert(view[1] == sword1 and view[2] == sword2, "in stash order")
            -- The bow sat at stash index 2 and the second sword at 4; the view collapses to 1,2 but the
            -- map has to point back at 1 and 3 or an equip would move the wrong item.
            assert(p:stashIndex(1) == 1, "first shown sword is stash #1")
            assert(p:stashIndex(2) == 3, "second shown sword is stash #3, not #2")
            assert(p:passesFilters(sword1) and not p:passesFilters(bow1), "match rule agrees")
        end,
    },
    {
        name = "a discipline chip filters on the discipline field, weapon or not",
        fn = function()
            local p = panel(fourItemStash(), { weaponGroup(), disciplineGroup({ apothecary = true }) })
            local view = p:visibleStash()
            assert(#view == 1 and view[1] == potion, "only the apothecary item shows")
            assert(p:stashIndex(1) == 4, "and it maps back to its real stash slot")
        end,
    },
    {
        name = "two groups AND together -- swords that are ALSO duelist gear",
        fn = function()
            local p = panel(fourItemStash(),
                { weaponGroup({ sword = true }), disciplineGroup({ duelist = true }) })
            local view = p:visibleStash()
            assert(#view == 1 and view[1] == sword2, "sword1 fails the discipline half; only sword2 passes both")
            assert(not p:passesFilters(sword1), "a plain sword is out once a discipline is also required")
        end,
    },
    {
        name = "a group without a valueOf never constrains the view (the debug editor's kind)",
        fn = function()
            -- The debug character editor filters by rebuilding its catalog, so its groups carry no
            -- valueOf; the panel's view must leave those alone rather than hide everything.
            local debugGroup = { label = "Type", options = {}, selected = { weapon = true } }
            local p = panel(fourItemStash(), { debugGroup })
            assert(#p:visibleStash() == 4, "a valueOf-less group leaves the view whole")
        end,
    },
}
