-- Tests for models/spoils.lua: the computed gold + loot a won combat/elite fight pays out, and the
-- salvage floor under every won fight. Every loot id must resolve to a real blueprint, overrides must
-- short-circuit the computation, no fight may ever pay nothing, and the module must load without
-- love.graphics (the runner is headless).

local Spoils = require("models.spoils")
local Item = require("models.item")
local Character = require("models.character")
local Material = require("models.material")

-- Total materials in a { id = count } table, and whether any of them is house stock.
local function totalMaterials(mats)
    local n = 0
    for _, count in pairs(mats or {}) do n = n + count end
    return n
end

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

-- Stamp a `drops` list onto a blueprint for the length of one case, and hand back the undo. The
-- authored route reads Character.defs directly, so this is the whole of what a fixture needs -- and
-- stamping rather than picking a body that already carries one keeps these cases true while the
-- catalogue is still being authored (docs/drops.md).
local function withDrops(charId, list)
    local def = Character.defs[charId]
    local had = def.drops
    def.drops = list
    return function() def.drops = had end
end

-- An unbound item the rift will give up at the shallowest depth there is, chosen by SCANNING rather
-- than typed, so a re-tier moves the fixture instead of reddening the spec on an id that moved.
local function shallowItem()
    local best
    for id, def in pairs(Item.defs) do
        if def.dropTier and not def.bound and Spoils.depthOf(def) <= 1 then
            if not best or id < best then best = id end
        end
    end
    return best
end

-- Two distinct shallow ones, for the unowned-first case.
local function twoShallowItems()
    local out = {}
    for id, def in pairs(Item.defs) do
        if def.dropTier and not def.bound and Spoils.depthOf(def) <= 1 then out[#out + 1] = id end
    end
    table.sort(out)
    return out[1], out[2]
end

-- ...and one ranked or gated well past the top of a shallow floor, for the depth-gate case.
local function deepItem()
    local best, bestDepth
    for id, def in pairs(Item.defs) do
        if def.dropTier and not def.bound then
            local d = Spoils.depthOf(def)
            if d >= 8 and (not bestDepth or d > bestDepth or (d == bestDepth and id < best)) then
                best, bestDepth = id, d
            end
        end
    end
    return best
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
    -- EVERY CASE IN THIS BLOCK IS A CAMPAIGN ROLL -- no `floorLevel` -- so it still pays gold, and the
    -- economy split left it untouched (models/scrip.lua). That is deliberate rather than incidental:
    -- these guard the CURVE (a bigger fight pays more, an elite pays richer, a tier pays materially
    -- more), the curve is one function serving both purses, and pinning it on the simpler side keeps
    -- these cases about the arithmetic. WHICH purse a fight pays into is a separate claim and lives in
    -- tests/economy_spec.lua.
    {
        name = "a won combat fight pays out gold",
        fn = function()
            local s = Spoils.roll({ enemyUnits = roster(3), day = 2, kind = "combat" })
            assert(type(s.gold) == "number" and s.gold > 0, "gold should be a positive number")
            assert(type(s.loot) == "table", "loot should be a list")
        end,
    },
    {
        name = "gold scales with roster size and prestige",
        fn = function()
            local small = Spoils.roll({ enemyUnits = roster(1), day = 1, kind = "combat",
                loot = {} })
            local big = Spoils.roll({ enemyUnits = roster(6), day = 5, kind = "combat",
                loot = {} })
            -- The jitter is +/-15%, far smaller than a 6x roster and 5x prestige gap, so this holds.
            assert(big.gold > small.gold, "a bigger, deeper fight should pay more")
        end,
    },
    {
        name = "an elite fight pays richer than a like-sized common one",
        fn = function()
            local common = Spoils.roll({ enemyUnits = roster(3), day = 3, kind = "combat",
                loot = {} })
            local elite = Spoils.roll({ enemyUnits = roster(3), day = 3, kind = "elite",
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
                    sum = sum + Spoils.roll({ enemyUnits = roster(3), day = 3, kind = "combat",
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
            local a = Spoils.roll({ count = 3, day = 3, kind = "combat", loot = {} }).gold
            seed(42)
            local b = Spoils.roll({ count = 3, day = 3, kind = "combat", loot = {},
                rewardScale = 1 }).gold
            -- Guarded against passing on two zeroes, which is what this case would do if the campaign
            -- branch ever stopped paying gold (models/scrip.lua) -- a comparison whose inputs left the
            -- reachable domain never goes red on its own.
            assert(a > 0, "the fixture rolled nothing, so this compares two zeroes")
            assert(a == b, "rewardScale=1 must equal the absent case, got " .. a .. " vs " .. b)
        end,
    },
    {
        -- ...AND IT PAYS THE CAMPAIGN'S PURSE, which is the other half of the claim now. An authored
        -- payout is an end somebody wrote down, and an end pays gold (models/scrip.lua) -- so the
        -- override does not merely replace the number, it replaces which purse the fight pays into.
        name = "rewardGold overrides the computation exactly, and pays gold rather than scrip",
        fn = function()
            local s = Spoils.roll({ enemyUnits = roster(4), day = 4, kind = "elite",
                rewardGold = 77, loot = {} })
            assert(s.gold == 77, "an explicit rewardGold should be used verbatim")
            -- ...including underground, where a rolled fight would have paid scrip.
            local deep = Spoils.roll({ enemyUnits = roster(4), day = 4, kind = "elite",
                floorLevel = 7, rewardGold = 77, loot = {} })
            assert(deep.gold == 77,
                "an authored purse on a descent floor must still pay gold -- it is an end, not a body")
        end,
    },
    {
        name = "a loot override is used verbatim",
        fn = function()
            local s = Spoils.roll({ enemyUnits = roster(2), day = 2, kind = "combat",
                loot = { "consumable_healing_potion", "consumable_healing_potion" } })
            assert(#s.loot == 2, "both override ids should come through")
            assert(s.loot[1] == "consumable_healing_potion", "the override id should be preserved")
        end,
    },
    {
        name = "an unknown override id is dropped, not emitted",
        fn = function()
            local s = Spoils.roll({ enemyUnits = roster(1), day = 1, kind = "combat",
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
                local s = Spoils.roll({ enemyUnits = roster(3), day = 4, kind = "elite" })
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
            local s = Spoils.roll({ day = 1, kind = "combat" })
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
                local s = Spoils.roll({ enemyUnits = units, day = 3, kind = "combat" })
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
                local s = Spoils.roll({ enemyUnits = units, day = 3, kind = "elite" })
                drops = drops + #s.loot
            end
            assert(drops > 0, "an empty carried pool must fall back to the band, not pay nothing")
        end,
    },
    {
        -- The headline rule: a fight that pays nothing is the one outcome the board cannot justify
        -- having walked into, so the salvage floor holds for every kind, every tier, loot or no loot.
        name = "every won fight pays at least one material",
        fn = function()
            for _, kind in ipairs({ "combat", "elite", "objective" }) do
                for tier = 1, 3 do
                    local mats = Spoils.materials({ kind = kind, tier = tier })
                    assert(totalMaterials(mats) >= 1,
                        kind .. " tier " .. tier .. " paid no material at all")
                    for id in pairs(mats) do
                        assert(Material.get(id), "salvage id must be a real blueprint: " .. tostring(id))
                    end
                end
            end
            -- ...and it rides out on a full roll too, not just the helper.
            local s = Spoils.roll({ enemyUnits = roster(2), day = 1, kind = "combat", loot = {} })
            assert(totalMaterials(s.materials) >= 1, "a rolled fight must carry its salvage")
        end,
    },
    {
        -- The grade is what you BEAT (the tier the fog already showed), never how deep the forge is.
        name = "a harder tier salvages a better craft grade",
        fn = function()
            local grades = Material.craftGrades()
            local function gradeOf(mats)
                for i, id in ipairs(grades) do
                    if mats[id] then return i end
                end
                return nil
            end
            local t1 = gradeOf(Spoils.materials({ kind = "combat", tier = 1 }))
            local t3 = gradeOf(Spoils.materials({ kind = "combat", tier = 3 }))
            assert(t1 == 1, "a tier-1 fight salvages the commonest grade")
            assert(t3 and t3 > t1, "a tier-3 fight salvages a better grade than tier-1")
            -- An elite is a grade up on the same ground.
            local elite = gradeOf(Spoils.materials({ kind = "elite", tier = 1 }))
            assert(elite and elite > t1, "an elite salvages better than a common fight of its tier")
        end,
    },
    {
        -- House stock is the gate half of the economy: the reward for the fights you could have walked
        -- around, and for the one you came for -- not for every scrap on the road.
        name = "house stock salvages off elites and objectives, never off a common fight",
        fn = function()
            local house = Material.houseFor("knight")
            assert(house, "the knight house stock must exist for this test to mean anything")
            assert(not Spoils.materials({ kind = "combat", houseMaterial = house })[house],
                "a common road fight must not pay house stock")
            assert(Spoils.materials({ kind = "elite", houseMaterial = house })[house],
                "an elite must pay house stock")
            assert(Spoils.materials({ kind = "objective", houseMaterial = house })[house],
                "the objective must pay house stock")
            -- An unsponsored leg (the prologue) passes none, and still pays craft stock.
            assert(totalMaterials(Spoils.materials({ kind = "elite" })) >= 1,
                "a fight with no house named still salvages craft stock")
            -- A house id that no longer names a blueprint is dropped, not granted.
            assert(not Spoils.materials({ kind = "elite", houseMaterial = "material_not_real" })
                ["material_not_real"], "an unknown house id must never be granted")
        end,
    },
    {
        -- The salvage is computed, not rolled -- which is what lets the seeded gold comparison above
        -- keep working, and what makes the floor a floor rather than a likely outcome.
        name = "salvage draws no RNG and is identical for two identical fights",
        fn = function()
            local a = Spoils.materials({ kind = "elite", tier = 2, houseMaterial = Material.houseFor("mage") })
            for _ = 1, 50 do
                local b = Spoils.materials({ kind = "elite", tier = 2, houseMaterial = Material.houseFor("mage") })
                for id, count in pairs(a) do
                    assert(b[id] == count, "salvage must not vary between identical fights: " .. id)
                end
                assert(totalMaterials(a) == totalMaterials(b), "salvage totals must match")
            end
        end,
    },
    {
        -- The floor must stay UNDER the cache, or leaving the path stops being the thing that stocks
        -- the Forge (docs/progression.md). A cache pays up to 4 craft + 3 house; a fight pays a
        -- fraction of that.
        name = "a fight's salvage stays smaller than a cache's payout",
        fn = function()
            local CACHE_BEST = 4 + 3 -- Overworld:placeCaches' caps, the ceiling this must sit under
            for _, kind in ipairs({ "combat", "elite", "objective" }) do
                local mats = Spoils.materials({ kind = kind, tier = 3,
                    houseMaterial = Material.houseFor("knight") })
                assert(totalMaterials(mats) < CACHE_BEST,
                    kind .. " salvage must stay under the deepest cache's payout")
            end
        end,
    },
    {
        -- What keeps a boss's phase machinery out of the player's hands (utility_demon_sigil is
        -- `bound` and carries trait_boss_phases). Every drop must still be a real, unbound item.
        name = "a bound relic is never dropped, even by the body carrying it",
        fn = function()
            local units = realRoster("character_demon_champion", 1)
            for _ = 1, 300 do
                local s = Spoils.roll({ enemyUnits = units, day = 5, kind = "elite" })
                for _, id in ipairs(s.loot) do
                    local def = Item.defs[id]
                    assert(def, "rolled loot id must exist: " .. tostring(id))
                    assert(not def.bound, "a bound item must never drop: " .. tostring(id))
                    -- An unpriced item may drop NOW, but only on its own ladder: it has to carry a
                    -- `dropTier` (tools/drop_tier.lua), which is what a shelf slot is for an item
                    -- with no shelf. What must still never fall out is something with neither --
                    -- a natural weapon, a signature, a body's phase machinery.
                    assert((def.price and def.price > 0) or def.dropTier,
                        "an item with neither a price nor a drop tier must never drop: " .. tostring(id))
                end
            end
        end,
    },

    {
        -- WHAT A FLOOR IS ALLOWED TO HAND OVER, and the reason there are two halves to the answer:
        -- floor one was dropping Warden kit. A crossing asks eight rungs in two houses
        -- (data/classes/warden.lua) and the drop pool ranked a find by what it was WORTH and by
        -- nothing else, so anything gated deep and tuned light graded shallow and fell out at the top
        -- of the rift. The priced half was worse: it had no tier gate at all, only a gold band, so a
        -- 165-gold crossing cast was reachable the moment the band cleared 165.
        --
        -- Rolled rather than read off lootCandidates, because the gate has to hold at the seam a
        -- player actually meets -- and with no `enemyUnits`, so every id here came out of the band.
        -- A body's own kit is a different promise (you took his axe) and is authored, not rolled.
        name = "a floor gives up nothing ranked or gated deeper than it reaches",
        fn = function()
            local Class = require("models.class")
            for _, floorLevel in ipairs({ 1, 3, 5, 7 }) do
                local tier = math.min(Class.CLASS_LEVEL_CAP, floorLevel)
                for _ = 1, 200 do
                    local s = Spoils.roll({ count = 3, day = floorLevel, floorLevel = floorLevel })
                    for _, id in ipairs(s.loot) do
                        local def = Item.defs[id]
                        assert(Spoils.depthOf(def) <= tier, string.format(
                            "%s (rank/gate %d) fell out of a floor that only reaches tier %d",
                            id, Spoils.depthOf(def), tier))
                    end
                end
            end
        end,
    },
    {
        -- The same rule where it is loosest. A chest deliberately reaches ABOVE the floor's own band
        -- (Spoils.SEALED_ABOVE) and so above its own rung, which is the feature -- but reaching past a
        -- gate nobody has opened is not reaching, it is skipping, and floor one's chests were sealing
        -- crossing casts. Both sealable kinds, since `secret` takes a slice of the same pool.
        name = "a sealed find reaches above the band but never past a class gate",
        fn = function()
            local Class = require("models.class")
            for _, kind in ipairs({ "treasure", "secret" }) do
                local sealed = 0
                for _ = 1, 200 do
                    for _, find in ipairs(Spoils.rollSealed({ kind = kind, floorLevel = 1 })) do
                        sealed = sealed + 1
                        local def = Item.defs[find.id]
                        assert(Class.gateLevel(def.class) <= 1 + Spoils.SEALED_REACH, string.format(
                            "%s is gated at class level %d and was sealed on floor one",
                            find.id, Class.gateLevel(def.class)))
                    end
                end
                -- ...and the bound must not have emptied the pool: a rank gate read as flatly as the
                -- ordinary drop's would leave floor one with nothing above its own band to seal.
                assert(sealed > 0, "floor one's " .. kind .. " stops must still seal something")
            end
        end,
    },

    -- ---- The Merchant's shelf (Spoils.shelf) --------------------------------------------------

    {
        -- Everything the drop table guarantees, the shelf guarantees too: it is literally the same
        -- pool. A shelf row that could not instantiate would crash the panel that displays it.
        name = "a shelf stocks real, priced, unbound items and no duplicates",
        fn = function()
            for _ = 1, 100 do
                local ids = Spoils.shelf({ day = 3, count = 3 })
                assert(#ids == 3, "the band at prestige 3 is deep enough to fill three rows")
                local seen = {}
                for _, id in ipairs(ids) do
                    local def = Item.defs[id]
                    assert(def, "a shelf id must exist: " .. tostring(id))
                    assert(Item.instantiate(id), "a shelf id must instantiate: " .. tostring(id))
                    assert(def.price and def.price > 0, "an unpriced item is not for sale: " .. tostring(id))
                    assert(not def.bound, "a bound item must never be stocked: " .. tostring(id))
                    assert(not seen[id], "the same ware must not fill two rows: " .. tostring(id))
                    seen[id] = true
                end
            end
        end,
    },
    {
        -- The shelf and the drop table are one band, so what the road sells climbs with the run exactly
        -- as what it drops does -- and a low-prestige company can never be offered top-shelf gear.
        name = "the shelf's price band widens as the campaign runs on",
        fn = function()
            local function dearest(day)
                local best = 0
                for _ = 1, 200 do
                    for _, id in ipairs(Spoils.shelf({ day = day, count = 3 })) do
                        best = math.max(best, Item.defs[id].price)
                    end
                end
                return best
            end
            local low, high = dearest(1), dearest(6)
            assert(high > low, "a deeper run should see dearer stock, got " .. low .. " vs " .. high)
            -- The band's own ceiling, quoted from bandPrice: 40 + day * 60.
            assert(low <= 40 + 1 * 60, "day 1 must never be offered past its band, got " .. low)
        end,
    },
    {
        name = "an excluded id is kept off the shelf",
        fn = function()
            local ids = Spoils.shelf({ day = 3, count = 3 })
            local banned = ids[1]
            for _ = 1, 100 do
                for _, id in ipairs(Spoils.shelf({ day = 3, count = 3, exclude = { [banned] = true } })) do
                    assert(id ~= banned, "an excluded ware was stocked anyway: " .. tostring(banned))
                end
            end
        end,
    },
    {
        -- THE CART IS STOCKED AGAINST A DEPTH, which is what states/game.lua passes it: the deepest
        -- floor the company has ever stood on, converted the way every other depth reading converts.
        -- Before this the call site named a field (`prestige`) the function does not read, so the band
        -- fell back to its floor and the wandering market was stocked at the day-one band wherever it
        -- was met -- nothing on it dearer than 100 gold, for the whole of a descent.
        name = "a deeper cart stocks deeper than a shallow one",
        fn = function()
            local seen = {}
            for _, depth in ipairs({ 1, 8 }) do
                local best = 0
                for day = 1, 40 do
                    -- Every id the cart could deal at this depth, over the whole band it is drawn
                    -- from, so the comparison is about the POOL and not about one lucky roll.
                    for _, id in ipairs(Spoils.shelf({ day = day, floorLevel = depth, count = 50 })) do
                        local def = Item.defs[id]
                        assert(def.price and def.price > 0, "a cart deals priced stock: " .. id)
                        assert(Spoils.depthOf(def) <= depth,
                            id .. " is deeper than the floor the cart was stocked against")
                        if def.price > best then best = def.price end
                    end
                end
                seen[depth] = best
            end
            assert(seen[8] > seen[1],
                "a cart stocked against the deep end must reach past what floor one's does")
        end,
    },
    {
        -- A market with nothing on it is a stop with nothing to do; the caller clears the cell instead,
        -- so the empty case has to come back as an empty list rather than an error.
        name = "a shelf that cannot be filled returns what it could, without erroring",
        fn = function()
            assert(#Spoils.shelf({ day = 3, count = 0 }) == 0, "a zero-row shelf is empty")
            local huge = Spoils.shelf({ day = 1, count = 10000 })
            assert(type(huge) == "table", "an unfillable shelf still returns a list")
            local seen = {}
            for _, id in ipairs(huge) do
                assert(not seen[id], "the exhausted pool must not start repeating: " .. tostring(id))
                seen[id] = true
            end
        end,
    },

    -- ---------------------------------------------------------------------------
    -- The authored route: a body's own `drops` list (docs/drops.md)
    -- ---------------------------------------------------------------------------
    --
    -- EVERY CASE HERE COLLECTS FIRST, RESTORES, AND ONLY THEN ASSERTS. The runner pcalls a case, so an
    -- assert that fires inside a `withDrops` window would skip the undo and leave a stamped blueprint
    -- behind -- which is exactly how the first cut of this block turned one real failure into two, the
    -- second of them in an unrelated case that had done nothing wrong.
    {
        -- The whole point of the third route. A body that is KNOWN FOR something has to be able to hand
        -- that thing over, off its blueprint rather than off a depth band that happens to reach it.
        name = "a body's authored drops list can pay out",
        fn = function()
            local id = shallowItem()
            assert(id, "the catalogue must hold at least one shallow unbound item to test with")
            local restore = withDrops("character_bandit", { id })
            local seen = false
            for _ = 1, 400 do
                for _, got in ipairs(Spoils.roll({
                    enemyUnits = realRoster("character_bandit", 3), day = 9, floorLevel = 9,
                }).loot) do
                    if got == id then seen = true end
                end
            end
            restore()
            assert(seen, "400 fights against a body listing " .. id .. " never paid one")
        end,
    },
    {
        -- A list is authored on the BODY, and a body can be met shallower than its best piece is
        -- ranked or than its class gate allows. Without the depth gate an ordinary floor-one stop
        -- hands over eight-rung kit purely because somebody wrote it onto a wanderer that rolls early.
        name = "an authored drop still obeys the depth gate",
        fn = function()
            local deep = deepItem()
            assert(deep, "the catalogue must hold a deep-ranked unbound item to test with")
            local restore = withDrops("character_bandit", { deep })
            local leaked = false
            for _ = 1, 300 do
                for _, got in ipairs(Spoils.roll({
                    enemyUnits = realRoster("character_bandit", 3), day = 1, floorLevel = 1,
                }).loot) do
                    if got == deep then leaked = true end
                end
            end
            restore()
            assert(not leaked, deep .. " fell out on floor one; depthOf says "
                .. tostring(Spoils.depthOf(Item.defs[deep])))
        end,
    },
    {
        -- Descent.dropFor's rule, lifted: a body with anything new to give gives that. Without it a
        -- list is a lottery you re-roll for the piece you are missing, which is the frustration the
        -- boss lists were already designed to avoid.
        --
        -- MEASURED AS A RATIO, NOT AS AN ABSENCE, and the reason is worth keeping: the band and the
        -- carried pool are both still live, so a shallow owned id can and will turn up through them --
        -- asserting it NEVER appears is a claim about three routes while only one of them is under
        -- test. What unowned-first actually promises is that the authored route stops offering it, so
        -- the new one has to come out far oftener than the held one. Without the rule the two would be
        -- drawn evenly.
        name = "an authored drop pays what the company does not already hold",
        fn = function()
            local a, b = twoShallowItems()
            assert(a and b, "need two distinct shallow items to test unowned-first")
            local restore = withDrops("character_bandit", { a, b })
            local player = { stash = { { id = a } }, roster = {} } -- the company holds `a`
            local held, new = 0, 0
            for _ = 1, 800 do
                for _, got in ipairs(Spoils.roll({
                    enemyUnits = realRoster("character_bandit", 3), day = 9, floorLevel = 9,
                    player = player,
                }).loot) do
                    if got == a then held = held + 1 elseif got == b then new = new + 1 end
                end
            end
            restore()
            assert(new > 0, "the unowned entry " .. b .. " never dropped at all")
            assert(new > held * 2, "unowned-first should favour " .. b .. " heavily, got "
                .. new .. " new vs " .. held .. " held")
        end,
    },
    {
        -- The tolerant reading: every caller that has not been taught to pass a player must behave
        -- exactly as it did, which means the whole list stands rather than nothing does.
        name = "a body with no drops list is unaffected by the authored route",
        fn = function()
            local units = realRoster("character_bandit", 3)
            assert(not (Character.defs["character_bandit"] or {}).drops,
                "character_bandit must carry no authored list for this to mean anything")
            for _ = 1, 200 do
                for _, got in ipairs(Spoils.roll({ enemyUnits = units, day = 5 }).loot) do
                    assert(Item.defs[got], "every rolled id still resolves: " .. tostring(got))
                end
            end
        end,
    },
    {
        -- P8: a floor may not pay nothing. At the bare 15% a dry floor of eight fights happens about a
        -- quarter of the time, which at ~14 husks a run is the experience that ends runs.
        name = "a dry floor lifts the husk chance until it pays",
        fn = function()
            local function rate(drought)
                local hits = 0
                for _ = 1, 600 do
                    local s = Spoils.roll({
                        enemyUnits = realRoster("character_bandit", 3),
                        day = 6, floorLevel = 6, kind = "combat", drought = drought,
                    })
                    if #(s.sealed or {}) > 0 then hits = hits + 1 end
                end
                return hits / 600
            end
            local dry0, dry3 = rate(0), rate(3)
            assert(dry3 > dry0, "three dry stops must lift the chance, got "
                .. dry0 .. " -> " .. dry3)
            assert(rate(5) > 0.9, "by the fifth dry stop a husk should be near certain")
        end,
    },
    {
        -- The half worth protecting: a floor that pays on its first stop has had its rate touched not
        -- at all, so the common case stays the authored one.
        name = "no drought leaves the authored rate exactly where it was",
        fn = function()
            local hits = 0
            for _ = 1, 1200 do
                local s = Spoils.roll({
                    enemyUnits = realRoster("character_bandit", 3),
                    day = 6, floorLevel = 6, kind = "combat",
                })
                if #(s.sealed or {}) > 0 then hits = hits + 1 end
            end
            local rate = hits / 1200
            -- SEALED_CHANCE.combat is 0.15; the pool can refuse, so this is an upper-bounded band.
            assert(rate <= 0.15 + 0.04,
                "an undroughted fight must not exceed its authored 15%, got " .. rate)
        end,
    },
    {
        -- The tally is a fact about the FLOOR. Carrying it down would let one lucky floor make the next
        -- four dry ones legal.
        name = "a new floor resets the husk drought",
        fn = function()
            local Descent = require("models.descent")
            local run = { floor = 1, sealedDrought = 4 }
            Descent.advance(run)
            assert(Descent.sealedDrought(run) == 0, "advancing a floor clears the dry spell")
            Descent.recordSealed(run, false)
            assert(Descent.sealedDrought(run) == 1, "a dry stop lengthens it")
            Descent.recordSealed(run, true)
            assert(Descent.sealedDrought(run) == 0, "a paid stop resets it")
        end,
    },
}
