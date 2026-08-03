-- Tests for ENEMY SCALING (models/growth.lua: combatantLevel / spawn).
--
-- Enemies and escorted allies are minted from blueprints and grown through the same tables the roster
-- uses, so the far side climbs with the company instead of staying pinned at blueprint level 1. Before
-- this, a demon grunt's blow fell to the 1-damage floor against a knight by prestige 9 and stayed there
-- for the rest of the campaign.
--
-- Everything below goes through the REAL damage pipeline (Combat.computeDamage) rather than
-- re-deriving the arithmetic, so a change to mitigation shows up here instead of being quietly
-- mirrored by a test that agrees with the old formula.

local Growth = require("models.growth")
local Character = require("models.character")
local Combat = require("models.combat")
local Item = require("models.item")
local Fixture = require("tests.support.fixture")

-- A character grown to `level` along its own class's table.
local function grown(id, level, class)
    local char = Character.instantiate(id)
    if class then char.classUse = { [class] = 1 } end
    Growth.resolve(char, level)
    return char
end

-- The heaviest attack the character actually carries, so the exchange is measured with the weapon
-- the blueprint hands it rather than an invented one.
local function weaponOf(char)
    local best, bestDmg = nil, -1
    for _, it in ipairs(Character.eachItem(char)) do
        local ab = it.activeAbility
        local dmg = ab and type(ab.damage) == "number" and ab.damage or nil
        if dmg and dmg > bestDmg then best, bestDmg = it, dmg end
    end
    return best
end

-- Hits `attacker` needs to fell `defender`, through the live combat model.
local function hitsToKill(attacker, defender)
    local map = Fixture.new(6, 6)
    local a = Fixture.unit(attacker, 1, 1)
    local d = Fixture.unit(defender, 2, 1)
    local combat = Fixture.combat(map, a, d)
    local weapon = weaponOf(attacker)
    if not weapon then return nil end
    local per = Combat.computeDamage(combat, a, d, weapon)
    if not per or per < 1 then per = 1 end
    return math.ceil(d.char.stats.health.max / per), per
end

return {
    -- ------------------------------------------------------------ the floor rule
    {
        name = "a combatant's level is the highest of its own floor, the fight's floor, and its tracking",
        fn = function()
            local lagged = function(level) return 1 + math.floor(Growth.ENEMY_LEVEL_LAG * (level - 1)) end

            local plain = {}
            assert(Growth.combatantLevel(plain, 12, nil) == lagged(12),
                "ordinary stock tracks the player at the lag, not level for level")
            assert(Growth.combatantLevel(plain, 3, 9) == 9, "a fight's floor lifts a green party's opposition")
            assert(Growth.combatantLevel(plain, 20, 9) == lagged(20),
                "and is left behind once the party passes it")

            -- The lag is what lets a grown company sit ahead of common stock. Assert the DIRECTION
            -- rather than a number, so retuning ENEMY_LEVEL_LAG moves this instead of breaking it.
            assert(Growth.combatantLevel(plain, Growth.LEVEL_CAP, nil) < Growth.LEVEL_CAP,
                "a capped company must have outgrown the ordinary stock")
            assert(Growth.combatantLevel(plain, 1, nil) == 1, "and at level 1 there is nothing to lag behind")

            -- A named unit -- anything declaring a floor of its own -- tracks exactly. This is what
            -- keeps elites and bosses dangerous while the trash becomes a victory lap.
            local elite = { floorLevel = 15 }
            assert(Growth.combatantLevel(elite, 4, nil) == 15,
                "a creature's own floor holds even in a fight that declares none")
            assert(Growth.combatantLevel(elite, 30, nil) == 30,
                "and above its floor it tracks the player level for level, unlagged")
            assert(Growth.combatantLevel(elite, 30, nil) > Growth.combatantLevel(plain, 30, nil),
                "a named unit must outrank the stock beside it")

            -- The case an implementation is most likely to fumble: two floors that disagree.
            assert(Growth.combatantLevel({ floorLevel = 15 }, 2, 8) == 15, "the higher floor wins (creature)")
            assert(Growth.combatantLevel({ floorLevel = 8 }, 2, 15) == 15, "the higher floor wins (fight)")

            -- Never past the cap, which is the range the growth tables are verified over.
            assert(Growth.combatantLevel({ floorLevel = 9999 }, 1, 9999) == Growth.LEVEL_CAP,
                "a floor above the cap clamps to it")
        end,
    },

    {
        name = "scaling = false is blueprint-exact at any player level",
        fn = function()
            local base = Character.instantiate("character_demon_grunt")
            local late = Growth.spawn("character_demon_grunt", Growth.LEVEL_CAP, Growth.LEVEL_CAP)
            assert(late.level == 1, "a pinned unit stays at level 1")
            for stat, value in pairs(base.stats) do
                if type(value) == "table" then
                    assert(late.stats[stat].max == value.max, "pinned pool " .. stat .. " moved")
                else
                    assert(late.stats[stat] == value, "pinned stat " .. stat .. " moved")
                end
            end
        end,
    },

    {
        name = "an ordinary enemy is grown to the fight's level",
        fn = function()
            local base = Character.instantiate("character_bandit")
            local late = Growth.spawn("character_bandit", 20)
            assert(late.level == Growth.combatantLevel(Character.defs.character_bandit, 20),
                "an unpinned enemy takes the level the rule gives it")
            assert(late.level > base.level, "which is well above where it started")
            assert(late.stats.health.max > base.stats.health.max, "and actually grew a pool")
            assert(late.stats.health.current == late.stats.health.max, "arriving at full health")
        end,
    },

    -- ------------------------------------------------------------ the exchange
    {
        -- The property the whole change rests on: with both sides on the same tables, time-to-kill
        -- holds roughly still as levels climb, instead of the player pulling away to invulnerability.
        name = "the exchange stays flat as both sides climb",
        fn = function()
            local seen = {}
            for _, level in ipairs({ 1, 10, 25, Growth.LEVEL_CAP }) do
                local knight = grown("character_knight", level, "knight")
                local bandit = Growth.spawn("character_bandit", level)

                local theyNeed = hitsToKill(bandit, knight)
                local weNeed = hitsToKill(knight, bandit)
                assert(theyNeed and weNeed, "both sides must carry a weapon")
                seen[#seen + 1] = string.format("L%d %d/%d", level, theyNeed, weNeed)

                assert(theyNeed >= 2, string.format(
                    "at level %d the enemy fells a knight in %d hits -- the player is being one-shot (%s)",
                    level, theyNeed, table.concat(seen, "  ")))
                assert(theyNeed <= 12, string.format(
                    "at level %d the enemy needs %d hits to fell a knight -- the player has run away "
                    .. "with it, which is the pre-scaling bug (%s)", level, theyNeed, table.concat(seen, "  ")))
                assert(weNeed <= 12, string.format(
                    "at level %d the knight needs %d hits to fell a bandit -- fights have turned to "
                    .. "slogs (%s)", level, weNeed, table.concat(seen, "  ")))
            end
        end,
    },

    {
        -- The lag's whole purpose: a grown company must FEEL grown against ordinary stock, without
        -- fights becoming free. Both halves are asserted, because either one alone is a bug -- no edge
        -- is a treadmill, and too much edge is the no-scaling bug returning by another road.
        -- The edge is CONSTANT, not growing, and that is inherent rather than a shortfall: with both
        -- sides growing linearly and mitigation subtracting, the exchange converges to a fixed ratio and
        -- a lag only chooses which one (see the note on Growth.ENEMY_LEVEL_LAG). So the property to hold
        -- is that the lag buys a real edge AT EVERY LEVEL -- not that the edge widens with the campaign.
        name = "the lag buys a real edge over common stock at every level, and never a free fight",
        fn = function()
            for _, level in ipairs({ 5, 20, Growth.LEVEL_CAP }) do
                local knight = grown("character_knight", level, "knight")
                local lagged = Growth.spawn("character_bandit", level)

                -- The same bandit, denied the lag, is what a fair fight would look like.
                local fair = Character.instantiate("character_bandit")
                Growth.resolve(fair, level)

                local withLag = hitsToKill(lagged, knight)
                local without = hitsToKill(fair, knight)

                assert(withLag > without, string.format(
                    "at level %d the lag bought nothing (%d hits either way) -- levelling is a treadmill",
                    level, withLag))
                assert(withLag <= 20, string.format(
                    "at level %d common stock needs %d hits to fell a knight -- it can no longer "
                    .. "threaten anyone, which is the un-scaled bug wearing a lag", level, withLag))
            end
        end,
    },

    {
        name = "an elite keeps pace with the company the trash has fallen behind",
        fn = function()
            local knight = grown("character_knight", Growth.LEVEL_CAP, "knight")

            local stock = Growth.spawn("character_bandit", Growth.LEVEL_CAP)
            -- Same body, but named: a blueprint floor marks it as something that tracks exactly.
            local namedDef = {}
            for k, v in pairs(Character.defs.character_bandit) do namedDef[k] = v end
            namedDef.floorLevel = 1
            assert(Growth.combatantLevel(namedDef, Growth.LEVEL_CAP)
                > Growth.combatantLevel(Character.defs.character_bandit, Growth.LEVEL_CAP),
                "declaring a floor should lift a unit out of the lag")

            local elite = Growth.spawn("character_demon_champion", Growth.LEVEL_CAP)
            assert(hitsToKill(elite, knight) < hitsToKill(stock, knight),
                "an elite must still be the dangerous thing on the board")
        end,
    },

    {
        -- The regression guard for the divergence Part 0 closed: a class whose survivability grew
        -- slower than a scaled enemy's attack gets relatively frailer every level and is eventually
        -- one-shot. Swept over every growth table rather than spot-checked, because the failure is
        -- structural -- it arrives for any table that misses the floor, just at a different level.
        name = "no class is ever one-shot by a scaled elite, at any level up to the cap",
        fn = function()
            local elite = Growth.spawn("character_demon_champion", Growth.LEVEL_CAP)
            local weapon = weaponOf(elite)
            assert(weapon, "the elite must carry something to swing")

            local checked = 0
            for class in pairs(Growth.defs) do
                local id = "character_" .. class
                if Character.defs[id] then
                    local victim = grown(id, Growth.LEVEL_CAP, class)
                    local map = Fixture.new(6, 6)
                    local a = Fixture.unit(elite, 1, 1)
                    local d = Fixture.unit(victim, 2, 1)
                    local combat = Fixture.combat(map, a, d)

                    local blow = Combat.computeDamage(combat, a, d, weapon) or 0
                    assert(blow < d.char.stats.health.max, string.format(
                        "%s is ONE-SHOT at level %d: a scaled elite hits for %d into a %d pool. Its "
                        .. "growth table buys %d survivability per level against the enemy's +%d attack.",
                        class, Growth.LEVEL_CAP, blow, d.char.stats.health.max,
                        Growth.survivability(Growth.defs[class]), Growth.ENEMY_DAMAGE_GROWTH))
                    checked = checked + 1
                end
            end
            assert(checked > 30, "the sweep should cover the roster of growth tables, saw " .. checked)
        end,
    },
}
