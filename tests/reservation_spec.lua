-- Tests for resource reservation (models/combat.lua): committing part of a pool to sustain a
-- summon. A reservation lowers the CEILING that `current` may reach; it never touches `max`, so
-- percentage-of-maximum modifiers stay honest. Also covers the cost multiplier a status can apply
-- to every ability price (Haste). Pure logic, runs headless.

local Character = require("models.character")
local Item = require("models.item")
local Combat = require("models.combat")
local Status = require("models.status")

-- A flat, all-walkable arena (mirrors tests/resource_spec.lua).
local function arena(cols, rows, objective)
    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do
            tiles[y][x] = { type = "ground", moveCost = 1, walkable = true }
        end
    end
    return { cols = cols, rows = rows, tiles = tiles, objective = objective or { type = "killAll" } }
end

local function unit(charOrId, x, y)
    local char = type(charOrId) == "string" and Character.instantiate(charOrId) or charOrId
    return { char = char, x = x, y = y }
end

-- A bare stand-in for the unit whose life sustains a reservation; nothing reads it but identity.
local function holder() return { alive = true } end

return {
    {
        name = "reserving lowers the ceiling and clamps current, but never touches max",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("mage", 1, 1) }, { unit("bandit", 8, 8) })
            local mage = c.units[1]
            local mana = mage.char.stats.mana
            local max = mana.max
            assert(mana.current == max, "starts full")

            Combat.reserve(mage.char, "mana", 10, holder())
            assert(mana.max == max, "max is untouched by a reservation")
            assert(Combat.reservedAmount(mage.char, "mana") == 10, "the reservation is recorded")
            assert(Combat.unreservedMax(mage.char, "mana") == max - 10, "the ceiling drops by the reservation")
            assert(mana.current == max - 10, "current is clamped down to the new ceiling")
        end,
    },
    {
        name = "a reservation below current only lowers the ceiling; it doesn't take what isn't there",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("mage", 1, 1) }, { unit("bandit", 8, 8) })
            local mage = c.units[1]
            local mana = mage.char.stats.mana
            mana.current = 12 -- spent most of the pool already

            Combat.reserve(mage.char, "mana", 10, holder())
            assert(Combat.unreservedMax(mage.char, "mana") == mana.max - 10, "the ceiling still drops")
            assert(mana.current == 12, "current sits below the ceiling, so nothing is taken")
        end,
    },
    {
        name = "restoreResource and applyHeal stop at the reserved ceiling, not at max",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("knight", 1, 1) }, { unit("bandit", 8, 8) })
            local knight = c.units[1]
            local hp = knight.char.stats.health
            local ceiling = hp.max - 30

            Combat.reserve(knight.char, "health", 30, holder())
            assert(hp.current == ceiling, "reserving health costs you that life outright")

            hp.current = ceiling - 10
            assert(Combat.applyHeal(c, knight, 999) == 10, "a heal tops out at the ceiling")
            assert(hp.current == ceiling, "and never climbs past it")

            local st = knight.char.stats.stamina
            Combat.reserve(knight.char, "stamina", 20, holder())
            st.current = 0
            local restored = Combat.restoreResource(knight.char, "stamina", 999)
            assert(restored == st.max - 20, "restore fills only the unreserved share")
            assert(st.current == st.max - 20, "and clamps at the ceiling")
        end,
    },
    {
        name = "regen still fills to the ceiling once a reservation is active",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("knight", 1, 1) }, { unit("bandit", 8, 8) })
            local knight = c.units[1]
            local st = knight.char.stats.stamina
            Combat.reserve(knight.char, "stamina", 20, holder())
            st.current = 0

            Combat.regenerate(c, 100) -- far more ticks than needed to top out
            assert(st.current == st.max - 20, "regen respects the ceiling")
            assert(st.max == knight.char.stats.stamina.max, "and leaves max alone, so %-of-max math is unaffected")
        end,
    },
    {
        name = "canReserve demands you actually hold the resource, and never lets a health reserve kill",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("mage", 1, 1) }, { unit("bandit", 8, 8) })
            local mage = c.units[1]
            mage.char.stats.mana.current = 5

            assert(Combat.canReserve(mage.char, "mana", 5), "exactly enough is enough")
            assert(not Combat.canReserve(mage.char, "mana", 6), "you can't commit mana you don't have")

            local hp = mage.char.stats.health
            hp.current = 20
            assert(Combat.canReserve(mage.char, "health", 19), "leaving 1 life is allowed")
            assert(not Combat.canReserve(mage.char, "health", 20), "reserving your last life is not")
        end,
    },
    {
        name = "releaseHeldBy frees a dead holder's reservation and restores the ceiling",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("mage", 1, 1) }, { unit("bandit", 8, 8) })
            local mage = c.units[1]
            local mana = mage.char.stats.mana
            local wolf = holder()

            Combat.reserve(mage.char, "mana", 10, wolf)
            assert(Combat.unreservedMax(mage.char, "mana") == mana.max - 10, "committed")

            Combat.releaseHeldBy(c, wolf)
            assert(Combat.reservedAmount(mage.char, "mana") == 0, "the reservation is gone")
            assert(Combat.unreservedMax(mage.char, "mana") == mana.max, "the ceiling is whole again")
            assert(mana.current == mana.max - 10, "but the mana it cost is not refunded")
        end,
    },
    {
        name = "a stale reservation never survives into the next battle",
        fn = function()
            local mage = Character.instantiate("mage")
            Combat.reserve(mage, "mana", 10, holder())
            assert(Combat.reservedAmount(mage, "mana") == 10, "reserved before the battle")

            local c = Combat.new(arena(8, 8), { unit(mage, 1, 1) }, { unit("bandit", 8, 8) })
            assert(Combat.reservedAmount(mage, "mana") == 0, "battle setup clears it (its summon is long gone)")
            local st = c.units[1].char.stats.stamina
            assert(st.current == st.max, "so the stamina refill still reaches a full max")
        end,
    },
    {
        name = "abilityCost applies a status cost multiplier; abilityReserve does not",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("mage", 1, 1) }, { unit("bandit", 8, 8) })
            local mage = c.units[1]
            local ab = { cost = { stat = "mana", amount = 12 }, reserve = { stat = "mana", percent = 0.25 } }

            assert(Combat.abilityCost(mage, ab).amount == 12, "unmodified cost")
            local max = mage.char.stats.mana.max
            assert(Combat.abilityReserve(mage, ab).amount == math.floor(max * 0.25), "reserve is a share of max")

            Status.apply(c, mage, "hasted")
            assert(Combat.abilityCost(mage, ab).amount == 6, "a cost multiplier halves the price")
            assert(Combat.abilityReserve(mage, ab).amount == math.floor(max * 0.25),
                "a reservation is committed, not paid -- the multiplier must not touch it")
        end,
    },
    {
        name = "a previewed heal respects the reserved ceiling, exactly like the real one",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("priest", 1, 1), unit("knight", 2, 1) },
                { unit("bandit", 8, 8) })
            local priest, knight = c.units[1], c.units[2]
            Character.addItem(priest.char, Item.instantiate("ability_heal"))

            local hp = knight.char.stats.health
            Combat.reserve(knight.char, "health", 40, holder())
            hp.current = hp.max - 45 -- 5 below the ceiling

            local heal
            for _, it in ipairs(Character.eachItem(priest.char)) do
                if it.id == "ability_heal" then heal = it end
            end
            local preview = Combat.previewAbility(c, priest, heal, knight.x, knight.y)
            local predicted = preview.entries[knight].heal

            local healed = Combat.applyHeal(c, knight, 999)
            assert(healed == 5, "the real heal stops at the ceiling")
            assert(predicted == healed,
                "and the preview said so (predicted " .. predicted .. ", got " .. healed .. ")")
        end,
    },
    {
        name = "canAfford refuses an ability whose reservation cannot be committed",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("mage", 1, 1) }, { unit("bandit", 8, 8) })
            local mage = c.units[1]
            local ab = { reserve = { stat = "mana", percent = 0.25 } }
            assert(Combat.canAfford(mage, ab), "a full pool can commit a quarter of itself")

            mage.char.stats.mana.current = 1
            assert(not Combat.canAfford(mage, ab), "an empty pool has nothing to set aside")
        end,
    },
}
