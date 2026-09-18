-- THE PARKED RELIC SHELF, AS GEAR (2026-09-17).
--
-- Twenty-five run relics became items when models/relic.lua was parked: seven that acted at the bell or
-- between fights, ten flat trades, and eight that rewrite a rule of the game. Eleven more -- the whole
-- pure-stat common rung, a flat always-on number with no strings -- were CUT rather than converted, and
-- the last case here pins that so none of them quietly grows back.
--
-- WHAT THIS FILE IS FOR, beyond naming the ids so tests/item_coverage_spec.lua is satisfied: the
-- conversion moved every one of these from a COMPANY scope to a BEARER scope, and that is the half a
-- data diff cannot show. A relic's `bonus` folded onto all four bodies; an item's folds onto the body
-- wearing it. So the cases below are written about who is affected, not only about what the number is.
--
-- The three new seams each get a case of their own, because each is a mechanism that did not exist
-- before this move and nothing else in the tree exercises them:
--   * `item.rules`        -- Item.rulesFor / Item.mergeRules, folded to unit.rules by Combat
--   * `item.openingBoon`  -- drained onto the bearer by states/battle.lua at the opening bell
--   * `item.encounterCleared` -- models/item_hook.lua, fired by the run loop between fights

local Combat = require("models.combat")
local Fixture = require("tests.support.fixture")
local Item = require("models.item")
local ItemHook = require("models.item_hook")
local Character = require("models.character")

-- Every id the conversion produced, by the rung it came off. Listed rather than derived so that
-- deleting one is a failing test rather than a silently shorter sweep.
local CONVERTED = {
    -- the seven that act at the bell or between fights
    "utility_deep_larder", "utility_duelists_spur", "utility_gluttons_purse", "utility_honed_edge",
    "utility_kept_vigil", "utility_long_watch", "utility_warding_icon",
    -- the ten trades
    "utility_bared_head", "utility_bared_nerve", "armor_braced_stance", "utility_far_mark",
    "utility_keen_edge", "utility_overreach", "utility_quick_draw", "utility_closed_ranks",
    "utility_held_line", "utility_thin_blade",
    -- the eight rule rewrites
    "utility_held_breath", "utility_long_wait", "utility_open_wound", "utility_overdraft",
    "utility_rooted_oath", "utility_unpaid_tithe", "utility_whetted_vow", "utility_yoked_company",
}

-- The eleven that were CUT. Each was a flat always-on number for the whole company and nothing else --
-- one relic per stat -- which is the thing an item shelf already sells a hundred of.
local CUT = {
    "deep_draught", "early_bell", "full_skin", "long_lesson", "overfull_flask", "quiet_ward",
    "second_breath", "struck_sigil", "thumbed_die", "weight_of_plate", "whetstone_tithe",
}

local function ruleNames()
    local set = {}
    for _, n in ipairs(Item.RULE_NAMES) do set[n] = true end
    return set
end

-- Fixture.unit hands back a SPAWN descriptor ({ char, x, y }), and the unit a rule lands on is the one
-- Combat.new builds from it. Matching by char identity is the seam between the two, and getting this
-- wrong reads as "the rule did not apply" rather than as a test bug.
local function unitFor(combat, spawn)
    for _, u in ipairs(combat.units) do
        if u.char == spawn.char then return u end
    end
    return nil
end

return {
    {
        name = "every relic that became an item is on the shelf, and carries an effect",
        fn = function()
            for _, id in ipairs(CONVERTED) do
                local def = Item.defs[id]
                assert(def, id .. " does not exist -- the relic conversion lost one")
                assert(def.name and def.description and def.flavor,
                    id .. " is missing a name, description or flavor")
                -- A converted relic that ended up with no mechanism at all would still pass every
                -- schema sweep in the tree, because a description is prose. This is the case that
                -- says the thing actually does something.
                local acts = def.bonus or def.maxBonus or def.resist or def.traits
                    or def.rules or def.openingBoon or def.encounterCleared
                assert(acts, id .. " converted into an item that does nothing at all")
            end
        end,
    },
    {
        name = "the pure-stat rung was cut, not converted",
        fn = function()
            -- Eleven relics were a flat number for the whole company with no strings attached. The
            -- brief was explicit that those do not become items, so this asserts the ABSENCE -- which
            -- is the only way a deletion stays deleted once the blueprints are still sitting on disk
            -- in data/relics/ waiting for a revert.
            for _, stem in ipairs(CUT) do
                for _, prefix in ipairs({ "utility_", "armor_", "weapon_", "ability_", "consumable_" }) do
                    assert(not Item.defs[prefix .. stem],
                        prefix .. stem .. " exists -- the pure-stat relics were cut, not converted")
                end
            end
        end,
    },
    {
        name = "every rule an item declares is one the engine actually reads",
        fn = function()
            -- A misspelled rule name is a field nothing consumes: it parses, it ships, and it does
            -- exactly nothing, which is indistinguishable from working until somebody plays it. The
            -- name list is the contract and this is what holds a blueprint to it.
            local known = ruleNames()
            local declared = 0
            for id, def in pairs(Item.defs) do
                for name in pairs(def.rules or {}) do
                    assert(known[name],
                        id .. " declares rule '" .. name .. "', which nothing in the engine reads")
                    declared = declared + 1
                end
            end
            assert(declared >= 8, "almost no item declares a rule -- this sweep is not scanning anything")
        end,
    },
    {
        name = "a rule reaches the bearer and nobody else",
        fn = function()
            -- THE WHOLE POINT OF THE CONVERSION, in one case. As a relic, The Rooted Oath rooted the
            -- COMPANY; every escort objective became unsatisfiable and the honest answer was that the
            -- relic had to be refused on those maps. One rooted body among four is a position instead.
            local c = Fixture.new(10, 10)
            local rooted = Fixture.unit("character_knight", 2, 2,
                { isolate = "bare", items = { "utility_rooted_oath" } })
            local free = Fixture.unit("character_knight", 4, 4, { isolate = "bare" })
            local combat = Fixture.combat(c, { rooted, free }, {})
            Combat.applyPassives(combat)
            rooted, free = unitFor(combat, rooted), unitFor(combat, free)

            assert(rooted.rules and rooted.rules.noMove, "the wearer is rooted")
            assert(rooted.rules.abilityRange == 3, "and reaches three tiles further for it")
            assert(not free.rules, "the ally standing beside them is not rooted, and has no rule bag at all")
        end,
    },
    {
        name = "two sources of one rule merge the way the shelf merged",
        fn = function()
            -- `damageMultiplier` MULTIPLIES and everything else is first-wins, which is the rule /
            -- magnitude split the parked shelf was built on. Asserted through Item.mergeRules directly
            -- because it is the one policy both the live path and the revert path share.
            local merged = Item.mergeRules({ damageMultiplier = 1.5, noMove = true },
                                           { damageMultiplier = 2, noMove = true, abilityRange = 1 })
            assert(merged.damageMultiplier == 3, "two multipliers multiply: 1.5 x 2 is 3, not 3.5")
            assert(merged.noMove == true, "a rule fires once -- nothing is more unable to move")
            assert(merged.abilityRange == 1, "a name only the second source declares still lands")
        end,
    },
    {
        name = "The Whetted Vow halves the body and doubles the blow, on its wearer alone",
        fn = function()
            local c = Fixture.new(8, 8)
            local sworn = Fixture.unit("character_fighter", 2, 2,
                { isolate = "bare", items = { "utility_whetted_vow" } })
            local plain = Fixture.unit("character_fighter", 3, 3, { isolate = "bare" })
            local combat = Fixture.combat(c, { sworn, plain }, {})
            Combat.applyPassives(combat)
            sworn, plain = unitFor(combat, sworn), unitFor(combat, plain)

            assert(sworn.rules.damageMultiplier == 2, "the blow doubles")
            assert(sworn.rules.halveMaxHealth == 2, "and the ceiling is divided by the same figure")
            local halved = Combat.unreservedMax(sworn.char, "health")
            local whole = Combat.unreservedMax(plain.char, "health")
            assert(halved < whole, "the wearer's ceiling is below their untouched twin's")
            assert(halved == math.floor(whole / 2) or halved == math.ceil(whole / 2),
                "and it is halved, not merely lowered: " .. halved .. " against " .. whole)
        end,
    },
    {
        name = "The Yoked Company is the one item that is still collective, and says so",
        fn = function()
            -- The documented exception to the bearer rule. A shared health pool cannot be scoped to one
            -- body without ceasing to be the thing it is, so one body wears the yoke and all four share
            -- the bar. Combat.applyUnitRules is where the collective half and the per-bearer half split.
            local c = Fixture.new(8, 8)
            local bearer = Fixture.unit("character_priest", 2, 2,
                { isolate = "bare", items = { "utility_yoked_company" } })
            local other = Fixture.unit("character_knight", 3, 3, { isolate = "bare" })
            local combat = Fixture.combat(c, { bearer, other }, {})
            Combat.applyPassives(combat)
            Combat.applyUnitRules(combat)
            bearer, other = unitFor(combat, bearer), unitFor(combat, other)

            assert(bearer.sharedPool and other.sharedPool, "both bodies are on the one bar")
            assert(bearer.char.stats.health.max == other.char.stats.health.max,
                "and it is literally the same number, not two similar ones")
            assert(not other.rules, "the ally wears no yoke of their own -- the pool is shared, the item is not")
        end,
    },
    {
        name = "The Held Breath pins its wearer at 1 and leaves the rest of the company whole",
        fn = function()
            local c = Fixture.new(8, 8)
            local pinned = Fixture.unit("character_mage", 2, 2,
                { isolate = "bare", items = { "utility_held_breath" } })
            local whole = Fixture.unit("character_mage", 3, 3, { isolate = "bare" })
            local combat = Fixture.combat(c, { pinned, whole }, {})
            Combat.applyPassives(combat)
            Combat.applyUnitRules(combat)
            pinned, whole = unitFor(combat, pinned), unitFor(combat, whole)

            assert(pinned.char.stats.health.current == 1, "the wearer is pinned at one health")
            assert(whole.char.stats.health.current > 1,
                "and the body standing next to them is untouched -- as a relic this pinned all four")
        end,
    },
    {
        name = "an opening boon comes off the bearer's own grid",
        fn = function()
            -- The four bell items declare `openingBoon`, drained by states/battle.lua once the units
            -- are built. Asserted here at the blueprint rather than by driving a whole battle: what
            -- this case protects is that the field exists, names a real status, and is shaped the way
            -- the drain expects (a single entry, or a list of them).
            local Status = require("models.status")
            local found = 0
            for _, id in ipairs({ "utility_duelists_spur", "utility_honed_edge", "utility_long_watch",
                                  "utility_warding_icon", "utility_kept_vigil" }) do
                local def = Item.defs[id]
                local boon = def.openingBoon
                assert(boon, id .. " lost its opening boon")
                for _, b in ipairs(boon.id and { boon } or boon) do
                    assert(Status.defs[b.id], id .. " opens with '" .. tostring(b.id) .. "', which is not a status")
                    found = found + 1
                end
            end
            assert(found >= 5, "the opening-boon sweep found almost nothing")
        end,
    },
    {
        name = "a between-fight hook feeds its carrier and nobody else",
        fn = function()
            -- models/item_hook.lua's whole reason for existing. The Deep Larder healed all four as a
            -- relic; in one knight's pack it feeds the knight.
            local carrier = Character.instantiate("character_knight")
            local other = Character.instantiate("character_knight")
            for _, ch in ipairs({ carrier, other }) do ch.stats.health.current = 1 end
            Character.addItem(carrier, Item.instantiate("utility_deep_larder"))

            ItemHook.dispatch("encounterCleared", { party = { carrier, other } })

            assert(carrier.stats.health.current > 1, "the body carrying the larder is fed")
            assert(other.stats.health.current == 1, "and the one walking beside it is not")
        end,
    },
    {
        name = "The Unpaid Tithe gags what its own bearer would be given back",
        fn = function()
            -- The gag lives on models/item_hook.lua's ctx.restore and asks the RECEIVING body's rules,
            -- so a larder still feeds everyone else at the same stop. As a relic this silenced the
            -- whole company's recovery at once.
            local tithed = Character.instantiate("character_knight")
            local plain = Character.instantiate("character_knight")
            for _, ch in ipairs({ tithed, plain }) do ch.stats.health.current = 1 end
            Character.addItem(tithed, Item.instantiate("utility_unpaid_tithe"))
            Character.addItem(tithed, Item.instantiate("utility_deep_larder"))
            Character.addItem(plain, Item.instantiate("utility_deep_larder"))

            ItemHook.dispatch("encounterCleared", { party = { tithed, plain } })

            assert(tithed.stats.health.current == 1, "the tithed body recovers nothing")
            assert(plain.stats.health.current > 1, "and the body beside it still eats")
        end,
    },
    {
        name = "Glutton's Purse pays into the purse, and is paid for at the ceiling",
        fn = function()
            -- The one conversion whose COST is not the same quantity it was: the relic drained stamina
            -- at the opening bell through a `battleStart` hook, and an item has no such seam, so the
            -- toll is a lowered stamina ceiling instead. Both halves are asserted so the substitution
            -- cannot quietly lose one.
            local def = Item.defs["utility_gluttons_purse"]
            assert(def.maxBonus and def.maxBonus.stamina == -4,
                "the purse still costs four stamina, now off the ceiling")

            local bearer = Character.instantiate("character_rogue")
            Character.addItem(bearer, Item.instantiate("utility_gluttons_purse"))
            local paid = 0
            ItemHook.dispatch("encounterCleared", {
                party = { bearer },
                spoils = { gold = 30 },
                addGold = function(n) paid = paid + n end,
            })
            assert(paid == 30, "a fight worth 30 pays 30 again, and paid " .. paid)
        end,
    },
    {
        name = "a body carrying none of this has no rule bag at all",
        fn = function()
            -- The common case, and worth pinning: `unit.rules` is nil rather than an empty table for
            -- the overwhelming majority of bodies, and every read in the engine is written to test for
            -- that. An accidental `{}` here would be invisible and would change nothing until some
            -- future read did `if unit.rules then`.
            local c = Fixture.new(6, 6)
            local plain = Fixture.unit("character_fighter", 2, 2, { isolate = "bare" })
            local combat = Fixture.combat(c, { plain }, {})
            Combat.applyPassives(combat)
            plain = unitFor(combat, plain)
            assert(plain.rules == nil, "an ordinary body's rule bag is nil, not an empty table")
            assert(Item.rulesFor(plain.char) == nil, "and Item.rulesFor agrees")
        end,
    },
}
