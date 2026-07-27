-- Counter/charge items (S: the `counter` contract). Two items on the shelf hold a purse they fill
-- over a fight and spend whole: the Gleaning Rod banks a charge per nearby spell, and the Reliquary
-- of Tallies banks one per comrade lost. Both declare `activeAbility.counter`, which reports what the
-- purse currently holds -- the one number the grid badge draws AND the block gate reads, so the two
-- can never disagree.
--
-- The rule this pins: an empty purse is a refused cast, not a wasted turn. Combat.itemBlockReason
-- reports kind "empty" while the count is 0 (so the slot greys out and Combat.useItem declines), and
-- stops reporting it the moment the purse holds anything.

local Combat = require("models.combat")
local Fixture = require("tests.support.fixture")

return {
    {
        name = "an empty Reliquary of Tallies is refused, and fills as comrades fall",
        fn = function()
            local map = Fixture.new(8, 8)
            local hero = Fixture.unit("character_amana", 2, 2,
                { isolate = "bare", items = { "utility_reliquary_of_tallies" }, stats = { mana = 40 } })
            local foe = Fixture.unit("character_bandit", 2, 4, { isolate = "bare" })
            local combat = Fixture.combat(map, hero, foe)
            local h = combat.units[1]
            local reliquary = Fixture.itemNamed(h.char, "utility_reliquary_of_tallies")
            local ab = reliquary.activeAbility

            assert(ab.counter(h, reliquary) == 0, "it opens empty -- nothing owed yet")
            local blocked = Combat.itemBlockReason(h, reliquary)
            assert(blocked and blocked.kind == "empty", "an empty reliquary is refused, kind 'empty'")

            Combat.tally(h, "allyDown", 2) -- two comrades lost
            assert(ab.counter(h, reliquary) == 2, "the purse now reads the two it is owed")
            assert(Combat.itemBlockReason(h, reliquary) == nil,
                "and with the mana to pay it, the cast is no longer refused")
        end,
    },
    {
        name = "an empty Gleaning Rod is refused; a charged one is not",
        fn = function()
            local map = Fixture.new(8, 8)
            local hero = Fixture.unit("character_mage", 2, 2,
                { isolate = "bare", items = { "utility_gleaning_rod" }, stats = { mana = 40 } })
            local foe = Fixture.unit("character_bandit", 2, 4, { isolate = "bare" })
            local combat = Fixture.combat(map, hero, foe)
            local h, f = combat.units[1], combat.units[2]
            local rod = Fixture.itemNamed(h.char, "utility_gleaning_rod")
            local ab = rod.activeAbility

            assert(ab.counter(h, rod) == 0, "the rod starts dry")
            assert(Combat.itemBlockReason(h, rod).kind == "empty", "a dry rod is refused")

            -- Firing a dry rod does nothing: the gate declines it, so the target is untouched.
            local before = f.char.stats.health.current
            local ok, why = Combat.useItem(combat, h, rod, f.x, f.y)
            assert(not ok and why == "empty", "Combat.useItem declines the empty cast")
            assert(f.char.stats.health.current == before, "and the foe is untouched -- no wasted turn")

            rod.charges = 3
            assert(ab.counter(h, rod) == 3, "banked charges read straight off the item")
            assert(Combat.itemBlockReason(h, rod) == nil, "a charged rod is castable")
        end,
    },
    {
        name = "an unaffordable empty purse is told about the mana first, not the empty",
        fn = function()
            local map = Fixture.new(8, 8)
            local hero = Fixture.unit("character_amana", 2, 2,
                { isolate = "bare", items = { "utility_reliquary_of_tallies" }, stats = { mana = 0 } })
            local foe = Fixture.unit("character_bandit", 2, 4, { isolate = "bare" })
            local combat = Fixture.combat(map, hero, foe)
            local h = combat.units[1]
            local reliquary = Fixture.itemNamed(h.char, "utility_reliquary_of_tallies")

            local blocked = Combat.itemBlockReason(h, reliquary)
            assert(blocked and blocked.kind == "cost",
                "affordability is the more fixable thing, so it is reported ahead of the empty purse")
        end,
    },
}
