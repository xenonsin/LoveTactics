-- Tests for the GREED and LUST circles -- the last two strata, and the two whose rules are about
-- resources rather than about the board.
--
-- The tier's design rule, pinned as it is for every other circle: A MINI SIN'S SECOND PHASE IS ITS
-- GENERAL'S FIRST.
--
--   Aurea lifts an ITEM off an adjacent body from her opening bell; the Tally takes coin, and starts
--   taking gear at half health.
--   Luxuria drains a foe's held-back reserves on EVERY hit; the Suppliant drains only a body that spent
--   nothing, and drops the condition at half health.
--
-- Both circles are grouped here because both are about what a player is CARRYING rather than about
-- terrain, and the two rules are each other's mirror -- one takes what you hoarded, the other punishes
-- you for hoarding it.

local Character = require("models.character")
local Combat = require("models.combat")
local Descent = require("models.descent")
local Item = require("models.item")
local Status = require("models.status")
local Trait = require("models.trait")
local Fixture = require("tests.support.fixture")

local unit, openTurn, itemNamed = Fixture.unit, Fixture.openTurn, Fixture.itemNamed

local function sinNamed(id)
    for _, s in ipairs(Descent.SINS) do if s.id == id then return s end end
end

return {
    -- ------------------------------------------------------------ both stairs
    {
        name = "Greed and Lust are each held by their own mini sin",
        fn = function()
            assert(sinNamed("greed").minor.lead == "character_the_tally", "the Tally holds the Undercroft")
            assert(sinNamed("lust").minor.lead == "character_the_suppliant", "the Suppliant holds the Cathedral")
            for _, id in ipairs({ "greed", "lust" }) do
                local sin = sinNamed(id)
                assert(sin.guardian.filler == sin.minor.lead,
                    id .. "'s mini sin must fill out its own general's stair")
            end
        end,
    },

    -- ------------------------------------------------------------ Greed: it reads your purse
    {
        name = "an Assayer is worth more the richer the party is, and nothing without a purse",
        fn = function()
            local map = Fixture.new(10, 10)
            local c = Fixture.combat(map,
                { unit("character_knight", 3, 3) },
                { unit("character_assayer", 6, 6) })
            local assayer
            for _, u in ipairs(c.units) do
                if u.char.id == "character_assayer" then assayer = u end
            end

            -- No purse injected: a draft duel, an arena, a headless fixture. It must read as nothing
            -- rather than faulting off the board it was not built for.
            assert(Trait.liveBonus(assayer, "damage") == 0,
                "with no campaign purse under the fight, the scales weigh nothing")

            -- states/battle.lua injects `combat.purse = { get, spend }` for a campaign fight.
            local gold = 3000
            c.purse = { get = function() return gold end, spend = function(n) gold = gold - n end }
            local rich = Trait.liveBonus(assayer, "damage")
            assert(rich > 0, "a full purse makes it heavier")

            gold = 100
            assert(Trait.liveBonus(assayer, "damage") < rich,
                "and it lightens as the purse empties -- which is why its own thieves are helping you")
        end,
    },
    {
        name = "the Assayer is capped, so a rich run does not meet an unkillable body",
        fn = function()
            local def = Trait.defs["trait_assayed"]
            assert(def and def.ceiling and def.per, "the scales declare both a rate and a ceiling")
            local map = Fixture.new(10, 10)
            local c = Fixture.combat(map,
                { unit("character_knight", 3, 3) },
                { unit("character_assayer", 6, 6) })
            local assayer
            for _, u in ipairs(c.units) do
                if u.char.id == "character_assayer" then assayer = u end
            end
            c.purse = { get = function() return 9999999 end, spend = function() end }
            assert(Trait.liveBonus(assayer, "damage") == def.ceiling,
                "an absurd purse still stops at the ceiling")
        end,
    },
    {
        name = "the Tally's second phase is Aurea's first",
        fn = function()
            local reck = Item.defs["utility_the_reckoning"]
            assert(reck and reck.phases and #reck.phases == 1, "a mini sin gets ONE phase")
            assert(reck.phases[1].at == 0.5, "and it turns at half health")
            local carries = false
            for _, t in ipairs(reck.traits or {}) do if t == "trait_assayed" then carries = true end end
            assert(carries, "it opens reading the purse")
        end,
    },
    {
        name = "the Hoard spends itself as you open it",
        fn = function()
            local hoard = Item.defs["utility_the_hoard"]
            assert(hoard and hoard.phases and #hoard.phases == 2, "it comes apart twice")
            for _, phase in ipairs(hoard.phases) do
                for _, r in ipairs(phase.responses or {}) do
                    if r.kind == "summon" then
                        assert(r.id == "character_coin_chitter",
                            "what leaves a disturbed hoard is pieces of it, carrying as much as they can")
                    end
                end
            end
            local def = Character.defs["character_the_hoard"]
            assert(def.footprint and def.footprint.w == 2, "the apex stands on four tiles")
            assert(def.kind == "object", "it is the pile, not something guarding one")
        end,
    },

    -- ------------------------------------------------------------ Lust: it reads what you held back
    {
        name = "the Unasked drains a foe and takes half of it as health",
        fn = function()
            -- `isolate = "bare"` empties the victim's grid. Without it a knight PARRIES the touch and
            -- counters for more than the drain heals, so the Suppliant's net health goes DOWN and the
            -- rule looks broken when it is working exactly as authored.
            local map = Fixture.new(10, 10)
            local c = Fixture.combat(map,
                { unit("character_knight", 4, 4, { isolate = "bare" }) },
                { unit("character_the_suppliant", 5, 4) })
            local sup, victim
            for _, u in ipairs(c.units) do
                if u.side == "party" then victim = u else sup = u end
            end
            -- 40 off 180 leaves it at 78%, comfortably above its own `stopsAskingBelow` -- so this case
            -- reads the CONDITION and not the phase past it (which is the case below).
            Combat.dealFlatDamage(c, sup, 40, {}, "test")
            local hurt = Fixture.hp(sup)

            -- A BODY THAT HAS NOT STOOD UP YET IS NOT A BODY THAT HELD ITS TURN. The gate is a fact
            -- about a turn already taken, so the victim has to actually take one -- and hold it.
            assert(not Combat.heldItsTurn(victim), "nobody has been asked anything yet")
            victim.initiative, sup.initiative = 0, 5
            assert(Combat.startTurn(c) == victim, "the victim is up first")
            Combat.pass(c, victim) -- holds: reaches for no pool at all
            assert(Combat.heldItsTurn(victim), "and comes back around having spent nothing")

            local stam = victim.char.stats.stamina.current
            openTurn(c, sup)
            assert(Combat.useItem(c, sup, itemNamed(sup.char, "weapon_petal_touch"), victim.x, victim.y),
                "the Suppliant acts")
            assert(victim.char.stats.stamina.current < stam, "it draws off what was held back")
            assert(Fixture.hp(sup) > hurt, "and takes it into itself")
        end,
    },
    {
        name = "a body that SPENT its turn is passed over -- the dilemma, not a tax",
        fn = function()
            local map = Fixture.new(10, 10)
            local c = Fixture.combat(map,
                { unit("character_knight", 4, 4, { isolate = "bare" }) },
                { unit("character_the_suppliant", 5, 4) })
            local sup, victim
            for _, u in ipairs(c.units) do
                if u.side == "party" then victim = u else sup = u end
            end

            victim.initiative, sup.initiative = 0, 5
            assert(Combat.startTurn(c) == victim, "the victim is up first")
            -- Paid through Combat.spendCost, the one path every cast in the game pays through -- the
            -- seam the tally is kept at, rather than a field poked directly into the unit.
            Combat.spendCost(c, victim, { stat = "stamina", amount = 3 })
            Combat.pass(c, victim)
            assert(not Combat.heldItsTurn(victim), "it spent, so it held nothing back")

            local stam = victim.char.stats.stamina.current
            openTurn(c, sup)
            assert(Combat.useItem(c, sup, itemNamed(sup.char, "weapon_petal_touch"), victim.x, victim.y),
                "the Suppliant acts")
            assert(victim.char.stats.stamina.current == stam, "and the bowl passes it over")
        end,
    },
    {
        name = "past half health the Suppliant stops asking, and drains a body that spent",
        fn = function()
            local map = Fixture.new(10, 10)
            local c = Fixture.combat(map,
                { unit("character_knight", 4, 4, { isolate = "bare" }) },
                { unit("character_the_suppliant", 5, 4) })
            local sup, victim
            for _, u in ipairs(c.units) do
                if u.side == "party" then victim = u else sup = u end
            end

            victim.initiative, sup.initiative = 0, 5
            assert(Combat.startTurn(c) == victim, "the victim is up first")
            Combat.spendCost(c, victim, { stat = "stamina", amount = 3 })
            Combat.pass(c, victim)
            assert(not Combat.heldItsTurn(victim), "the same body the case above is passed over")

            -- 100 off 180 puts it at 44%, under its threshold: the condition comes off and the rule is
            -- Luxuria's. This is the tier's promise -- the mini sin's second phase is its general's
            -- first -- and it is a promise about the SAME victim the gate just spared.
            Combat.dealFlatDamage(c, sup, 100, {}, "test")
            local stam = victim.char.stats.stamina.current
            openTurn(c, sup)
            assert(Combat.useItem(c, sup, itemNamed(sup.char, "weapon_petal_touch"), victim.x, victim.y),
                "the Suppliant acts")
            assert(victim.char.stats.stamina.current < stam, "it stops asking, and takes it anyway")
        end,
    },
    {
        name = "the Suppliant stops asking on the same beat its relic sheds the grove",
        fn = function()
            -- Two authored numbers, in two files, that have to mean one moment: the trait's threshold
            -- and the relic's phase. Apart, the fight makes a promise ("The Suppliant stops asking.")
            -- on a beat where nothing about the drain changed.
            local def = Trait.defs["trait_unasked"]
            local relic = Item.defs["utility_offered_nothing"]
            assert(def.stopsAskingBelow, "the condition comes off somewhere")
            assert(relic.phases and relic.phases[1], "and the relic phases somewhere")
            assert(def.stopsAskingBelow == relic.phases[1].at,
                "the drain's threshold and the relic's phase are the same moment")
        end,
    },
    {
        name = "the Unasked is Rapture with a condition on it",
        fn = function()
            local mine = Trait.defs["trait_unasked"]
            local hers = Trait.defs["trait_rapture"]
            assert(mine and hers, "both rules exist")
            assert(mine.stamina < hers.stamina and mine.mana < hers.mana,
                "the mini sin takes less per hit than its general")
            -- Both must honour Xin's counter, or the one answer to the sin works on only half of it.
            for _, id in ipairs({ "trait_unasked", "trait_rapture" }) do
                local src = love.filesystem.read("data/traits/" .. id .. ".lua")
                assert(src and src:find("trait_devotion_unbidden", 1, true),
                    id .. " must honour a will that gave everything away")
            end
        end,
    },
    {
        name = "a Chorister Charms as it acts, then has to wait",
        fn = function()
            local map = Fixture.new(10, 10)
            local c = Fixture.combat(map,
                { unit("character_knight", 4, 4) },
                { unit("character_chorister", 5, 4) })
            local chor, victim
            for _, u in ipairs(c.units) do
                if u.side == "party" then victim = u else chor = u end
            end
            openTurn(c, chor)
            assert(Combat.useItem(c, chor, itemNamed(chor.char, "weapon_petal_touch"), victim.x, victim.y),
                "the chorister sings")
            assert(Status.has(victim, "status_charm"), "and somebody goes to it")

            local def = Trait.defs["trait_lure"]
            assert(def.cooldown and def.cooldown > 0,
                "the cooldown is what makes it a decision rather than a lock")
        end,
    },
    {
        name = "cut the singer down and what it took comes back",
        fn = function()
            local map = Fixture.new(10, 10)
            local c = Fixture.combat(map,
                { unit("character_knight", 4, 4) },
                { unit("character_chorister", 5, 4) })
            local chor, victim
            for _, u in ipairs(c.units) do
                if u.side == "party" then victim = u else chor = u end
            end
            openTurn(c, chor)
            assert(Combat.useItem(c, chor, itemNamed(chor.char, "weapon_petal_touch"), victim.x, victim.y),
                "the chorister sings")
            assert(Status.has(victim, "status_charm") and victim.side == "enemy",
                "and the knight is standing on their line")

            -- The counterplay the circle is written to be read as: kill the thing that took it.
            Combat.dealFlatDamage(c, chor, 9999, { "physical" }, "test")
            assert(not chor.alive, "the singer falls")
            assert(not Status.has(victim, "status_charm"), "and the charm falls with it")
            assert(victim.side == "party" and victim.control ~= "ai",
                "the knight is yours again, command and all")
        end,
    },
    {
        name = "ground charms nobody, so no death frees it",
        fn = function()
            local map = Fixture.new(10, 10)
            local c = Fixture.combat(map,
                { unit("character_knight", 4, 4) },
                { unit("character_chorister", 8, 8) })
            local chor, victim
            for _, u in ipairs(c.units) do
                if u.side == "party" then victim = u else chor = u end
            end
            -- A briar names no applier: the charm is the ground's, and the ground outlives everyone.
            Status.apply(c, victim, "status_charm", { duration = 6 })
            assert(victim.side == "enemy", "the flowers take it all the same")
            Combat.dealFlatDamage(c, chor, 9999, { "physical" }, "test")
            assert(Status.has(victim, "status_charm"),
                "a body nobody is holding is not let go by a death")
        end,
    },
    {
        name = "the Beloved makes the choice worse rather than the fight",
        fn = function()
            local dev = Item.defs["utility_beloveds_devotion"]
            assert(dev and dev.phases and #dev.phases == 2, "it sheds twice")
            for _, phase in ipairs(dev.phases) do
                for _, r in ipairs(phase.responses or {}) do
                    if r.kind == "summon" then
                        assert(r.id == "character_petal_drift",
                            "it sheds the chaff that makes holding your good ability feel correct")
                    end
                    assert(r.kind ~= "bonus" or r.amount < 0,
                        "the apex escalates the dilemma, not its own stat line")
                end
            end
        end,
    },

    -- ------------------------------------------------------------ both mini sins sit in band
    {
        name = "both mini sins sit between their line body and their general",
        fn = function()
            for _, case in ipairs({
                { mini = "character_the_tally", general = "character_general_greed",
                  line = "character_coffer_crawler" },
                { mini = "character_the_suppliant", general = "character_general_lust",
                  line = "character_bloom_wraith" },
            }) do
                local mini = Character.defs[case.mini]
                local gen = Character.defs[case.general]
                assert(mini.boss and mini.referenceLevel, case.mini .. ": a centrepiece that scales down")
                assert(mini.stats.health > Character.defs[case.line].stats.health,
                    case.mini .. " must outweigh its circle's line body")
                local share = mini.stats.health / gen.stats.health
                assert(share > 0.6 and share < 0.85, string.format(
                    "%s is %.0f%% of its general; the tier sits between 60%% and 85%%",
                    case.mini, share * 100))
            end
        end,
    },
    {
        name = "every Greed and Lust item is natural kit and nothing else",
        fn = function()
            for _, id in ipairs({ "weapon_cutpurse_nip", "weapon_coffer_shell", "weapon_gilt_maw",
                                  "utility_assay_scales", "utility_the_reckoning", "utility_the_hoard",
                                  "weapon_petal_touch", "weapon_bloom_reach", "weapon_antler_crown",
                                  "utility_chorister_call", "utility_offered_nothing",
                                  "utility_beloveds_devotion" }) do
                local def = Item.defs[id]
                assert(def, id .. " does not exist")
                assert(def.noSteal and not def.price and def.class == "creature",
                    id .. ": creature kit is unpriced, unshelved and unstealable")
            end
        end,
    },
    -- ------------------------------------------------------------ LUST, RE-PREMISED (2026-09-22)
    --
    -- The circle is five verbs -- Charm, Taunt, Root, Wind, Fire -- and one sentence: it never takes
    -- your health, it takes your say over where you are standing and who you are standing for. The
    -- cases below hold the three of those five that are now on the flock and its alpha (Root, Wind,
    -- Fire) and the one interaction that is the circle's own counterplay. See the Lust entry in
    -- models/descent.lua for the whole argument, including the verb that is NOT wired.
    {
        name = "the flock is one verb pointed both ways: the talons haul in, the gust drives off",
        fn = function()
            local map = Fixture.new(12, 12)
            local c = Fixture.combat(map, { unit("character_knight", 5, 5) },
                                          { unit("character_harpy", 5, 8) })
            local harpy, knight
            for _, u in ipairs(c.units) do
                if u.char.id == "character_harpy" then harpy = u else knight = u end
            end

            -- THE STOOP drives a body one tile straight off the bird -- worth nothing on this bare
            -- fixture and everything in the Thinwall Keep, where the tile behind you is a wall and
            -- Combat.knockback bills the impact of a shove it could not finish.
            openTurn(c, harpy)
            local y = knight.y
            Combat.useItem(c, harpy, itemNamed(harpy.char, "weapon_stooping_gust"), knight.x, knight.y)
            assert(knight.y == y - 1, "the gust drives a body one tile off the harpy")

            -- THE SNATCH is the same verb reversed: it hauls a body out of its line and onto the bird.
            -- A flock that only pushed would scatter a company; a flock that only pulled would gather
            -- it into a heap, which is the one arrangement a party actually wants. Both is what
            -- unpicks a rank.
            harpy.x, harpy.y = knight.x, knight.y + 2
            openTurn(c, harpy)
            Combat.useItem(c, harpy, itemNamed(harpy.char, "weapon_harpy_talons"), knight.x, knight.y)
            assert(math.max(math.abs(knight.x - harpy.x), math.abs(knight.y - harpy.y)) == 1,
                "the talons haul their mark to the bird's side")
        end,
    },
    {
        name = "nothing on this stratum holds a body still",
        fn = function()
            -- ROOT IS OFF THIS GROUND AND THE REASON IS MECHANICAL, not flavour. The talons pinned in
            -- the first cut of this circle, and Root sets `blocksForcedMove` -- so a rooted victim
            -- cannot be shoved or dragged by ANYBODY, and the line body was quietly switching the rest
            -- of the circle off one target at a time. A stratum built on displacement must not hold.
            -- Asserted rather than written down, because "the talons also pin" is a one-line change
            -- that reads like an improvement.
            local map = Fixture.new(12, 12)
            local c = Fixture.combat(map, { unit("character_knight", 5, 5) },
                                          { unit("character_harpy", 5, 7) })
            local harpy, knight
            for _, u in ipairs(c.units) do
                if u.char.id == "character_harpy" then harpy = u else knight = u end
            end
            openTurn(c, harpy)
            Combat.useItem(c, harpy, itemNamed(harpy.char, "weapon_harpy_talons"), knight.x, knight.y)
            assert(not Status.get(knight, "status_root"),
                "the flock moves you and never holds you")
            assert(not Status.get(knight, "status_halted") and not Status.get(knight, "status_mired"),
                "...and it does not hold you under another name either")
        end,
    },
    {
        name = "the Matriarch's cry takes the body out of the player's hands and lights it",
        fn = function()
            local map = Fixture.new(12, 12)
            local c = Fixture.combat(map, { unit("character_knight", 5, 5) },
                                          { unit("character_harpy_matriarch", 5, 9) })
            local mother, knight
            for _, u in ipairs(c.units) do
                if u.char.id == "character_harpy_matriarch" then mother = u else knight = u end
            end
            assert(Combat.isPlayerControlled(knight), "the knight starts out the player's")
            openTurn(c, mother)
            Combat.useItem(c, mother, itemNamed(mother.char, "weapon_the_wanting"), knight.x, knight.y)

            -- SHE ESCALATES IN KIND. The flock decides where your body is; she decides what it does --
            -- the victim spends its own turns walking to her, and the burn is what the walking costs.
            local st = Status.get(knight, "status_taunt")
            assert(st and st.taunter == mother, "the cry points the victim back at her")
            assert(not Combat.isPlayerControlled(knight),
                "and the compulsion is real: a called body takes no orders (status_taunt's seizure)")
            assert(Status.get(knight, "status_burn"), "the coming is what burns")

            -- SHE DOES NOT MOVE IT. That is the flock's verb and she deliberately does not share it --
            -- a cry that also dragged would make her a louder harpy instead of a different problem.
            assert(knight.x == 5 and knight.y == 5, "the cry calls; it does not haul")

            -- AND CUTTING HER DOWN HANDS IT BACK, which is this circle's standing counterplay and the
            -- only reason the compulsion is fair. Driven from the clock, so it covers a taunter that
            -- merely stopped being hostile as well as one that fell.
            mother.alive = false
            Status.tick(c, 5)
            assert(Combat.isPlayerControlled(knight), "the jeer dies with the jeerer")
        end,
    },
    {
        name = "Downdraft clears the whole room, not only the hand that reached in",
        fn = function()
            local map = Fixture.new(12, 12)
            local c = Fixture.combat(map,
                { unit("character_knight", 5, 5), unit("character_knight", 6, 6) },
                { unit("character_harpy_matriarch", 5, 6) })
            local mother
            for _, u in ipairs(c.units) do
                if u.char.id == "character_harpy_matriarch" then mother = u end
            end
            for _, u in ipairs(c.units) do Combat.refreshPassives(u) end
            local party = {}
            for _, u in ipairs(c.units) do if u.side == "party" then party[#party + 1] = u end end
            local before = {}
            for i, u in ipairs(party) do before[i] = { u.x, u.y } end
            local stamina = mother.char.stats.stamina.current

            -- DISPATCHED DIRECTLY rather than by swinging at her, and the reason is the harness and not
            -- the rule: an on-hit reflex is HELD until the action finishes (Combat.beginAnswers) and a
            -- fixture's bare Combat.useItem never opens the turn machinery that flushes the hold. The
            -- shipped Antler Toss and Shield Shove are equally silent in exactly the same fixture, so a
            -- case built on the swing would be measuring the scaffolding. This is the call the live
            -- path makes, carrying the snapshot the live path carries (see Combat's raiseAnswer).
            Trait.onDamaged(c, mother, {
                attacker = party[1], amount = 10,
                tags = { "physical", "pierce", "melee" },
                at = { answering = false, ux = mother.x, uy = mother.y,
                       ax = party[1].x, ay = party[1].y },
            })

            local moved = 0
            for i, u in ipairs(party) do
                if u.x ~= before[i][1] or u.y ~= before[i][2] then moved = moved + 1 end
            end
            assert(moved == #party, string.format(
                "the wing-beat takes everything adjacent (Whirl Answer's shape in this circle's verb); "
                .. "%d of %d moved", moved, #party))
            assert(mother.char.stats.stamina.current < stamina,
                "and she pays for it, which is what paces her being surrounded")
        end,
    },
    {
        name = "the Matriarch is the harpy escalated, not a second animal",
        fn = function()
            local flock, alpha = Character.defs.character_harpy, Character.defs.character_harpy_matriarch
            assert(flock and alpha, "the Lust circle fields a flock and an alpha")
            assert(flock.tier == 2 and alpha.tier == 3, "line body, then elite")
            assert(alpha.stats.health > flock.stats.health, "the alpha outweighs its own flock")
            -- THE SAME BIRD, which is the whole reason the escalation reads without a word of
            -- explanation: identical resist SHAPE, deeper, so a party that learned to shoot the flock
            -- is right about her too. A different profile here would make her a second lesson.
            for _, key in ipairs({ "slash", "pierce", "fire", "holy" }) do
                local a, b = flock.resist[key], alpha.resist[key]
                assert(a and b, "both carry a " .. key .. " line")
                assert((a < 0) == (b < 0), key .. ": the alpha must lean the way its flock leans")
                assert(math.abs(b) >= math.abs(a), key .. ": the alpha is the deeper version of it")
            end
            -- The two weapons the flock swings are hers as well; the cry and the feathers are what she
            -- adds. Anything else and the escalation stops being an escalation.
            local hers = {}
            for _, id in ipairs(alpha.startingItems) do hers[id] = true end
            for _, id in ipairs(flock.startingItems) do
                assert(hers[id], "the alpha drops the flock's own " .. id)
            end
            assert(hers.weapon_the_wanting and hers.utility_flight_feathers,
                "and she carries the cry and the wing-beat on top")
        end,
    },
    {
        name = "the castle fields an ordinary fight and an elite again",
        fn = function()
            -- THE 2026-09-22 CUT LEFT THIS GROUND AT 0/0 -- Lust's two floors rolled nothing at all,
            -- which is a playability break rather than thinning. Measured the way that hole was
            -- measured: the floor pool derives its circle from ctx.quest.sin, so a ctx without it
            -- silently skips the elite billing entirely.
            local Encounter = require("models.encounter")
            local combat, elite = 0, 0
            for _, row in ipairs(Encounter.pool({ biome = "castle", depth = 3, rung = 2,
                                                  quest = { sin = "lust" } })) do
                if row.kind == "elite" then elite = elite + 1
                elseif row.kind == "combat" then combat = combat + 1 end
            end
            assert(combat >= 1, "the castle rolls no ordinary fight at all")
            assert(elite >= 1, "the castle rolls no elite at all")
        end,
    },
    -- ------------------------------------------------------------ WHAT THE FLOCK IS KNOWN FOR
    --
    -- The rift sells you the trick (docs/drops.md, and the Barrow Lord's Marrowlight argues the
    -- ordering): each of these two is the thing the body spent the fight doing to you, handed over.
    {
        name = "the flock's drop is its gust, and a bow does not get it",
        fn = function()
            local map = Fixture.new(12, 12)
            local c = Fixture.combat(map,
                { unit("character_knight", 5, 5, { isolate = "bare",
                      items = { "weapon_iron_sword", "weapon_corvids_bow",
                                "utility_the_updraught" } }) },
                { unit("character_harpy", 5, 6), unit("character_harpy", 5, 9) })
            local knight, near, far
            for _, u in ipairs(c.units) do
                if u.char.id == "character_knight" then knight = u
                elseif not near then near = u else far = u end
            end
            for _, u in ipairs(c.units) do Combat.refreshPassives(u) end

            -- MELEE: the blow lands and the body it landed on goes back a tile, away from the swinger.
            openTurn(c, knight)
            local y = near.y
            Combat.useItem(c, knight, itemNamed(knight.char, "weapon_iron_sword"), near.x, near.y)
            assert(near.alive and near.y == y + 1,
                "a melee blow drives what it hit back a tile")

            -- RANGED: nothing moves, and that is the item's PRICE rather than a category. On a bow this
            -- would be a free disengage on every arrow -- strictly good, never once a decision. On a
            -- blade it costs the follow-up, because the thing you just hit is now out of reach.
            openTurn(c, knight)
            local fy = far.y
            Combat.useItem(c, knight, itemNamed(knight.char, "weapon_corvids_bow"), far.x, far.y)
            assert(far.alive and far.y == fy,
                "an arrow shoves nobody -- the reach is what pays for the control")
        end,
    },
    {
        name = "the Matriarch's drop is her cry factored: what you taunt, burns",
        fn = function()
            local map = Fixture.new(12, 12)
            local c = Fixture.combat(map,
                { unit("character_knight", 5, 5, { isolate = "bare", items = { "utility_coalsong" } }) },
                { unit("character_harpy", 5, 6) })
            local knight, harpy
            for _, u in ipairs(c.units) do
                if u.char.id == "character_knight" then knight = u else harpy = u end
            end
            for _, u in ipairs(c.units) do Combat.refreshPassives(u) end

            -- THE COUPLING, NOT THE CAST. It fires on whatever taunt the bearer already owns, which is
            -- what makes it half of a pair rather than a tier -- on a body with no taunt in its kit it
            -- is a blank cell, deliberately.
            Status.apply(c, harpy, "status_taunt", { applier = knight })
            assert(Status.get(harpy, "status_burn"),
                "a foe the bearer taunts catches fire")

            -- AND ONLY ON THE APPLIER'S SIDE OF IT. Being taunted is not taunting: without the role
            -- gate the charm would light its own wearer every time an enemy jeered at them, which is
            -- the same rule read backwards and strictly a downside.
            local victim = c.units[1]
            Status.remove(c, victim, "status_burn")
            Status.apply(c, victim, "status_taunt", { applier = harpy })
            assert(not Status.get(victim, "status_burn"),
                "being taunted is not taunting -- the charm reads the applier's side only")
        end,
    },
    {
        name = "both bodies are known for something, and neither trophy is merchandise",
        fn = function()
            -- A DROP IS A HEAD START, NOT A SOURCE OF RECORD (docs/drops.md): no price, so a counter
            -- deals it only once the class has climbed to its rung, and the rift pays it early and
            -- free before that. `unlockLevel` is the DERIVED half -- `. drop-tier` files both off
            -- their grades -- so this asserts that one exists rather than pinning the figure, which
            -- would go stale the next time the ladder is re-cut.
            local flock = Character.defs.character_harpy.drops
            local alpha = Character.defs.character_harpy_matriarch.drops
            assert(flock and #flock > 0, "the flock is known for nothing")
            assert(alpha and #alpha > 0, "the alpha is known for nothing")
            assert(flock[1] == "utility_the_updraught", "the flock hands over its gust")
            assert(alpha[1] == "utility_coalsong", "the alpha hands over her cry, first")

            for _, id in ipairs({ "utility_the_updraught", "utility_coalsong" }) do
                local def = Item.defs[id]
                assert(def, id .. " does not exist")
                assert(not def.price, id .. ": a rift find carries no price")
                assert(def.unlockLevel, id .. ": every graded ware sits somewhere on the ladder")
                assert(def.class and def.class ~= "creature",
                    id .. ": a drop is a player's ware and belongs on a real shelf")
            end
        end,
    },
    -- ------------------------------------------------------------ THE COILS
    --
    -- The circle's second animal, and the opposite half of the flock's rule. A harpy decides where
    -- your body is; a lamia decides that it does not get to be anywhere else. See the Lust entry in
    -- models/descent.lua for why the two are authored to make each other worse.
    {
        name = "one sentence at two lengths: the knot takes the turn, the fang takes the ground",
        fn = function()
            local map = Fixture.new(14, 14)
            local c = Fixture.combat(map, { unit("character_knight", 5, 5) },
                                          { unit("character_lamia", 5, 8) })
            local lamia, knight
            for _, u in ipairs(c.units) do
                if u.char.id == "character_lamia" then lamia = u else knight = u end
            end

            -- THE FANG at reach: no pin, no clock -- a string.
            openTurn(c, lamia)
            Combat.useItem(c, lamia, itemNamed(lamia.char, "weapon_lunging_fang"), knight.x, knight.y)
            local st = Status.get(knight, "status_coiled")
            assert(st and st.coiler == lamia, "the fang leaves a tether that knows what it measures from")
            assert(not Status.get(knight, "status_root"), "and it does not pin -- that is the other weapon")

            -- THE KNOT at melee: the circle's fifth verb, returned on the one body that displaces
            -- nothing. See the Lust entry for the condition that was written down before it came back.
            lamia.x, lamia.y = knight.x, knight.y + 1
            openTurn(c, lamia)
            Combat.useItem(c, lamia, itemNamed(lamia.char, "weapon_strangleknot"), knight.x, knight.y)
            assert(Status.get(knight, "status_root"), "the knot pins what it winds around")
        end,
    },
    {
        name = "the coil is a price, not a lock -- and it is the circle it charges for",
        fn = function()
            local map = Fixture.new(14, 14)
            local c = Fixture.combat(map, { unit("character_knight", 5, 5) },
                                          { unit("character_lamia", 5, 8) })
            local lamia, knight
            for _, u in ipairs(c.units) do
                if u.char.id == "character_lamia" then lamia = u else knight = u end
            end
            openTurn(c, lamia)
            Combat.useItem(c, lamia, itemNamed(lamia.char, "weapon_lunging_fang"), knight.x, knight.y)
            assert(Status.get(knight, "status_coiled"), "coiled to begin with")

            -- INSIDE THE CIRCLE costs nothing. A tether that bit wherever you stood would be a poison
            -- with a serpent painted on it; what makes it a decision is that obeying it is free.
            knight.x, knight.y = lamia.x, lamia.y - 2
            local before = Fixture.hp(knight)
            Status.onTurnEnd(c, knight)
            assert(Fixture.hp(knight) == before, "two tiles is inside the coils and costs nothing")

            -- OUTSIDE IT, the walking is what costs -- and the victim keeps its whole turn either way,
            -- which is the entire difference from the Root the same body deals at melee.
            knight.x, knight.y = lamia.x, lamia.y - 5
            before = Fixture.hp(knight)
            Status.onTurnEnd(c, knight)
            assert(Fixture.hp(knight) < before, "a turn ended outside the circle closes the coil")
        end,
    },
    {
        name = "the Elder's coil is a slope, and the slope has a ceiling",
        fn = function()
            local map = Fixture.new(16, 16)
            local c = Fixture.combat(map, { unit("character_knight", 5, 5) },
                                          { unit("character_elder_lamia", 5, 8) })
            local elder, knight
            for _, u in ipairs(c.units) do
                if u.char.id == "character_elder_lamia" then elder = u else knight = u end
            end
            for _, u in ipairs(c.units) do Combat.refreshPassives(u) end
            openTurn(c, elder)
            Combat.useItem(c, elder, itemNamed(elder.char, "weapon_lunging_fang"), knight.x, knight.y)
            local st = Status.get(knight, "status_coiled")
            assert(st and st.perTile and st.perTile > 0,
                "an Elder's application carries the slope (trait_the_long_coil stamps it)")
            -- ...AND IT RIDES A RELIC, like every creature rule: a blueprint's own `traits` field is
            -- never collected (models/trait.lua), so the slope lives in her grid where a Sunder can
            -- silence it and a corpse can be looted for the idea.
            assert(itemNamed(elder.char, "utility_serpents_length"),
                "the slope rides Serpent's Length in her grid, not a bare field on the blueprint")

            local function bite(gap)
                knight.x, knight.y = elder.x, elder.y - gap
                local before = Fixture.hp(knight)
                Status.onTurnEnd(c, knight)
                return before - Fixture.hp(knight)
            end

            -- THE SLOPE: further is dearer, which turns "whether to leave" into "how far".
            local near, far = bite(3), bite(5)
            assert(far > near, "every tile past the circle is worth another bite")

            -- ...AND THE CEILING, which is what keeps a curve from becoming a second attack the victim
            -- delivers to itself. Measured before the cap existed this billed 17 raw a turn at five
            -- tiles -- a full melee hit from her, unmitigated, on top of the ones she was throwing,
            -- and more than a GENERAL'S oath bills. Stated as a multiple of the flat toll so the two
            -- cannot drift apart.
            local def = Status.defs and Status.defs.status_coiled
            local flat = (def and def.magnitude) or st.magnitude
            local scale = (def and def.maxScale) or 2
            assert(bite(9) <= flat * scale,
                "the slope may double the toll and no more -- running has to stop mattering somewhere")
        end,
    },
    {
        name = "the coil dies with the serpent, which is this circle's standing law",
        fn = function()
            -- EVERY CONTROL EFFECT IN LUST ENDS WITH THE BODY HOLDING IT: a charm with its charmer
            -- (Combat.releaseCharmedBy), a jeer with its taunter (status_taunt's onTick), a coil with
            -- the serpent. Deliberately the OPPOSITE of Acedia's Sworn, whose own header insists the
            -- oath "does not release you for having failed it" -- two circles, two laws, and this one
            -- is the reason cutting the thing that did it is the whole counterplay of the stratum.
            local map = Fixture.new(14, 14)
            local c = Fixture.combat(map, { unit("character_knight", 5, 5) },
                                          { unit("character_lamia", 5, 8) })
            local lamia, knight
            for _, u in ipairs(c.units) do
                if u.char.id == "character_lamia" then lamia = u else knight = u end
            end
            openTurn(c, lamia)
            Combat.useItem(c, lamia, itemNamed(lamia.char, "weapon_lunging_fang"), knight.x, knight.y)
            lamia.alive = false
            knight.x, knight.y = 13, 13 -- as far from the corpse as the board allows
            local before = Fixture.hp(knight)
            Status.onTurnEnd(c, knight)
            assert(Fixture.hp(knight) == before, "a dead serpent bills nobody")
            assert(not Status.get(knight, "status_coiled"), "and the badge goes with it")
        end,
    },
    {
        name = "the two animals argue, and the argument is left in",
        fn = function()
            -- A ROOTED BODY CANNOT BE SHOVED (status_root's `blocksForcedMove`), so a company caught
            -- in the coils is sheltered from the wind. That is a texture rather than a bug: being
            -- pinned next to a serpent is a real alternative to being scattered by a flock, and
            -- choosing which of the two to be caught by is a decision the player makes on the board.
            -- Pinned here because it reads like an oversight to anyone who meets it cold.
            local map = Fixture.new(14, 14)
            local c = Fixture.combat(map, { unit("character_knight", 5, 5) },
                { unit("character_lamia", 5, 6), unit("character_harpy", 5, 9) })
            local lamia, harpy, knight
            for _, u in ipairs(c.units) do
                if u.char.id == "character_lamia" then lamia = u
                elseif u.char.id == "character_harpy" then harpy = u else knight = u end
            end
            openTurn(c, lamia)
            Combat.useItem(c, lamia, itemNamed(lamia.char, "weapon_strangleknot"), knight.x, knight.y)
            assert(Status.get(knight, "status_root"), "held by the coils")

            openTurn(c, harpy)
            local y = knight.y
            Combat.useItem(c, harpy, itemNamed(harpy.char, "weapon_stooping_gust"), knight.x, knight.y)
            assert(knight.y == y,
                "the flock cannot throw what the coils are holding -- the stratum's two animals are "
                .. "not additive, and were never meant to be")
        end,
    },
    {
        name = "the coils' drops are a pair, and the circle sells you both halves",
        fn = function()
            local line = Character.defs.character_lamia.drops
            local alpha = Character.defs.character_elder_lamia.drops
            assert(line and line[1] == "utility_the_slow_circle", "the lamia hands over its string")
            assert(alpha and alpha[1] == "utility_constrictors_due", "the Elder hands over her patience")

            for _, id in ipairs({ "utility_the_slow_circle", "utility_constrictors_due" }) do
                local def = Item.defs[id]
                assert(def, id .. " does not exist")
                assert(not def.price, id .. ": a rift find carries no price")
                assert(def.unlockLevel, id .. ": every graded ware sits somewhere on the ladder")
                assert(def.class and def.class ~= "creature",
                    id .. ": a drop is a player's ware and belongs on a real shelf")
            end

            -- THE PAIR, ASSERTED RATHER THAN WRITTEN DOWN. One puts a body in a hold and the other
            -- bills for it, so a player who walks out with both has been taught a rule in two halves
            -- and sold both -- and a player who walks out with one has a reason to go back down. If
            -- the Due ever stops reading the status the Circle applies, the pair is silently over and
            -- nothing else in the suite would say so.
            local map = Fixture.new(12, 12)
            local c = Fixture.combat(map,
                { unit("character_knight", 5, 5, { isolate = "bare",
                      items = { "weapon_iron_sword", "utility_constrictors_due" } }) },
                { unit("character_lamia", 5, 6) })
            local knight, foe = c.units[1], c.units[2]
            for _, u in ipairs(c.units) do Combat.refreshPassives(u) end
            local sword = itemNamed(knight.char, "weapon_iron_sword")
            assert(Trait.outgoingDamageBonus(c, knight, foe, sword, { "melee" }) == 0,
                "a free body owes nothing")
            local st = Status.apply(c, foe, "status_coiled")
            st.coiler = knight
            assert(Trait.outgoingDamageBonus(c, knight, foe, sword, { "melee" }) > 0,
                "and a coiled one owes the constrictor's due")
        end,
    },
    {
        name = "every harpy item is natural kit and nothing else",
        fn = function()
            for _, id in ipairs({ "weapon_harpy_talons", "weapon_stooping_gust", "weapon_the_wanting",
                                  "utility_flight_feathers" }) do
                local def = Item.defs[id]
                assert(def, id .. " does not exist")
                assert(def.noSteal and not def.price and def.class == "creature",
                    id .. ": creature kit is unpriced, unshelved and unstealable")
            end
        end,
    },
}
