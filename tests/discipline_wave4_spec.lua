-- S5 (single-target dispel) and S3 (fuses), with the Inquisitor and Saboteur shelves built on them.
--
-- The two system claims worth pinning:
--   * Combat.dispelUnit takes BLESSINGS off one body and leaves the engine's own markers alone -- it
--     must never become a silent counterspell, which is the power S5 gave up when it shrank.
--   * a charge is DATA, never a closure: it survives models/state_hash.lua, which is the constraint
--     that shaped the whole fuse system.

local Combat = require("models.combat")
local Status = require("models.status")
local StateHash = require("models.state_hash")
local Fixture = require("tests.support.fixture")

return {
    -- S5 --------------------------------------------------------------------------------------------
    {
        name = "dispelUnit strips blessings, spares afflictions, and never touches a channel",
        fn = function()
            local map = Fixture.new(10, 10)
            local hero = Fixture.unit("character_amana", 3, 3, { isolate = "bare" })
            local foe = Fixture.unit("character_bandit", 3, 4, { isolate = "bare", stats = { health = 300 } })
            local combat = Fixture.combat(map, hero, foe)
            local f = combat.units[2]

            Status.apply(combat, f, "status_inspiration")
            Status.apply(combat, f, "status_aegis")
            Status.apply(combat, f, "status_poison")
            Status.apply(combat, f, "status_channeling")

            local taken = Combat.dispelUnit(combat, f)
            assert(#taken == 2, "two blessings come off")
            assert(not Status.has(f, "status_inspiration"), "the inspiration is gone")
            assert(not Status.has(f, "status_aegis"), "and the ward")
            assert(Status.has(f, "status_poison"), "the poison is left where it is -- this is not a Cure")
            assert(Status.has(f, "status_channeling"),
                "and the wind-up is untouched: S5 gave up being a counterspell")
        end,
    },
    {
        name = "dispelUnit honours a cap, so an ability can take exactly one",
        fn = function()
            local map = Fixture.new(10, 10)
            local hero = Fixture.unit("character_clem", 3, 3, { isolate = "bare" })
            local foe = Fixture.unit("character_bandit", 3, 4, { isolate = "bare", stats = { health = 300 } })
            local combat = Fixture.combat(map, hero, foe)
            local f = combat.units[2]

            Status.apply(combat, f, "status_inspiration")
            Status.apply(combat, f, "status_aegis")
            assert(#Combat.dispelUnit(combat, f, 1) == 1, "one is taken")
            assert(#Combat.dispelUnit(combat, f, 1) == 1, "and the other is still there to take")
        end,
    },

    -- INQUISITOR ------------------------------------------------------------------------------------
    {
        name = "Sentence strips the accused before it burns them, and declines the unaccused",
        fn = function()
            local map = Fixture.new(10, 10)
            local hero = Fixture.unit("character_amana", 3, 3,
                { isolate = "bare", items = { "ability_sentence" } })
            local foe = Fixture.unit("character_bandit", 3, 4,
                { isolate = "bare", stats = { defense = 0, magicDefense = 0, health = 900 } })
            local combat = Fixture.combat(map, hero, foe)
            local h, f = combat.units[1], combat.units[2]
            h.char.stats.mana.max, h.char.stats.mana.current = 999, 999

            Status.apply(combat, f, "status_aegis")
            local hp = f.char.stats.health.current
            Fixture.strike(combat, h, f, "ability_sentence")
            assert(f.char.stats.health.current == hp, "sentence cannot be passed on the unaccused")
            assert(Status.has(f, "status_aegis"), "and nothing is taken from them")

            h.char.stats.mana.current = 999
            Status.apply(combat, f, "status_mark")
            assert(Fixture.strike(combat, h, f, "ability_sentence"), "the accused is sentenced")
            assert(not Status.has(f, "status_aegis"), "the ward comes off first")
            assert(f.char.stats.health.current < hp, "and then the fire")
        end,
    },
    {
        name = "The Question moves a blessing across rather than destroying it",
        fn = function()
            local map = Fixture.new(10, 10)
            local hero = Fixture.unit("character_clem", 3, 3,
                { isolate = "bare", items = { "ability_the_question" } })
            local foe = Fixture.unit("character_bandit", 3, 4,
                { isolate = "bare", stats = { health = 300 } })
            local combat = Fixture.combat(map, hero, foe)
            local h, f = combat.units[1], combat.units[2]
            h.char.stats.stamina.max, h.char.stats.stamina.current = 99, 99

            Status.apply(combat, f, "status_mark")
            Status.apply(combat, f, "status_inspiration")
            assert(Fixture.strike(combat, h, f, "ability_the_question"), "the question is put")
            assert(not Status.has(f, "status_inspiration"), "they no longer have it")
            assert(Status.has(h, "status_inspiration"),
                "the inquisitor does -- the Cathedral burns heresy, the Undercroft finds a use for it")
        end,
    },
    {
        name = "The Pyre collects on every accusation at once and leaves the marks standing",
        fn = function()
            local map = Fixture.new(12, 12)
            local hero = Fixture.unit("character_amana", 3, 3,
                { isolate = "bare", items = { "ability_the_pyre" } })
            local a = Fixture.unit("character_bandit", 8, 3,
                { isolate = "bare", stats = { defense = 0, magicDefense = 0, health = 300 } })
            local b = Fixture.unit("character_bandit", 3, 9,
                { isolate = "bare", stats = { defense = 0, magicDefense = 0, health = 300 } })
            local c = Fixture.unit("character_bandit", 9, 9,
                { isolate = "bare", stats = { defense = 0, magicDefense = 0, health = 300 } })
            local combat = Combat.new(map, { hero }, { a, b, c })
            local h, u1, u2, u3 = combat.units[1], combat.units[2], combat.units[3], combat.units[4]
            h.char.stats.mana.max, h.char.stats.mana.current = 999, 999

            Status.apply(combat, u1, "status_mark")
            Status.apply(combat, u2, "status_mark")
            local hp1, hp2, hp3 = u1.char.stats.health.current, u2.char.stats.health.current,
                u3.char.stats.health.current

            assert(Fixture.strike(combat, h, h, "ability_the_pyre"), "the pyre is lit")
            assert(u1.char.stats.health.current < hp1, "the accused across the field burns")
            assert(u2.char.stats.health.current < hp2, "and the other one")
            assert(u3.char.stats.health.current == hp3, "the unaccused does not")
            assert(Status.has(u1, "status_mark"),
                "and the marks stand -- the Pyre and Sentence share a setup rather than competing for it")
        end,
    },

    -- S3 --------------------------------------------------------------------------------------------
    {
        name = "a charge counts down in its owner's turns and goes off at zero",
        fn = function()
            local map = Fixture.new(10, 10)
            local hero = Fixture.unit("character_clem", 3, 3, { isolate = "bare" })
            local foe = Fixture.unit("character_bandit", 6, 3,
                { isolate = "bare", stats = { defense = 0, health = 300 } })
            local combat = Fixture.combat(map, hero, foe)
            local h, f = combat.units[1], combat.units[2]

            Combat.plantCharge(combat, h, 6, 3, { fuse = 2, amount = 20 })
            local hp = f.char.stats.health.current

            Combat.tickCharges(combat, h)
            assert(f.char.stats.health.current == hp, "one turn on, the fuse is still burning")
            Combat.tickCharges(combat, h)
            assert(f.char.stats.health.current < hp, "two turns on, it is not")
            assert(#(combat.charges or {}) == 0, "and the spent charge is swept off the board")
        end,
    },
    {
        name = "a charge is data, so the board hash sees it",
        fn = function()
            local map = Fixture.new(10, 10)
            local hero = Fixture.unit("character_clem", 3, 3, { isolate = "bare" })
            local foe = Fixture.unit("character_bandit", 6, 3, { isolate = "bare" })
            local combat = Fixture.combat(map, hero, foe)
            local h = combat.units[1]

            local before = StateHash.of(combat)
            Combat.plantCharge(combat, h, 6, 3, { fuse = 2 })
            local after = StateHash.of(combat)
            assert(before ~= after,
                "a peer whose fuse is burning has diverged from one whose is not -- which is the whole "
                .. "reason a charge is six numbers and never a closure")
        end,
    },

    -- SABOTEUR --------------------------------------------------------------------------------------
    {
        name = "the Sapper's Line buries three charges and the Detonator stops the waiting",
        fn = function()
            local map = Fixture.new(12, 12)
            local hero = Fixture.unit("character_clem", 3, 3, { isolate = "bare", items = {
                "consumable_sappers_line", "ability_detonator",
            } })
            local foe = Fixture.unit("character_bandit", 5, 3,
                { isolate = "bare", stats = { defense = 0, health = 400 } })
            local combat = Fixture.combat(map, hero, foe)
            local h, f = combat.units[1], combat.units[2]
            h.char.stats.stamina.max, h.char.stats.stamina.current = 99, 99

            -- Aimed at the tile BESIDE the bandit: the blast has a radius, so a line laid across an
            -- approach catches what is standing on the approach.
            assert(Fixture.strike(combat, h, { x = 5, y = 4 }, "consumable_sappers_line"), "the line goes in")
            assert(#(combat.charges or {}) == 3, "three charges are in the ground")

            local hp = f.char.stats.health.current
            h.char.stats.stamina.current = 99
            assert(Fixture.strike(combat, h, h, "ability_detonator"), "the plunger goes down")
            assert(f.char.stats.health.current < hp, "and the fuse stops mattering")
            assert(#(combat.charges or {}) == 0, "every charge is spent")
        end,
    },
    {
        name = "the Detonator only ever sets off the saboteur's own charges",
        fn = function()
            local map = Fixture.new(12, 12)
            local hero = Fixture.unit("character_clem", 2, 2,
                { isolate = "bare", items = { "ability_detonator" } })
            local other = Fixture.unit("character_clem", 2, 3, { isolate = "bare" })
            local foe = Fixture.unit("character_bandit", 8, 8, { isolate = "bare" })
            local combat = Combat.new(map, { hero, other }, { foe })
            local h, o = combat.units[1], combat.units[2]
            h.char.stats.stamina.max, h.char.stats.stamina.current = 99, 99

            Combat.plantCharge(combat, h, 6, 6, { fuse = 5 })
            Combat.plantCharge(combat, o, 7, 7, { fuse = 5 })
            assert(#combat.charges == 2, "two saboteurs, two charges")

            assert(Fixture.strike(combat, h, h, "ability_detonator"), "one of them fires")
            assert(#combat.charges == 1, "and the other's is still in the ground")
        end,
    },
    {
        name = "Bring It Down refuses bare ground and churns what it demolishes",
        fn = function()
            local map = Fixture.new(12, 12)
            local hero = Fixture.unit("character_ren", 3, 3,
                { isolate = "bare", items = { "ability_bring_it_down" } })
            local foe = Fixture.unit("character_bandit", 9, 9, { isolate = "bare" })
            local combat = Fixture.combat(map, hero, foe)
            local h = combat.units[1]
            h.char.stats.mana.max, h.char.stats.mana.current = 999, 999

            local Hazard = require("models.hazard")
            Fixture.strike(combat, h, { x = 5, y = 3 }, "ability_bring_it_down")
            assert(not Hazard.at(combat, 5, 3, "hazard_quicksand"),
                "a demolition needs something to demolish")
        end,
    },
}
