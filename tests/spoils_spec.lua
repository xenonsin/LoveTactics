-- Tests for models/spoils.lua: the computed gold + loot a won combat/elite fight pays out. Every
-- loot id must resolve to a real blueprint, overrides must short-circuit the computation, and the
-- module must load without love.graphics (the runner is headless).

local Spoils = require("models.spoils")
local Item = require("models.item")
local Character = require("models.character")

-- A stand-in enemy roster: bare tables with no grid, so only the length matters. Kept as-is to
-- prove the gold half still works for a caller that has no bodies to hand over.
local function roster(n)
    local units = {}
    for i = 1, n do units[i] = { char = { id = "character_bandit" } } end
    return units
end

-- A REAL roster: instantiated characters carrying their blueprint loadouts, which is what a live
-- battle passes and what the carried-drop path actually reads.
local function realRoster(id, n)
    local units = {}
    for i = 1, n do units[i] = { char = Character.instantiate(id) } end
    return units
end

-- The priced, unbound ids a roster is carrying -- the set a carried drop must come from.
local function carriedIds(units)
    local set = {}
    for _, u in ipairs(units) do
        for _, item in ipairs(Character.eachItem(u.char)) do
            local def = item.id and Item.defs[item.id]
            if def and def.price and def.price > 0 and not def.bound then set[item.id] = true end
        end
    end
    return set
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
        -- The overworld redesign's risk/reward: a tougher tier pays materially more, so engaging a
        -- fight before the boss is a real gamble against attrition. Averaged over many rolls to see
        -- past the +/-15% jitter.
        name = "a higher difficulty tier (rewardScale) pays materially more gold",
        fn = function()
            local function avgGold(scale)
                local sum = 0
                for _ = 1, 300 do
                    sum = sum + Spoils.roll({ enemyUnits = roster(3), prestige = 3, kind = "combat",
                        loot = {}, rewardScale = scale }).gold
                end
                return sum / 300
            end
            local t1, t3 = avgGold(1.0), avgGold(2.4)
            assert(t3 > t1 * 1.8, "a tier-3 fight should pay far more than tier-1, got "
                .. t1 .. " vs " .. t3)
        end,
    },
    {
        -- Regression guard: absent rewardScale (or 1) reproduces the pre-tier payout exactly, so an
        -- objective/quest reward (which never passes a scale) is untouched.
        name = "rewardScale absent or 1 reproduces the base payout",
        fn = function()
            -- Spoils draws from love.math under LÖVE, so seed THAT (fall back to math for a bare run).
            local function seed(n)
                if love and love.math and love.math.setRandomSeed then love.math.setRandomSeed(n)
                else math.randomseed(n) end
            end
            -- loot = {} short-circuits the loot roll, so only gold's single jitter draw consumes RNG.
            seed(42)
            local a = Spoils.roll({ count = 3, prestige = 3, kind = "combat", loot = {} }).gold
            seed(42)
            local b = Spoils.roll({ count = 3, prestige = 3, kind = "combat", loot = {},
                rewardScale = 1 }).gold
            assert(a == b, "rewardScale=1 must equal the absent case, got " .. a .. " vs " .. b)
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
    {
        -- The headline of the carried-drop change: beating a body pays out in what that body had.
        name = "loot is drawn off the beaten roster far more often than off the price band",
        fn = function()
            local units = realRoster("character_bandit", 3)
            local carried = carriedIds(units)
            assert(next(carried), "the bandit must carry something priced for this test to mean anything")
            local fromBody, total = 0, 0
            for _ = 1, 400 do
                local s = Spoils.roll({ enemyUnits = units, prestige = 3, kind = "combat" })
                for _, id in ipairs(s.loot) do
                    total = total + 1
                    if carried[id] then fromBody = fromBody + 1 end
                end
            end
            assert(total > 0, "400 rolls should produce some loot")
            -- CARRIED_BIAS is 0.75; a band draw can coincidentally match a carried id, never the
            -- reverse, so the true rate is >= 0.75. 0.5 leaves ample room for sampling noise.
            assert(fromBody / total > 0.5,
                "most drops should come off the bodies, got " .. fromBody .. "/" .. total)
        end,
    },
    {
        -- Creatures carry unpriced, noSteal natural weapons, so their carried pool is empty and the
        -- price band has to catch the fight. A beast pack that paid nothing would be a regression.
        name = "a roster carrying nothing priced still pays out from the price band",
        fn = function()
            local units = realRoster("character_wolf_grunt", 3)
            assert(not next(carriedIds(units)), "a wolf should carry nothing priced")
            local drops = 0
            for _ = 1, 200 do
                local s = Spoils.roll({ enemyUnits = units, prestige = 3, kind = "elite" })
                drops = drops + #s.loot
            end
            assert(drops > 0, "an empty carried pool must fall back to the band, not pay nothing")
        end,
    },
    {
        -- What keeps a boss's phase machinery out of the player's hands (utility_demon_sigil is
        -- `bound` and carries trait_boss_phases). Every drop must still be a real, unbound item.
        name = "a bound relic is never dropped, even by the body carrying it",
        fn = function()
            local units = realRoster("character_demon_champion", 1)
            for _ = 1, 300 do
                local s = Spoils.roll({ enemyUnits = units, prestige = 5, kind = "elite" })
                for _, id in ipairs(s.loot) do
                    local def = Item.defs[id]
                    assert(def, "rolled loot id must exist: " .. tostring(id))
                    assert(not def.bound, "a bound item must never drop: " .. tostring(id))
                    assert(def.price and def.price > 0, "an unpriced item must never drop: " .. tostring(id))
                end
            end
        end,
    },
}
