-- Tests for models/spoils.lua: the computed gold + loot a won combat/elite fight pays out. Every
-- loot id must resolve to a real blueprint, overrides must short-circuit the computation, and the
-- module must load without love.graphics (the runner is headless).

local Spoils = require("models.spoils")
local Item = require("models.item")

-- A stand-in enemy roster: only the length matters to the gold computation.
local function roster(n)
    local units = {}
    for i = 1, n do units[i] = { char = { id = "character_bandit" } } end
    return units
end

return {
    {
        name = "a won combat fight pays out gold",
        fn = function()
            local s = Spoils.roll({ enemyUnits = roster(3), prestige = 2, kind = "combat" })
            assert(type(s.gold) == "number" and s.gold > 0, "gold should be a positive number")
            assert(type(s.loot) == "table", "loot should be a list")
        end,
    },
    {
        name = "gold scales with roster size and prestige",
        fn = function()
            local small = Spoils.roll({ enemyUnits = roster(1), prestige = 1, kind = "combat",
                loot = {} })
            local big = Spoils.roll({ enemyUnits = roster(6), prestige = 5, kind = "combat",
                loot = {} })
            -- The jitter is +/-15%, far smaller than a 6x roster and 5x prestige gap, so this holds.
            assert(big.gold > small.gold, "a bigger, deeper fight should pay more")
        end,
    },
    {
        name = "an elite fight pays richer than a like-sized common one",
        fn = function()
            local common = Spoils.roll({ enemyUnits = roster(3), prestige = 3, kind = "combat",
                loot = {} })
            local elite = Spoils.roll({ enemyUnits = roster(3), prestige = 3, kind = "elite",
                loot = {} })
            assert(elite.gold > common.gold, "an elite fight of the same size should pay more")
        end,
    },
    {
        name = "rewardGold overrides the computation exactly",
        fn = function()
            local s = Spoils.roll({ enemyUnits = roster(4), prestige = 4, kind = "elite",
                rewardGold = 77, loot = {} })
            assert(s.gold == 77, "an explicit rewardGold should be used verbatim")
        end,
    },
    {
        name = "a loot override is used verbatim",
        fn = function()
            local s = Spoils.roll({ enemyUnits = roster(2), prestige = 2, kind = "combat",
                loot = { "consumable_healing_potion", "consumable_healing_potion" } })
            assert(#s.loot == 2, "both override ids should come through")
            assert(s.loot[1] == "consumable_healing_potion", "the override id should be preserved")
        end,
    },
    {
        name = "an unknown override id is dropped, not emitted",
        fn = function()
            local s = Spoils.roll({ enemyUnits = roster(1), prestige = 1, kind = "combat",
                loot = { "consumable_healing_potion", "not_a_real_item" } })
            for _, id in ipairs(s.loot) do
                assert(id ~= "not_a_real_item", "an unknown id must never survive the roll")
            end
        end,
    },
    {
        name = "every rolled loot id resolves to a real blueprint",
        fn = function()
            -- Roll many times so the weighted draw covers a good spread of the pool.
            for _ = 1, 200 do
                local s = Spoils.roll({ enemyUnits = roster(3), prestige = 4, kind = "elite" })
                for _, id in ipairs(s.loot) do
                    assert(Item.defs[id], "rolled loot id must exist in Item.defs: " .. tostring(id))
                    -- Instantiation is the real crash site a bad id would hit; prove it survives.
                    assert(Item.instantiate(id), "rolled loot id must instantiate: " .. tostring(id))
                end
            end
        end,
    },
    {
        name = "a fight with no enemyUnits still rolls without erroring",
        fn = function()
            local s = Spoils.roll({ prestige = 1, kind = "combat" })
            assert(s.gold > 0, "gold falls back to a single-enemy computation")
        end,
    },
}
