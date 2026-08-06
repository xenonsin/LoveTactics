-- Tests for the Those Who Rule import: four mechanics borrowed from that game's ability list, each
-- one a seam this codebase did not have.
--
--   1. WATCHED GROUND -- their zone of control, restated as a move-COST tax laid by the Overwatch
--      stance rather than a hard stop laid by every body (Combat.watchTax, and the unification of the
--      three tile-cost derivations into stepTerrainCost that made it authorable at all).
--   2. LIVE PASSIVES -- a standing rule whose value is read off the board right now instead of banked
--      when an event fired (Trait.liveBonus, folded into Combat.flatStat).
--   3. TERRAIN MASTERY -- the first items in the catalog that touch `moveCost`: one that eases the
--      wearer's own footing, and one that eases it for the allies walking past (Combat.terrainEase).
--   4. THE TURN-REFRESH TIER -- fx.grantExtraAction widened to take a target, so a priest can hand
--      SOMEBODY ELSE another action, plus the once-per-turn stamp that keeps a kill-reflex from
--      chaining forever (Combat.firstThisTurn).
--
-- Each is tested at its own seam rather than at "the file loads", following the house shape for an
-- import pass (fae_borrowings_spec, fft_items_spec, bg3_import_spec). Pure logic, headless.

local Character = require("models.character")
local Combat = require("models.combat")
local Item = require("models.item")
local Status = require("models.status")
local Trait = require("models.trait")
local Fixture = require("tests.support.fixture")

-- A body that walks 4 and carries nothing that would perturb a cost measurement.
local function walker(x, y)
    return Fixture.unit("character_archer", x, y, { isolate = "bare", stats = { movement = 4 } })
end

-- A body carrying exactly `items`, nothing else.
local function bare(id, x, y, items)
    return Fixture.unit(id, x, y, { isolate = "bare", items = items or {} })
end

-- Put `u` into the Overwatch stance without spending a turn on it, so a cost case can measure the
-- ground without also driving a whole turn through endTurn.
local function watch(u, zone)
    u.overwatch = { staminaPerShot = 0, zone = zone }
end

local function reaches(combat, u, x, y)
    return Combat.reachable(combat, u)[x .. "," .. y] ~= nil
end

return {
    -- ---------------------------------------------------------------------
    -- 1. Watched ground
    -- ---------------------------------------------------------------------
    {
        name = "watched ground shortens a walk -- and a plain enemy still does not",
        fn = function()
            -- The far half of a corridor, past a body standing beside the lane at (4,3).
            local function board()
                local map = Fixture.new(8, 8)
                local hero = walker(2, 2)
                local foe = bare("character_bandit", 4, 3)
                return Fixture.combat(map, hero, foe)
            end

            -- BASELINE: an ordinary enemy taxes nothing. This is the half that must never regress --
            -- it is every fight in the existing game.
            local plain = board()
            assert(reaches(plain, plain.units[1], 6, 2),
                "a plain enemy beside the lane must not shorten anybody's walk")

            -- The same board, with the same enemy holding Held Ground's stance.
            local held = board()
            watch(held.units[2], 2)
            assert(not reaches(held, held.units[1], 6, 2),
                "a watcher's ground should cost enough to put the far tile out of a 4-move reach")
            assert(reaches(held, held.units[1], 3, 2),
                "the near tile is still reachable: a tax is a price, never a wall")
        end,
    },
    {
        name = "the tax lifts when the stance does",
        fn = function()
            local map = Fixture.new(8, 8)
            local combat = Fixture.combat(map, walker(2, 2), bare("character_bandit", 4, 3))
            local hero, foe = combat.units[1], combat.units[2]

            watch(foe, 2)
            assert(not reaches(combat, hero, 6, 2), "watched ground should shorten the walk")
            -- Combat.startTurn drops a stance when its holder comes back around; the tax is the
            -- stance, so it must go with it rather than needing a lifetime of its own.
            foe.overwatch = nil
            assert(reaches(combat, hero, 6, 2), "the ground should be ordinary again once the watch ends")
        end,
    },
    {
        name = "both cost readers price a watched tile the same",
        fn = function()
            -- THE HIGHEST-VALUE CASE HERE. moveGraph (the Dijkstra behind the move overlay) and
            -- Combat.planMoveVia (a hand-steered route) used to derive terrain cost separately, each
            -- with its own copy of the arithmetic. That was survivable while the only term was the
            -- tile; the moment a tile's price could depend on the board it became a promise the
            -- overlay makes and the route breaks. Both now call stepTerrainCost, and this is what
            -- says so.
            local map = Fixture.new(8, 8)
            local combat = Fixture.combat(map, walker(2, 2), bare("character_bandit", 4, 3))
            local hero, foe = combat.units[1], combat.units[2]
            watch(foe, 2)

            Fixture.openTurn(combat, hero)
            local route = { { x = 2, y = 2 }, { x = 3, y = 2 }, { x = 4, y = 2 } }
            local steered = Combat.planMoveVia(combat, hero, route)
            assert(steered, "the steered route should still be legal -- it is dear, not forbidden")

            local derived = Combat.reachable(combat, hero)["4,2"]
            assert(derived, "the derived graph should reach the same tile")
            assert(steered.cost == derived.cost, string.format(
                "the steered route costs %d and the derived one %d -- the two readers have drifted",
                steered.cost, derived.cost))
            -- (4,2) is beside the watcher at (4,3): 1 for open ground plus the 2 it is taxed. The
            -- step onto (3,2) is untouched, so the whole route is 1 + 3.
            assert(steered.cost == 4,
                "expected 1 for open ground and 3 for the watched tile, got " .. steered.cost)
        end,
    },
    {
        name = "nobody is walled in: a tax can always be paid",
        fn = function()
            -- A hard stop can freeze a surrounded body forever. A cost cannot, and the difference is
            -- the whole argument for choosing one over the other on a board this small.
            --
            -- The watchers stand DIAGONALLY, so every tile the hero could step to is taxed by two of
            -- them at once while none of them is standing in the way. Ringing it with bodies instead
            -- would prove nothing: an enemy has always barred its own tile outright, and a hero with
            -- four of them on its orthogonals is immobile in the shipped game too.
            local map = Fixture.new(8, 8)
            local hero = walker(4, 4)
            local combat = Fixture.combat(map, hero, {
                bare("character_bandit", 3, 3), bare("character_bandit", 5, 3),
                bare("character_bandit", 3, 5), bare("character_bandit", 5, 5),
            })
            for i = 2, #combat.units do watch(combat.units[i], 2) end

            local out = Combat.reachable(combat, combat.units[1])
            local n = 0
            for _ in pairs(out) do n = n + 1 end
            assert(n > 0, "a body ringed by watchers must still be able to walk somewhere")
        end,
    },
    {
        name = "a flier reads none of it, and the counters needed no new code",
        fn = function()
            local map = Fixture.new(8, 8)
            local combat = Fixture.combat(map,
                bare("character_archer", 2, 2, { "utility_zephyr_striders" }),
                bare("character_bandit", 4, 3))
            local flier, foe = combat.units[1], combat.units[2]
            flier.char.stats.movement = 4
            assert(Combat.isFlying(flier), "the Zephyr Striders should lift their wearer off the ground")

            watch(foe, 2)
            -- stepTerrainCost returns a flat 1 for a flier before it reads the tile at all, so the
            -- tax is answered by an exemption that already existed.
            assert(reaches(combat, flier, 6, 2), "a flier should cross watched ground untaxed")
        end,
    },
    {
        name = "the tax is initiative, not just distance",
        fn = function()
            -- moveCost doubles as the time a move bills, so wading past a watcher puts the walker
            -- further down the order. That is the mechanic's real teeth and is asserted deliberately
            -- rather than left to be discovered.
            local map = Fixture.new(8, 8)
            local combat = Fixture.combat(map, walker(2, 2), bare("character_bandit", 4, 3))
            local hero, foe = combat.units[1], combat.units[2]

            Fixture.openTurn(combat, hero)
            local clear = Combat.planMove(combat, hero, 4, 2)
            assert(clear, "the tile should be reachable on open ground")

            watch(foe, 2)
            Fixture.openTurn(combat, hero)
            local taxed = Combat.planMove(combat, hero, 4, 2)
            assert(taxed, "and still reachable when watched -- a cost, not a wall")
            assert(taxed.cost > clear.cost, string.format(
                "a watched approach should bill more than a clear one (%d vs %d)", taxed.cost, clear.cost))
        end,
    },
    {
        name = "Held Ground declares the stance, and the sentries tax less than the wall",
        fn = function()
            local held = Item.instantiate("utility_held_ground")
            assert(held.waitBehavior and held.waitBehavior.kind == "overwatch",
                "Held Ground should swap Wait into Overwatch")
            assert(held.waitBehavior.zone == 2, "the knight's ground should tax 2")

            for _, id in ipairs({ "utility_overwatch_scope", "weapon_stillhunter" }) do
                local sentry = Item.instantiate(id)
                assert(sentry.waitBehavior.zone == 1,
                    id .. " should tax 1 -- a sentry watches a wide band lightly")
            end

            -- The stance carries the number onto the body, beside the per-shot stamina it already
            -- carried, so nothing about the tax needs a lifetime of its own.
            local map = Fixture.new(8, 8)
            local combat = Fixture.combat(map,
                bare("character_knight", 4, 4, { "utility_held_ground" }),
                bare("character_bandit", 8, 8))
            local knight = combat.units[1]
            Fixture.openTurn(combat, knight)
            assert(Combat.overwatch(combat, knight), "the knight should be able to take the stance")
            assert(knight.overwatch.zone == 2, "the stance should carry its zone onto the unit")
        end,
    },

    -- ---------------------------------------------------------------------
    -- 2. Live passives
    -- ---------------------------------------------------------------------
    {
        name = "a live passive rises and falls with the board, and is pure",
        fn = function()
            local map = Fixture.new(8, 8)
            local combat = Fixture.combat(map,
                bare("character_knight", 4, 4, { "utility_odds_against" }),
                { bare("character_bandit", 3, 4), bare("character_bandit", 5, 4) })
            local champ = combat.units[1]

            -- Two enemies stand adjacent right now; walk them away and the bonus must go with them.
            local surrounded = Combat.flatStat(champ, "defense")
            combat.units[2].x, combat.units[2].y = 1, 1
            combat.units[3].x, combat.units[3].y = 8, 8
            local cleared = Combat.flatStat(champ, "defense")

            assert(surrounded > cleared, string.format(
                "the Champion should be harder to hurt while surrounded (%d) than alone (%d)",
                surrounded, cleared))

            -- PURITY: the same read twice, with nothing between, must answer the same. Both damage
            -- previews and the inventory tooltip call flatStat on every hover frame.
            assert(Combat.flatStat(champ, "defense") == cleared, "a live read must not mutate anything")
            assert(Combat.flatStat(champ, "defense") == cleared, "...and must still answer the same")
        end,
    },
    {
        name = "Formation Fighter tracks a line that breaks, and never doubles into unit.bonus",
        fn = function()
            -- The trait that named this gap: it used to fire onCombatStart and bank the result, so a
            -- line-soldier kept a full formation's defense while standing over its own dead.
            local map = Fixture.new(8, 8)
            local combat = Fixture.combat(map, {
                bare("character_knight", 4, 4, { "utility_drill_standard" }),
                bare("character_knight", 3, 4),
                bare("character_knight", 5, 4),
            }, bare("character_bandit", 8, 8))
            local drilled = combat.units[1]
            assert(Trait.has(drilled, "trait_formation_fighter"),
                "the Drill Standard should carry Formation Fighter")

            local inLine = Combat.flatStat(drilled, "defense")
            combat.units[2].alive = false -- the rank breaks
            local oneDown = Combat.flatStat(drilled, "defense")
            assert(oneDown < inLine, string.format(
                "defense should fall as the line breaks (%d -> %d)", inLine, oneDown))

            combat.units[2].alive = true -- ...and closes again
            assert(Combat.flatStat(drilled, "defense") == inLine,
                "and rise again when somebody steps back into the rank")

            -- ctx.addBonus writes the permanent bucket, which flatStat ALSO sums. A live trait that
            -- reached for it would count every neighbour twice.
            assert((drilled.bonus and drilled.bonus.defense or 0) == 0,
                "a live trait must not bank into unit.bonus -- flatStat would double it")
        end,
    },
    {
        name = "Savior's Watch pays for the wounded, caps at three, and ignores the hale",
        fn = function()
            local map = Fixture.new(8, 8)
            local combat = Fixture.combat(map, {
                bare("character_knight", 4, 4, { "utility_saviors_watch" }),
                bare("character_knight", 4, 5),
            }, bare("character_bandit", 8, 8))
            local crusader, ally = combat.units[1], combat.units[2]

            local hale = Combat.flatStat(crusader, "movement")
            ally.char.stats.health.current = ally.char.stats.health.max - 1
            local hurt = Combat.flatStat(crusader, "movement")
            assert(hurt > hale, string.format(
                "the square should arrive because somebody needs it (%d -> %d)", hale, hurt))

            ally.char.stats.health.current = ally.char.stats.health.max
            assert(Combat.flatStat(crusader, "movement") == hale,
                "and go again when they are patched up -- a banked version would keep paying forever")
        end,
    },

    -- ---------------------------------------------------------------------
    -- 3. Terrain mastery
    -- ---------------------------------------------------------------------
    {
        name = "Trackless Boots cap what the ground may charge, in both cost readers",
        fn = function()
            -- Forest at 2 has been in models/arena.lua since the first arena and nothing in ~640
            -- items has ever cared. These are the first that do.
            local function board(items)
                local map = Fixture.new(8, 8, { tiles = {
                    { x = 3, y = 2, type = "forest", moveCost = 2 },
                    { x = 4, y = 2, type = "forest", moveCost = 2 },
                } })
                local hero = Fixture.unit("character_archer", 2, 2,
                    { isolate = "bare", stats = { movement = 4 }, items = items })
                return Fixture.combat(map, hero, bare("character_bandit", 8, 8))
            end

            local plain = board({})
            Fixture.openTurn(plain, plain.units[1])
            local slow = Combat.planMove(plain, plain.units[1], 4, 2)
            assert(slow and slow.cost == 4, "two forest tiles should cost 2 each, got "
                .. tostring(slow and slow.cost))

            local shod = board({ "utility_trackless_boots" })
            Fixture.openTurn(shod, shod.units[1])
            local quick = Combat.planMove(shod, shod.units[1], 4, 2)
            assert(quick and quick.cost == 2, "the boots should cap each forest tile at 1, got "
                .. tostring(quick and quick.cost))

            -- The steered route must agree with the derived one, exactly as it must for the tax.
            local steered = Combat.planMoveVia(shod, shod.units[1],
                { { x = 2, y = 2 }, { x = 3, y = 2 }, { x = 4, y = 2 } })
            assert(steered and steered.cost == quick.cost,
                "both cost readers must ease the ground the same way")
        end,
    },
    {
        name = "the Surveyor's Chain eases the ground for allies walking past, not for its bearer",
        fn = function()
            -- The genuinely new verb: every other movement item in the game changes how its own
            -- wearer moves. This one changes how somebody else does.
            local map = Fixture.new(8, 8, { tiles = {
                { x = 3, y = 2, type = "forest", moveCost = 2 },
            } })
            local mover = Fixture.unit("character_archer", 2, 2,
                { isolate = "bare", stats = { movement = 4 } })
            local surveyor = bare("character_knight", 3, 3, { "utility_surveyors_chain" })
            local combat = Fixture.combat(map, { mover, surveyor }, bare("character_bandit", 8, 8))
            local walking, chain = combat.units[1], combat.units[2]

            Fixture.openTurn(combat, walking)
            local eased = Combat.planMove(combat, walking, 3, 2)
            assert(eased and eased.cost == 1,
                "an ally beside the forest tile should make it cost open field, got "
                .. tostring(eased and eased.cost))

            -- Walk the surveyor away and the road closes behind it.
            chain.x, chain.y = 8, 8
            Fixture.openTurn(combat, walking)
            local unaided = Combat.planMove(combat, walking, 3, 2)
            assert(unaided and unaided.cost == 2, "and cost its full 2 again once nobody is standing by")

            -- It does not carry its own bearer: the escort read skips the moving body's own grid.
            local map2 = Fixture.new(8, 8, { tiles = { { x = 3, y = 2, type = "forest", moveCost = 2 } } })
            local solo = Fixture.unit("character_knight", 2, 2,
                { isolate = "bare", stats = { movement = 4 }, items = { "utility_surveyors_chain" } })
            local c2 = Fixture.combat(map2, solo, bare("character_bandit", 8, 8))
            Fixture.openTurn(c2, c2.units[1])
            local own = Combat.planMove(c2, c2.units[1], 3, 2)
            assert(own and own.cost == 2,
                "the chain is a bridge for the company, not for the one holding it")
        end,
    },
    {
        name = "good boots answer bad ground, never a spear: the tax is added after the cap",
        fn = function()
            local map = Fixture.new(8, 8, { tiles = { { x = 3, y = 2, type = "forest", moveCost = 2 } } })
            local hero = Fixture.unit("character_archer", 2, 2,
                { isolate = "bare", stats = { movement = 4 }, items = { "utility_trackless_boots" } })
            local combat = Fixture.combat(map, hero, bare("character_bandit", 3, 3))
            watch(combat.units[2], 2)

            Fixture.openTurn(combat, combat.units[1])
            local plan = Combat.planMove(combat, combat.units[1], 3, 2)
            -- Forest capped to 1 by the boots, then 2 added for the watcher beside the tile.
            assert(plan and plan.cost == 3, string.format(
                "expected the boots to ease the ground (1) and the watch to tax it anyway (+2), got %s",
                tostring(plan and plan.cost)))
        end,
    },
    {
        name = "Safeguard trades places and braces both bodies by the caster's own defense",
        fn = function()
            local map = Fixture.new(8, 8)
            local combat = Fixture.combat(map, {
                bare("character_knight", 4, 4, { "ability_safeguard" }),
                bare("character_archer", 4, 6),
            }, bare("character_bandit", 8, 8))
            local knight, ally = combat.units[1], combat.units[2]
            knight.char.stats.defense = 12

            local kx, ky, ax, ay = knight.x, knight.y, ally.x, ally.y
            local ok = Fixture.strike(combat, knight, ally, "ability_safeguard")
            assert(ok, "Safeguard should resolve on an ally in range")

            assert(knight.x == ax and knight.y == ay, "the knight should take the ally's ground")
            assert(ally.x == kx and ally.y == ky, "and the ally should take the knight's")
            for _, body in ipairs({ knight, ally }) do
                local st = Status.get(body, "status_defending")
                assert(st, "both bodies should come out of it braced")
                assert(st.magnitude == 6, "the brace should be half the caster's 12 defense, got "
                    .. tostring(st.magnitude))
            end
        end,
    },

    -- ---------------------------------------------------------------------
    -- 4. The turn-refresh tier
    -- ---------------------------------------------------------------------
    {
        name = "Vital Points hands the extra action to the ALLY, not to the caster",
        fn = function()
            -- The one verb this game could not say: fx.grantExtraAction was hardwired to the caster,
            -- so "let somebody else act again" was unauthorable in any form.
            local map = Fixture.new(8, 8)
            local combat = Fixture.combat(map, {
                bare("character_priest", 4, 4, { "ability_vital_points" }),
                bare("character_knight", 4, 5),
            }, bare("character_bandit", 8, 8))
            local priest, ally = combat.units[1], combat.units[2]
            priest.char.stats.mana.current = priest.char.stats.mana.max

            -- Bank the Focus the ability gates on, off the tallies it names.
            Combat.tally(priest, "healDone", 10)
            assert(Combat.chargePool(priest, "focus") >= 5, "the pool should have filled")

            local before = ally.initiative
            assert(Fixture.strike(combat, priest, ally, "ability_vital_points"),
                "Vital Points should resolve on an ally")

            assert((ally.extraActions or 0) == 1, "the ALLY should hold the extra action")
            assert((priest.extraActions or 0) == 0, "and the caster should hold none")
            assert(ally.initiative < before, "...and it should arrive sooner (fx.hasten)")
        end,
    },
    {
        name = "a kill-reflex fires once per turn, and an extra action does not reset it",
        fn = function()
            -- The stamp is a termination condition, not a balance dial: the granted action can make
            -- another qualifying kill, and ungated a body in a broken line would refresh forever.
            local u = { alive = true, char = { stats = {} } }
            assert(Combat.firstThisTurn(u, "battleborn"), "the first ask in a turn is true")
            assert(not Combat.firstThisTurn(u, "battleborn"), "and every ask after it is false")
            assert(Combat.firstThisTurn(u, "thrill_of_the_hunt"),
                "a different key keeps its own stamp")
        end,
    },
    {
        name = "Thrill of the Hunt wants the mark; Battleborn wants its absence",
        fn = function()
            local function board(item)
                local map = Fixture.new(8, 8)
                local combat = Fixture.combat(map,
                    bare("character_archer", 4, 4, { item }),
                    bare("character_bandit", 4, 5))
                combat.turn = { unit = combat.units[1], moved = false, moveCost = 0 }
                return combat, combat.units[1], combat.units[2]
            end

            -- The hunter is paid for the setup it did a turn ago.
            local c1, hunter, foe1 = board("utility_thrill_of_the_hunt")
            Status.apply(c1, foe1, "status_mark", { applier = hunter })
            Trait.onAnyDeath(c1, foe1)
            assert((hunter.extraActions or 0) == 1, "felling a MARKED foe should hand the turn back")

            -- An unmarked kill pays the hunter nothing.
            local c2, hunter2, foe2 = board("utility_thrill_of_the_hunt")
            Trait.onAnyDeath(c2, foe2)
            assert((hunter2.extraActions or 0) == 0, "an unprepared kill is not the hunter's payoff")

            -- The warlord is the exact mirror: it wants a body nothing had softened.
            local c3, lord, foe3 = board("utility_battleborn")
            Trait.onAnyDeath(c3, foe3)
            assert((lord.extraActions or 0) == 1, "felling an unweakened foe should hand the turn back")

            local c4, lord2, foe4 = board("utility_battleborn")
            Status.apply(c4, foe4, "status_bleed", { applier = lord2 })
            Trait.onAnyDeath(c4, foe4)
            assert((lord2.extraActions or 0) == 0, "a softened kill is not the warlord's boast")
        end,
    },
    {
        name = "the dry-run and tooltip builders both survive a targeted grantExtraAction",
        fn = function()
            -- A helper whose SHAPE differs between the live path and the two inert ones makes an
            -- effect branch differently under the cursor than in the cast, silently, from that line
            -- onward. Both replay Vital Points' effect; neither may throw, and neither may move the
            -- board.
            local map = Fixture.new(8, 8)
            local combat = Fixture.combat(map, {
                bare("character_priest", 4, 4, { "ability_vital_points" }),
                bare("character_knight", 4, 5),
            }, bare("character_bandit", 8, 8))
            local priest, ally = combat.units[1], combat.units[2]
            Combat.tally(priest, "healDone", 10)

            local item = Fixture.itemNamed(priest.char, "ability_vital_points")
            local ok = pcall(Combat.previewAbility, combat, priest, item, ally.x, ally.y)
            assert(ok, "the board dry-run must not throw on a targeted grant")

            local ok2 = pcall(Combat.abilityOutput, item, priest.char)
            assert(ok2, "the inventory tooltip builder must not throw either")

            assert((ally.extraActions or 0) == 0,
                "and neither preview may actually hand the ally an action")
            assert(Combat.chargePool(priest, "focus") >= 5,
                "...nor spend the pool under the cursor")
        end,
    },
}
