-- Can the player actually GET it? One contract, and it has been unenforced since the shelf split in
-- two.
--
-- An item with a `class` and no `price` is quest-only by construction: no vendor stocks it
-- (Vendor.stock reads price), and Spoils.lootCandidates filters the random drop pool by price too, so
-- an unpriced item can never fall out of a fight either. That leaves exactly four ways one can reach a
-- player's hands -- a quest's `rewardItems`, a character's `startingItems` (recruit them, get their
-- grid), an encounter's authored `loot` list, or the player's own opening inventory.
--
-- Named by none of them, an unpriced item is DEAD DATA: it loads, it passes the schema, it tallies
-- toward a class in docs/classes.md's counts, tests/armor_spec.lua and tests/weapon_spec.lua both
-- count it toward their five-per-shelf promises -- and no save file can ever contain it. The counts
-- say "finish this vendor's line and you are handed these five"; this spec is what makes that a
-- promise rather than a claim.
--
-- BOUND items are exempt (`bound = true`): they are nailed to one character's centre cell and can
-- never be earned, bought, stolen or moved (Character.reconcileBound). armor_sworn_aegis is the
-- reference case, and tests/armor_spec.lua already holds them outside its own count for the same
-- reason. They arrive with the person or not at all.
--
-- Pure logic, headless.

local Item = require("models.item")
local Quest = require("models.quest")
local Character = require("models.character")
local Encounter = require("models.encounter")

local function hasTag(def, tag)
    for _, t in ipairs(def.tags or {}) do if t == tag then return true end end
    return false
end

-- Every item id the game can put in a player's hands without a shop or a loot roll, as a set.
local function obtainableIds()
    local got = {}

    local function add(list)
        for _, id in ipairs(list or {}) do
            -- `startingItems` is POSITIONAL: empty grid cells are `false`, not nil, so ipairs walks
            -- straight through them. Skip anything that is not an id.
            if type(id) == "string" then got[id] = true end
        end
    end

    for _, def in pairs(Quest.defs) do add(def.rewardItems) end
    for _, def in pairs(Character.defs) do add(def.startingItems) end
    for _, def in pairs(Encounter.defs) do add(def.loot) end
    add(require("data.player").startingItems)

    return got
end

-- Quest-only items, sorted, so a failure message is stable and diffable.
local function questOnly()
    local out = {}
    for id, def in pairs(Item.defs) do
        if def.class and not def.price and not def.bound then out[#out + 1] = id end
    end
    table.sort(out)
    return out
end

return {
    {
        name = "every quest-only item has a source that can actually hand it over",
        fn = function()
            local got = obtainableIds()
            local orphans = {}
            for _, id in ipairs(questOnly()) do
                if not got[id] then orphans[#orphans + 1] = id end
            end
            assert(#orphans == 0, #orphans .. " unpriced item(s) no source can grant -- "
                .. "give each a quest's rewardItems, a character's startingItems, or an encounter's "
                .. "loot, or price it: " .. table.concat(orphans, ", "))
        end,
    },
    {
        -- The other direction: a quest that hands over an id nothing defines pays out nothing and
        -- says nothing, silently. Player.grantItem drops unknown ids rather than raising, so this is
        -- exactly the kind of typo that survives to a save file.
        name = "every rewardItems id names a real item",
        fn = function()
            local bad = {}
            for questId, def in pairs(Quest.defs) do
                for _, id in ipairs(def.rewardItems or {}) do
                    if not Item.defs[id] then bad[#bad + 1] = questId .. " -> " .. tostring(id) end
                end
            end
            table.sort(bad)
            assert(#bad == 0, "quest reward(s) naming no known item: " .. table.concat(bad, ", "))
        end,
    },
}
