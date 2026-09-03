-- Accuracy: whether the blow lands, and how badly.
--
-- THIS IS THE ONE SPEC THAT TURNS THE DICE ON. tests/runner.lua pins Combat.FORCE_HIT before every
-- case in the suite, because ~2600 other cases are about what an ability DOES and would otherwise
-- flake on a hit roll none of them mentions. That pinning is also a trap: with it left alone, the
-- entire accuracy system would sit outside the reachable domain of the suite and every assertion
-- about it would be green for the wrong reason. So each case below clears the flag first, and the
-- last case proves the flag itself still works -- otherwise a future edit could neutralise the whole
-- feature and the suite would applaud.
--
-- The arithmetic under test (models/combat.lua's ACCURACY section, docs/accuracy.md):
--
--   Hit   = weapon hit + skill*2 + luck/2
--   Avoid = speed*2 + luck + terrain
--   Crit  = weapon crit + skill/2
--   Dodge = luck
--
-- Pure logic, runs headless.

local Combat = require("models.combat")
local Item = require("models.item")
local Status = require("models.status")
local Fixture = require("tests.support.fixture")

-- Every case rolls for real. Called at the top of each rather than once at the top of the file:
-- the runner re-pins the flag before each case, so a file-level assignment would be overwritten.
local function live()
    Combat.FORCE_HIT = false
end

-- A board with two bodies whose accuracy stats are dictated rather than inherited, so a case asserts
-- arithmetic instead of asserting what some blueprint happens to be authored at today.
-- `tiles` lays terrain patches under the defender (Fixture.new copies them over the default floor).
local function duel(attacker, defender, tiles)
    local map = Fixture.new(8, 8, { tiles = tiles })
    local hero = Fixture.unit("character_rowan", 2, 2,
        { isolate = "bare", items = { "weapon_iron_sword" }, stats = attacker })
    local foe = Fixture.unit("character_bandit", 2, 3,
        { isolate = "bare", stats = defender })
    local combat = Fixture.combat(map, hero, foe)
    local a, d = combat.units[1], combat.units[2]
    return combat, a, d, Fixture.itemNamed(a.char, "weapon_iron_sword")
end

return {
    {
        name = "hit chance is the weapon's hit plus the swinger's skill, less what the target avoids",
        fn = function()
            live()
            -- Iron sword: family `sword`, so Item.FAMILY_HIT 90 unless the item overrides it.
            local _, _, _, sword = duel({}, {})
            local base = Item.hit(sword)

            -- skill 5, luck 0 -> Hit = base + 10. Defender speed 0, luck 0 -> Avoid = 0.
            local c, a, d, item = duel({ skill = 5, luck = 0 }, { speed = 0, luck = 0 })
            assert(Combat.hitChance(c, a, d, item) == math.min(100, base + 10),
                "skill should be worth two points of Hit each")

            -- Defender speed 4, luck 6 -> Avoid = 8 + 6 = 14.
            local c2, a2, d2, item2 = duel({ skill = 0, luck = 0 }, { speed = 4, luck = 6 })
            assert(Combat.avoid(c2, d2) == 14, "Avoid is speed*2 + luck, got " .. Combat.avoid(c2, d2))
            assert(Combat.hitChance(c2, a2, d2, item2) == base - 14,
                "avoid subtracts from the swing's hit")
        end,
    },
    {
        -- The lever that replaces facing. Fire Emblem has no direction, so the positional decision it
        -- offers is which tile you stand on -- and this is the assertion that makes ground a decision
        -- rather than scenery.
        name = "the ground under the defender is worth as much as the gap between two weapons",
        fn = function()
            live()
            local stats = { speed = 0, luck = 0 }
            local plain, a, d, item = duel({ skill = 0, luck = 0 }, stats)
            local onOpen = Combat.hitChance(plain, a, d, item)

            local c, a2, d2, item2 = duel({ skill = 0, luck = 0 }, stats,
                { { x = 2, y = 3, type = "forest", bonus = { avoid = 20 } } })
            assert(Combat.terrainAvoid(c, 2, 3) == 20, "the forest patch should be worth 20 avoid")
            assert(Combat.hitChance(c, a2, d2, item2) == onOpen - 20,
                "standing in cover should cost the attacker exactly the tile's avoid")

            -- And the mire is the inverse: the one floor that makes a body easier to hit.
            local m, a3, d3, item3 = duel({ skill = 0, luck = 0 }, stats,
                { { x = 2, y = 3, type = "mire", bonus = { avoid = -10 } } })
            assert(Combat.hitChance(m, a3, d3, item3) == onOpen + 10,
                "a bogged body should be easier to hit than one on open ground")
        end,
    },
    {
        name = "crit chance is the weapon's crit plus half the swinger's skill, less the target's luck",
        fn = function()
            live()
            local c, a, d, item = duel({ skill = 8, luck = 0 }, { speed = 0, luck = 0 })
            local expected = Item.crit(item) + 4
            assert(Combat.critChance(c, a, d, item) == expected,
                "skill should be worth half a point of Crit each, expected " .. expected)

            -- Luck does double duty: it raised Avoid above, and here it subtracts from crit outright.
            local c2, a2, d2, item2 = duel({ skill = 8, luck = 0 }, { speed = 0, luck = 30 })
            assert(Combat.critChance(c2, a2, d2, item2) == 0,
                "a lucky body is not especially hard to hit, but it is hard to hit badly")
        end,
    },
    {
        name = "a certain blow lands, an impossible one never does, and neither consumes a draw",
        fn = function()
            live()
            local c = Fixture.combat(Fixture.new(8, 8, { seed = 4242 }))
            local before = Combat.roll(c, 1000)
            assert(Combat.trueHit(c, 100), "100% must always land")
            assert(not Combat.trueHit(c, 0), "0% must never land")
            -- The two short-circuits above return before touching the generator, so the very next
            -- draw is the one that would have come next anyway. This is not tidiness: the draw CURSOR
            -- is hashed state, and a branch that spent draws only sometimes would desync two peers
            -- who disagreed about whether a blow was ever in doubt.
            local c2 = Fixture.combat(Fixture.new(8, 8, { seed = 4242 }))
            local firstAgain = Combat.roll(c2, 1000)
            assert(before == firstAgain, "one seed, one first draw")
            local after = Combat.roll(c, 1000)
            local expected = Combat.roll(c2, 1000)
            assert(after == expected, "a certain and an impossible roll must both cost zero draws")
        end,
    },
    {
        -- Fire Emblem's true hit, and the one place the model deliberately lies. A shown 75% should
        -- land appreciably more than 75% of the time; a shown 25% appreciably less.
        name = "two averaged draws bend the real odds toward what the number claims",
        fn = function()
            live()
            local function rate(chance, seed)
                local c = Fixture.combat(Fixture.new(8, 8, { seed = seed }))
                local hits = 0
                for _ = 1, 4000 do
                    if Combat.trueHit(c, chance) then hits = hits + 1 end
                end
                return hits / 4000 * 100
            end
            local high = rate(75, 991)
            local low = rate(25, 991)
            assert(high > 80, "a shown 75% should land well above 75%, got " .. string.format("%.1f", high))
            assert(low < 20, "a shown 25% should land well below 25%, got " .. string.format("%.1f", low))
            -- Symmetric about the middle: what the high end gains, the low end loses.
            local mid = rate(50, 991)
            assert(mid > 44 and mid < 56, "50% is the fixed point, got " .. string.format("%.1f", mid))
        end,
    },
    {
        name = "a miss deals nothing, applies nothing, and banks nothing",
        fn = function()
            live()
            -- Avoid far beyond any weapon's reach, so the blow cannot land.
            local c, a, d, sword = duel({ skill = 0, luck = 0 }, { speed = 90, luck = 0, health = 200 })
            assert(Combat.hitChance(c, a, d, sword) == 0, "this defender must be unhittable")

            local hp = Fixture.hp(d)
            local dealt = Combat.dealDamage(c, a, d, sword, {})
            assert(dealt == 0, "a miss deals no damage, got " .. dealt)
            assert(Fixture.hp(d) == hp, "and takes nothing off the body")
            -- The whole point of routing a miss through the voided-hit path: every downstream tally
            -- keys off `dealt > 0`, so none of them fires.
            assert(Combat.tallyCount(a, "hitDealt") == 0, "a whiff is not a hit dealt")
            assert(Combat.tallyCount(a, "damageDealt") == 0, "nor damage dealt")
            assert(Combat.tallyCount(d, "hitTaken") == 0, "and the target took nothing")
            assert(a.streakTarget == nil, "a miss starts no same-target streak")
        end,
    },
    {
        name = "a critical multiplies what armour left, not what the arm swung",
        fn = function()
            live()
            local c, a, d, sword = duel({ skill = 0, luck = 0 }, { speed = 0, luck = 0, health = 400, defense = 5 })
            local plain = Combat.computeDamage(c, a, d, sword, {})
            assert(plain > 0, "the fixture must land a real wound to multiply")

            local hp = Fixture.hp(d)
            Combat.dealDamage(c, a, d, sword, { critical = true })
            local taken = hp - Fixture.hp(d)
            assert(taken == plain * Combat.CRIT_MULTIPLIER,
                "a crit should be the mitigated wound times " .. Combat.CRIT_MULTIPLIER
                    .. ", expected " .. (plain * Combat.CRIT_MULTIPLIER) .. " got " .. taken)
            -- Tripling the PRE-mitigation power would have blown through the armour instead; this is
            -- the assertion that keeps armour meaning what it means against a crit.
            assert(taken < (plain + 5) * Combat.CRIT_MULTIPLIER,
                "the defence must still be subtracted before the multiply")
        end,
    },
    {
        name = "nothing without an attacker rolls, and an ability may opt out",
        fn = function()
            live()
            local c, a, d, sword = duel({}, { speed = 90 })
            -- A trap, a burn tick and a hazard all reach the damage path with no attacker at all.
            assert(not Combat.rollsToHit(c, nil, d, sword), "a source with no body behind it never misses")
            assert(not Combat.rollsToHit(c, a, nil, sword), "and neither does one with no target")
            assert(not Combat.rollsToHit(c, a, a, sword), "a bomb under your own feet does not miss")
            -- The flat path is the one traps use, and it must be untouched by any of this.
            local hp = Fixture.hp(d)
            local flat = Combat.dealFlatDamage(c, d, 10, {}, "a spike pit")
            assert(flat > 0 and Fixture.hp(d) < hp, "a trap on an undodgeable body still bites")

            local certain = { activeAbility = { alwaysHits = true, damage = 5 }, tags = { "sword" } }
            assert(not Combat.rollsToHit(c, a, d, certain), "alwaysHits opts a signature out of the dice")
            assert(Combat.hitChance(c, a, d, certain) == 100, "and reads as certain")
            assert(Combat.critChance(c, a, d, certain) == 0, "a blow that cannot miss cannot crit either")
        end,
    },
    {
        name = "a weapon's family sets its hit and crit, and the weapon itself outranks the family",
        fn = function()
            live()
            local dagger = { tags = { "dagger" } }
            local hammer = { tags = { "hammer" } }
            assert(Item.hit(dagger) == Item.FAMILY_HIT.dagger, "a dagger takes its family's hit")
            assert(Item.hit(dagger) > Item.hit(hammer), "a dagger lands more readily than a hammer")
            assert(Item.crit(dagger) > Item.crit(hammer), "and finds a gap more often")

            local killer = { tags = { "dagger" }, hit = 70, crit = 30 }
            assert(Item.hit(killer) == 70 and Item.crit(killer) == 30,
                "an authored hit/crit outranks the family default -- this is how a killer edge is built")

            -- Every family answers, so an unanswered one is an authoring slip rather than a gap.
            for family in pairs(Item.ARCHETYPES) do
                assert(Item.FAMILY_HIT[family], "family '" .. family .. "' declares no hit")
                assert(Item.FAMILY_CRIT[family], "family '" .. family .. "' declares no crit")
            end
        end,
    },
    {
        -- THE CHAIN, END TO END: a charm in the grid reaches the hit roll.
        --
        -- Worth its own case because every link in it is somebody else's code and none of them was
        -- written with these stats in mind -- Combat.applyUnitPassives folds `item.bonus` into
        -- unit.bonus, flatStat sums it, and Combat.hitChance reads flatStat. The stats were designed to
        -- ride that path precisely so no new plumbing was needed, which is exactly the kind of claim
        -- that is true right up until it silently isn't.
        name = "a charm's skill and luck reach the hit roll from the grid",
        fn = function()
            live()
            -- Marksman's Lens grants skill; the Opportunist's Charm grants luck.
            local map = Fixture.new(8, 8)
            local hero = Fixture.unit("character_rowan", 2, 2,
                { isolate = "bare", items = { "weapon_iron_sword" }, stats = { skill = 0, luck = 0 } })
            local foe = Fixture.unit("character_bandit", 2, 3,
                { isolate = "bare", stats = { speed = 0, luck = 0 } })
            local c = Fixture.combat(map, hero, foe)
            local a, d = c.units[1], c.units[2]
            local sword = Fixture.itemNamed(a.char, "weapon_iron_sword")
            local bare = Combat.hitChance(c, a, d, sword)

            local lensMap = Fixture.new(8, 8)
            local lensHero = Fixture.unit("character_rowan", 2, 2,
                { isolate = "bare", items = { "weapon_iron_sword", "utility_marksmans_lens" },
                  stats = { skill = 0, luck = 0 } })
            local lensFoe = Fixture.unit("character_bandit", 2, 3,
                { isolate = "bare", stats = { speed = 0, luck = 0 } })
            local lc = Fixture.combat(lensMap, lensHero, lensFoe)
            local la, ld = lc.units[1], lc.units[2]
            local lensed = Combat.hitChance(lc, la, ld, Fixture.itemNamed(la.char, "weapon_iron_sword"))
            assert(lensed > bare,
                "the Marksman's Lens must raise hit chance -- " .. bare .. " -> " .. lensed)

            -- ...and luck on the DEFENDER lowers it, which is the other direction through the same path.
            local charmMap = Fixture.new(8, 8)
            local charmHero = Fixture.unit("character_rowan", 2, 2,
                { isolate = "bare", items = { "weapon_iron_sword" }, stats = { skill = 0, luck = 0 } })
            local charmFoe = Fixture.unit("character_bandit", 2, 3,
                { isolate = "bare", items = { "utility_opportunists_charm" },
                  stats = { speed = 0, luck = 0 } })
            local cc = Fixture.combat(charmMap, charmHero, charmFoe)
            local ca, cd = cc.units[1], cc.units[2]
            local charmed = Combat.hitChance(cc, ca, cd, Fixture.itemNamed(ca.char, "weapon_iron_sword"))
            assert(charmed < bare,
                "the Opportunist's Charm must lower an attacker's hit chance -- " .. bare .. " -> " .. charmed)
        end,
    },
    {
        -- The status half of the same claim. Four statuses now move accuracy and each is a different
        -- direction through a different sign, so a single one passing proves very little.
        name = "the four accuracy statuses each move the roll the way they read",
        fn = function()
            live()
            local c, a, d, sword = duel({ skill = 4, luck = 0 }, { speed = 0, luck = 4 })
            local baseHit = Combat.hitChance(c, a, d, sword)
            local baseCrit = Combat.critChance(c, a, d, sword)

            -- Blessing steadies the attacker's hand; Blind ruins it. Each on its own fresh board, so a
            -- status that failed to lift cannot be masked by one still standing from the line above.
            Status.apply(c, a, "status_blessing")
            assert(Combat.hitChance(c, a, d, sword) > baseHit, "Blessing must raise the blessed body's aim")

            local c2, a2, d2, sword2 = duel({ skill = 4, luck = 0 }, { speed = 0, luck = 4 })
            Status.apply(c2, a2, "status_blind")
            assert(Combat.hitChance(c2, a2, d2, sword2) < baseHit, "Blind must cut the blinded body's aim")

            -- Aegis makes the target luckier: harder to hit AND much harder to crit.
            local c3, a3, d3, sword3 = duel({ skill = 4, luck = 0 }, { speed = 0, luck = 4 })
            Status.apply(c3, d3, "status_aegis")
            assert(Combat.hitChance(c3, a3, d3, sword3) < baseHit, "Aegis must lower an attacker's hit chance")
            assert(Combat.critChance(c3, a3, d3, sword3) < baseCrit, "and blunt their crit")

            -- Mark does the opposite, which is what "painted for the kill" was always claiming.
            local c4, a4, d4, sword4 = duel({ skill = 4, luck = 0 }, { speed = 0, luck = 4 })
            Status.apply(c4, d4, "status_mark")
            assert(Combat.hitChance(c4, a4, d4, sword4) > baseHit, "Mark must make a body easier to hit")
            assert(Combat.critChance(c4, a4, d4, sword4) > baseCrit, "and easier to crit")
        end,
    },
    {
        -- The tripwire. tests/runner.lua leans on this flag for the whole suite; if it ever stopped
        -- working, ~2600 cases would quietly start rolling dice and this file would be the only one
        -- that noticed.
        name = "the deterministic switch restores the game this used to be",
        fn = function()
            live()
            local c, a, d, sword = duel({ skill = 0, luck = 0 }, { speed = 90, luck = 0, health = 200 })
            assert(Combat.hitChance(c, a, d, sword) == 0, "unhittable with the dice live")

            Combat.FORCE_HIT = true
            assert(Combat.hitChance(c, a, d, sword) == 100, "pinned, every aimed blow connects")
            assert(Combat.critChance(c, a, d, sword) == 0, "and none of them crits")
            local hp = Fixture.hp(d)
            local dealt = Combat.dealDamage(c, a, d, sword, {})
            assert(dealt > 0 and Fixture.hp(d) < hp, "so the blow lands for real")
        end,
    },
}
