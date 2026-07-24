-- The CHARGE system (S1) and the nine Wave-1 items built on it: Champion's Defiance, the Duelist's
-- Tempo, the Crusader's Zeal. Chi is the same mechanism with a built-in definition and is covered by
-- tests/discipline_drafts_spec.lua, which also proves this refactor left the monk shelf alone.
--
-- The system claims worth pinning, from docs/classes.md:
--   * a pool exists only if something in the grid declares it (no charm, no pool)
--   * declarations MERGE -- `from` unions, the deeper `max` wins -- so a second charm deepens a pool
--     rather than opening a rival one called the same thing
--   * spending ALL of it clears overflow banked past the cap, leaving no hidden remainder
--   * `resetOn` forfeits a pool without paying anything out
-- Plus S2's free action, which is the other half of Wave 1's engine work.

local Combat = require("models.combat")
local Status = require("models.status")
local Fixture = require("tests.support.fixture")

return {
    -- THE SYSTEM ------------------------------------------------------------------------------------
    {
        name = "no item declares the pool, so there is no pool",
        fn = function()
            local map = Fixture.new(8, 8)
            local hero = Fixture.unit("character_saber", 2, 2, { isolate = "bare" })
            local foe = Fixture.unit("character_bandit", 2, 3, { isolate = "bare" })
            local combat = Fixture.combat(map, hero, foe)
            local h = combat.units[1]

            Combat.tally(h, "hitTaken", 5)
            assert(Combat.chargeDef(h, "defiance") == nil, "an empty grid defines no Defiance")
            assert(Combat.chargePool(h, "defiance") == 0,
                "and the tallies bank nothing without an item to bank them into")
        end,
    },
    {
        name = "a declaration opens the pool, and a second one deepens it rather than forking it",
        fn = function()
            local map = Fixture.new(8, 8)
            local hero = Fixture.unit("character_saber", 2, 2,
                { isolate = "bare", items = { "ability_defiant_stand" } })
            local foe = Fixture.unit("character_bandit", 2, 3, { isolate = "bare" })
            local combat = Fixture.combat(map, hero, foe)
            local h = combat.units[1]

            Combat.tally(h, "hitTaken", 3)
            assert(Combat.chargePool(h, "defiance") == 3, "Defiant Stand banks a blow weathered")
            Combat.tally(h, "allyStruck", 4)
            assert(Combat.chargePool(h, "defiance") == 3,
                "but a blow beside it means nothing without the charm that reads it")

            Fixture.give(h.char, "utility_crowds_favour")
            assert(Combat.chargePool(h, "defiance") == 7,
                "Crowd's Favour unions allyStruck INTO the same pool -- 3 + 4, not a second pool of 4")
            Combat.tally(h, "hitTaken", 20)
            assert(Combat.chargePool(h, "defiance") == 8,
                "and the deeper cap wins the merge (8, the charm's, not 6, the ability's)")
        end,
    },
    {
        name = "spending all of it takes the overflow too, and leaves no hidden remainder",
        fn = function()
            local map = Fixture.new(8, 8)
            local hero = Fixture.unit("character_saber", 2, 2,
                { isolate = "bare", items = { "ability_defiant_stand" } })
            local foe = Fixture.unit("character_bandit", 2, 3, { isolate = "bare" })
            local combat = Fixture.combat(map, hero, foe)
            local h = combat.units[1]

            Combat.tally(h, "hitTaken", 14) -- banked well past the cap of 6
            assert(Combat.chargePool(h, "defiance") == 6, "the pool reads its cap, not the tally")
            assert(Combat.spendCharge(h, "defiance") == 6, "spending all of it hands back the capped figure")
            assert(Combat.chargePool(h, "defiance") == 0,
                "and the 8 points of overflow are gone with it, not waiting to refill the pool for free")
        end,
    },
    {
        name = "a partial spend takes exactly what it asked for, and never more than is there",
        fn = function()
            local map = Fixture.new(8, 8)
            local hero = Fixture.unit("character_saber", 2, 2,
                { isolate = "bare", items = { "ability_defiant_stand" } })
            local foe = Fixture.unit("character_bandit", 2, 3, { isolate = "bare" })
            local combat = Fixture.combat(map, hero, foe)
            local h = combat.units[1]

            Combat.tally(h, "hitTaken", 4)
            assert(Combat.spendCharge(h, "defiance", 3) == 3, "three is taken")
            assert(Combat.chargePool(h, "defiance") == 1, "one is left")
            assert(Combat.spendCharge(h, "defiance", 9) == 1, "and asking for nine takes only the one there is")
            assert(Combat.chargePool(h, "defiance") == 0, "leaving the pool empty rather than negative")
        end,
    },

    -- CHAMPION --------------------------------------------------------------------------------------
    {
        name = "Defiant Stand taunts the ring and banks Defiance off the blows that answer",
        fn = function()
            local map = Fixture.new(8, 8)
            local hero = Fixture.unit("character_knight", 3, 3,
                { isolate = "bare", items = { "ability_defiant_stand" } })
            local foe = Fixture.unit("character_bandit", 3, 4, { isolate = "bare" })
            local combat = Fixture.combat(map, hero, foe)
            local h, f = combat.units[1], combat.units[2]
            h.char.stats.stamina.current = 99

            assert(Fixture.strike(combat, h, h, "ability_defiant_stand"), "Defiant Stand is taken")
            assert(Status.has(f, "status_taunt"), "the adjacent foe is dragged onto the Champion")
            assert(not Status.has(h, "status_defending"),
                "and the Champion does NOT brace -- it is asking to be hit, which is what fills the pool")
        end,
    },
    {
        name = "Answering Blow spends the whole pool and scales every blow in the ring by it",
        fn = function()
            local map = Fixture.new(8, 8)
            local hero = Fixture.unit("character_knight", 3, 3,
                { isolate = "bare", items = { "ability_answering_blow", "ability_defiant_stand" } })
            local a = Fixture.unit("character_bandit", 3, 4, { isolate = "bare", stats = { defense = 0, health = 300 } })
            local b = Fixture.unit("character_bandit", 2, 3, { isolate = "bare", stats = { defense = 0, health = 300 } })
            local combat = Combat.new(map, { hero }, { a, b })
            local h, f1, f2 = combat.units[1], combat.units[2], combat.units[3]
            h.char.stats.stamina.max, h.char.stats.stamina.current = 99, 99

            Combat.tally(h, "hitTaken", 5)
            assert(Combat.chargePool(h, "defiance") == 5, "the Champion has weathered five")
            local hp1, hp2 = f1.char.stats.health.current, f2.char.stats.health.current

            assert(Fixture.strike(combat, h, h, "ability_answering_blow"), "Answering Blow lands")
            assert(Combat.chargePool(h, "defiance") == 0, "the pool is emptied by the swing")
            local d1 = hp1 - f1.char.stats.health.current
            local d2 = hp2 - f2.char.stats.health.current
            assert(d1 > 0 and d2 > 0, "both adjacent foes are caught by the ring")
            assert(d1 >= 20, "and each blow carries the 5 banked points (+4 apiece) on top of its floor")
        end,
    },

    -- DUELIST ---------------------------------------------------------------------------------------
    {
        name = "Reading the Blade banks Tempo on a held target and forfeits it the moment you look away",
        fn = function()
            local map = Fixture.new(8, 8)
            local hero = Fixture.unit("character_clem", 3, 3,
                { isolate = "bare", items = { "utility_reading_the_blade" } })
            local a = Fixture.unit("character_bandit", 3, 4, { isolate = "bare", stats = { defense = 0, health = 300 } })
            local b = Fixture.unit("character_bandit", 2, 3, { isolate = "bare", stats = { defense = 0, health = 300 } })
            local combat = Combat.new(map, { hero }, { a, b })
            local h, f1, f2 = combat.units[1], combat.units[2], combat.units[3]
            h.char.stats.stamina.max, h.char.stats.stamina.current = 99, 99
            local fists = h.char.unarmed

            assert(Fixture.strike(combat, h, f1, fists), "the first blow lands")
            assert(Combat.chargePool(h, "tempo") == 0, "one exchange is not a rhythm yet")
            h.char.stats.stamina.current = 99
            assert(Fixture.strike(combat, h, f1, fists), "the second blow lands on the same body")
            assert(Combat.chargePool(h, "tempo") == 1, "and banks the first point of Tempo")
            h.char.stats.stamina.current = 99
            assert(Fixture.strike(combat, h, f1, fists), "and again")
            assert(Combat.chargePool(h, "tempo") == 2, "two")

            h.char.stats.stamina.current = 99
            assert(Fixture.strike(combat, h, f2, fists), "then the blade finds a different throat")
            assert(Combat.chargePool(h, "tempo") == 0,
                "and the Tempo is forfeit -- resetOn targetSwitch, paid out to nobody")
        end,
    },
    {
        name = "the Main-Gauche parries, and banks Tempo for the blow it turned aside",
        fn = function()
            local map = Fixture.new(8, 8)
            local hero = Fixture.unit("character_clem", 3, 3,
                { isolate = "bare", items = { "weapon_main_gauche" } })
            local foe = Fixture.unit("character_bandit", 3, 4, { isolate = "bare", stats = { defense = 0, health = 300 } })
            local combat = Fixture.combat(map, hero, foe)
            local h, f = combat.units[1], combat.units[2]
            h.char.stats.stamina.max, h.char.stats.stamina.current = 99, 99
            f.char.stats.stamina.max, f.char.stats.stamina.current = 99, 99

            assert(Combat.chargePool(h, "tempo") == 0, "the duellist opens empty")
            assert(Fixture.strike(combat, f, h, f.char.unarmed), "the bandit swings at the off-hand blade")
            assert(Combat.tallyCount(h, "answered") >= 1, "the main-gauche answers it")
            assert(Combat.chargePool(h, "tempo") >= 1, "and the answer banks Tempo")
        end,
    },
    {
        name = "Coup Droit multiplies by the Tempo it spends, and declines a foe not bound to the duel",
        fn = function()
            local map = Fixture.new(8, 8)
            local hero = Fixture.unit("character_saber", 3, 3,
                { isolate = "bare", items = { "ability_coup_droit", "utility_reading_the_blade" } })
            local foe = Fixture.unit("character_bandit", 3, 4, { isolate = "bare", stats = { defense = 0, health = 900 } })
            local combat = Fixture.combat(map, hero, foe)
            local h, f = combat.units[1], combat.units[2]
            h.char.stats.stamina.max, h.char.stats.stamina.current = 99, 99

            -- Unbound: the thrust still lands, spends nothing, and leaves the pool alone.
            Combat.tally(h, "repeatStrike", 4)
            assert(Combat.chargePool(h, "tempo") == 4, "four points held")
            local hp = f.char.stats.health.current
            assert(Fixture.strike(combat, h, f, "ability_coup_droit"), "the thrust is thrown at an unbound foe")
            local plain = hp - f.char.stats.health.current
            assert(plain > 0, "it still lands as an ordinary blow")
            assert(Combat.chargePool(h, "tempo") == 4, "and takes no Tempo for the privilege")

            -- Bound: the same pool, multiplied.
            Status.apply(combat, f, "status_duelbound")
            h.char.stats.stamina.current = 99
            hp = f.char.stats.health.current
            assert(Fixture.strike(combat, h, f, "ability_coup_droit"), "the thrust is thrown into the duel")
            local paid = hp - f.char.stats.health.current
            -- Down to at most the single point the thrust ITSELF banked on the way out: it landed on
            -- the same body again, so repeatStrike fired after the spend. Flurry has the same rebate
            -- and documents it as deliberate -- the rhythm pays for the next exchange, it does not
            -- reset you to nothing.
            assert(Combat.chargePool(h, "tempo") <= 1, "the pool is spent, bar what the thrust rebanked")
            assert(paid > plain, "and the blow is heavier for it")
        end,
    },

    -- CRUSADER --------------------------------------------------------------------------------------
    {
        name = "the Crusader's Tabard banks Zeal from kills AND mends, with no weapon in the loop",
        fn = function()
            local map = Fixture.new(8, 8)
            local hero = Fixture.unit("character_amana", 3, 3,
                { isolate = "bare", items = { "armor_crusaders_tabard" } })
            local foe = Fixture.unit("character_bandit", 3, 5, { isolate = "bare" })
            local combat = Fixture.combat(map, hero, foe)
            local h = combat.units[1]

            assert(Combat.chargePool(h, "zeal") == 0, "the crusade opens empty")
            Combat.tally(h, "kill", 2)
            assert(Combat.chargePool(h, "zeal") == 2, "two felled")
            Combat.tally(h, "healDone", 3)
            assert(Combat.chargePool(h, "zeal") == 5,
                "and three mended bank the same coin -- R2: the pool belongs to the crusade, not to a hammer")
        end,
    },
    {
        name = "Vow of the March widens Zeal to the whole column, and deepens the pool",
        fn = function()
            local map = Fixture.new(8, 8)
            local hero = Fixture.unit("character_amana", 3, 3,
                { isolate = "bare", items = { "armor_crusaders_tabard", "utility_vow_of_the_march" } })
            local foe = Fixture.unit("character_bandit", 3, 5, { isolate = "bare" })
            local combat = Fixture.combat(map, hero, foe)
            local h = combat.units[1]

            Combat.tally(h, "foeDown", 3)   -- somebody else's kills
            Combat.tally(h, "allyMended", 2) -- somebody else's mending
            assert(Combat.chargePool(h, "zeal") == 5,
                "a priest who has personally neither killed nor healed still holds the faith")
            Combat.tally(h, "kill", 20)
            assert(Combat.chargePool(h, "zeal") == 10, "and the vow's deeper cap of 10 wins the merge")
        end,
    },
    {
        name = "Reckoning spends Zeal into one blow and mends the line beside it for what landed",
        fn = function()
            local map = Fixture.new(8, 8)
            local hero = Fixture.unit("character_saber", 3, 3,
                { isolate = "bare", items = { "ability_reckoning", "armor_crusaders_tabard" } })
            local ally = Fixture.unit("character_knight", 2, 3, { isolate = "bare" })
            local foe = Fixture.unit("character_bandit", 3, 4, { isolate = "bare", stats = { defense = 0, health = 900 } })
            local combat = Combat.new(map, { hero, ally }, { foe })
            local h, a, f = combat.units[1], combat.units[2], combat.units[3]
            h.char.stats.stamina.max, h.char.stats.stamina.current = 99, 99
            a.char.stats.health.current = 5

            Combat.tally(h, "kill", 4)
            assert(Combat.chargePool(h, "zeal") == 4, "four points of Zeal held")
            local hp = f.char.stats.health.current
            assert(Fixture.strike(combat, h, f, "ability_reckoning"), "Reckoning lands")
            local dealt = hp - f.char.stats.health.current

            -- At most the point its own mending rebanked: Reckoning heals, healDone is a Zeal source,
            -- so the crusade is credited for the mercy it just did. Deliberate, and the same rebate
            -- Flurry takes -- what must not survive is the four points it was PAID for.
            assert(Combat.chargePool(h, "zeal") <= 1, "the pool is emptied, bar what the mending rebanked")
            assert(dealt > 0, "the blow bites")
            assert(a.char.stats.health.current > 5, "and the wounded ally beside the crusader is mended by it")
        end,
    },

    -- S2: FREE ACTIONS ------------------------------------------------------------------------------
    {
        name = "a free action bills no initiative and leaves the turn open -- but only once",
        fn = function()
            local map = Fixture.new(8, 8)
            local hero = Fixture.unit("character_kaya", 3, 3, { isolate = "bare" })
            local foe = Fixture.unit("character_bandit", 3, 5, { isolate = "bare" })
            local combat = Fixture.combat(map, hero, foe)
            local h = combat.units[1]

            assert(Combat.freeActionsLeft(h) == Combat.FREE_ACTIONS_PER_TURN,
                "a fresh turn opens with the free action in hand")
            h.freeActionsUsed = Combat.FREE_ACTIONS_PER_TURN
            assert(Combat.freeActionsLeft(h) == 0, "and spending it leaves none")

            -- The counter is cleared by the turn opening, not by the turn ending: a free cast never
            -- reaches endTurn, which is the whole point of it.
            Combat.startTurn(combat)
            local current = Combat.currentUnit(combat)
            assert(current.freeActionsUsed == nil, "opening a turn refreshes the free action")
        end,
    },
}
