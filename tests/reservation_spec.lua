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
    -- Strip the innate signature relic (see tests/innate_spec.lua): the mage relic's mana ceiling
    -- would otherwise raise the pool these reservation fixtures assert exact values against.
    for i = 1, Character.MAX_INVENTORY do
        if char.inventory[i] and char.inventory[i].bound then char.inventory[i] = nil end
    end
    return { char = char, x = x, y = y }
end

-- A bare stand-in for the unit whose life sustains a reservation; nothing reads it but identity.
local function holder() return { alive = true } end

return {
    {
        name = "reserving spends the resource and lowers the ceiling, but never touches max",
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
            assert(mana.current == max - 10, "and the 10 is spent out of current")
        end,
    },
    {
        name = "a reservation is spent out of current even when the pool is far from full",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("mage", 1, 1) }, { unit("bandit", 8, 8) })
            local mage = c.units[1]
            local mana = mage.char.stats.mana
            mana.current = 12 -- spent most of the pool already

            Combat.reserve(mage.char, "mana", 10, holder())
            assert(Combat.unreservedMax(mage.char, "mana") == mana.max - 10, "the ceiling drops")
            assert(mana.current == 2, "and the 10 comes out of the 12 that was left")

            -- The 10 it locked away can never be regenerated back while the wolf lives.
            Combat.restoreResource(mage.char, "mana", 999)
            assert(mana.current == mana.max - 10, "regen refills only the unreserved share")
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
    {
        name = "an ability that both costs and reserves one pool must afford the two together",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("mage", 1, 1) }, { unit("bandit", 8, 8) })
            local mage = c.units[1]
            local mana = mage.char.stats.mana
            local ab = { cost = { stat = "mana", amount = 12 }, reserve = { stat = "mana", percent = 0.25 } }
            local reserve = math.floor(mana.max * 0.25)

            -- useItem pays the cost first, so the reservation may only draw on what it leaves behind.
            mana.current = 12 + reserve
            assert(Combat.canAfford(mage, ab), "exactly enough for the cost and the reservation")

            mana.current = 12 + reserve - 1
            assert(not Combat.canAfford(mage, ab), "covering the cost alone is not enough")
            assert(Combat.itemBlockReason(mage, { activeAbility = ab }).kind == "reserve",
                "and it is the reservation that is named as short, not the cost")
        end,
    },
    {
        name = "abilitySpend lists both the cost and the reservation, priced against the actor",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("mage", 1, 1) }, { unit("bandit", 8, 8) })
            local mage = c.units[1]
            local max = mage.char.stats.mana.max
            local ab = { cost = { stat = "mana", amount = 12 }, reserve = { stat = "mana", percent = 0.25 } }

            local spend = Combat.abilitySpend(mage, ab)
            assert(#spend == 2, "a cast that both costs and reserves takes two bites")
            assert(spend[1].kind == "cost" and spend[1].amount == 12, "the cost is taken first")
            assert(spend[2].kind == "reserve" and spend[2].amount == math.floor(max * 0.25),
                "then the reservation, a share of maximum")

            -- The hover preview must show the price the cast will actually charge, not the printed one.
            Status.apply(c, mage, "hasted")
            local hasted = Combat.abilitySpend(mage, ab)
            assert(hasted[1].amount == 6, "the cost row follows the cost multiplier")
            assert(hasted[2].amount == math.floor(max * 0.25), "the reservation row does not")
        end,
    },
    {
        name = "abilitySpend covers a summon that only reserves, and is empty for a free ability",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("mage", 1, 1) }, { unit("bandit", 8, 8) })
            local mage = c.units[1]
            local max = mage.char.stats.mana.max

            -- Summon Fire Elemental has no `cost` at all -- its whole price is the reservation, so a
            -- preview that only reads `cost` would show the player nothing being spent.
            local summon = Item.instantiate("ability_summon_fire_elemental")
            local spend = Combat.abilitySpend(mage, summon.activeAbility)
            assert(#spend == 1 and spend[1].kind == "reserve", "the reservation is the only spend")
            assert(spend[1].stat == "mana" and spend[1].amount == math.floor(max * 0.25),
                "a quarter of maximum mana")

            assert(#Combat.abilitySpend(mage, { speed = 4 }) == 0, "a free ability takes nothing")
            assert(#Combat.abilitySpend(mage, nil) == 0, "and neither does no ability at all")
        end,
    },
}
