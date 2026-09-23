-- Tests for the GREED and LUST circles -- the last two strata, and the two whose rules are about
-- resources rather than about the board.
--
-- The tier's design rule, pinned as it is for every other circle: A MINI SIN'S SECOND PHASE IS ITS
-- GENERAL'S FIRST.
--
--   Aurea lifts an ITEM off an adjacent body from her opening bell; the Reckoning takes coin, and starts
--   taking gear at half health.
--   Luxuria drains a foe's held-back reserves on EVERY hit; the Unasked drains only a body that spent
--   nothing, and drops the condition at half health.
--
-- BOTH BODIES THAT CARRIED THOSE RULES ARE GONE. The Tally and the Suppliant were deleted with the other
-- five lieutenants (2026-09-22, Descent.SINS' header) and their naturals are not: the rules above are
-- pinned on the ITEMS now, and the Lust cases dress a stand-in in the Suppliant's kit rather than assert
-- about a blueprint. That is a weaker case on purpose -- it measures the rule and not the fight -- and it
-- reddens the day a replacement wears the bowl for real.
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

-- LUST'S DRAIN, WITHOUT THE BODY THAT CARRIED IT. `trait_unasked` and `utility_offered_nothing` are the
-- Suppliant's and she is deleted, so the three cases below dress Lust's own stand-in lieutenant in her
-- kit: the bowl, the touch, and the 180 health the arithmetic in those cases is written against (40 off
-- it reads 78%, comfortably above the threshold; 100 off reads 44%, under it). `isolate = "bare"` empties
-- the grid first, so what the host swings is only what is handed to it here.
local function unasked(x, y)
    return unit("character_lamia", x, y, {
        isolate = "bare",
        items = { "weapon_petal_touch", "utility_offered_nothing" },
        stats = { health = 180 },
    })
end

-- GREED'S SCALES, THE SAME WAY, AND GREED HAS EVEN LESS LEFT. The cut took the whole stratum -- the
-- Assayer, the Chorister, the Coin-Chitter, the Hoard and the Beloved -- and what survived it is
-- `trait_assayed` and the one piece that grants it. So the two purse cases dress a stand-in in the
-- Reckoning rather than field a body authored to read a purse: the scales are the subject and the
-- scales are still here. Health well clear of the Reckoning's own half-health phase, so nothing the
-- case does can trip it.
local function assayed(x, y)
    return unit("character_slime", x, y, {
        isolate = "bare",
        items = { "utility_the_reckoning" },
        stats = { health = 200 },
    })
end

return {
    -- ------------------------------------------------------------ both stairs
    {
        -- BOTH LIEUTENANTS ARE DELETED AND THIS CASE IS THE MARKER. Each slot holds ordinary traffic
        -- off its own ground as a stand-in (see the lieutenant note at the head of Descent.SINS). They
        -- are named here on purpose: seating a replacement reddens this case, and whoever does it owes
        -- the contract written out where the sizing case used to be, at the foot of this file.
        name = "Greed's and Lust's lieutenant slots are filled, and by stand-ins that say so",
        fn = function()
            assert(sinNamed("greed").minor.lead == "character_fen_lancer", "a lancer stands in for the Tally")
            assert(sinNamed("lust").minor.lead == "character_lamia", "a lamia stands in for the Suppliant")
            assert(not Character.defs["character_the_tally"], "the Tally is gone")
            assert(not Character.defs["character_the_suppliant"], "the Suppliant is gone")
            for _, id in ipairs({ "greed", "lust" }) do
                local sin = sinNamed(id)
                assert(Character.defs[sin.minor.lead], id .. "'s stand-in is a body that loads")
                assert(sin.guardian.filler == sin.minor.lead,
                    id .. "'s approach body must fill out its own general's stair")
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
                { assayed(6, 6) })
            local assayer
            for _, u in ipairs(c.units) do
                if u.side ~= "party" then assayer = u end
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
                { assayed(6, 6) })
            local assayer
            for _, u in ipairs(c.units) do
                if u.side ~= "party" then assayer = u end
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
    -- THE HOARD'S OWN CASE IS DELETED WITH THE BODY, and this is what it said, because Greed's apex
    -- is the one in the seven that was not a creature at all:
    --
    --     kind = "object"          the pile itself, not something standing guard over one
    --     footprint 2x2            four tiles of it
    --     two phases, each         what leaves a disturbed hoard is PIECES of it -- the summon was
    --       summoning coin-chitters  character_coin_chitter, carrying as much as it could hold
    --
    -- So the apex got smaller as you opened it and the room filled with the difference, which is the
    -- only apex in the descent that fights by being spent. utility_the_hoard is gone too, so there is
    -- nothing left here to repoint onto. A refill owes that shape or owes an argument against it.

    -- ------------------------------------------------------------ Lust: it reads what you held back
    {
        name = "the Unasked drains a foe and takes half of it as health",
        fn = function()
            -- `isolate = "bare"` empties the victim's grid. Without it a knight PARRIES the touch and
            -- counters for more than the drain heals, so the host's net health goes DOWN and the
            -- rule looks broken when it is working exactly as authored.
            local map = Fixture.new(10, 10)
            local c = Fixture.combat(map,
                { unit("character_knight", 4, 4, { isolate = "bare" }) },
                { unasked(5, 4) })
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
                "the host acts")
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
                { unasked(5, 4) })
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
                "the host acts")
            assert(victim.char.stats.stamina.current == stam, "and the bowl passes it over")
        end,
    },
    {
        name = "past half health the bowl stops asking, and drains a body that spent",
        fn = function()
            local map = Fixture.new(10, 10)
            local c = Fixture.combat(map,
                { unit("character_knight", 4, 4, { isolate = "bare" }) },
                { unasked(5, 4) })
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
                "the host acts")
            assert(victim.char.stats.stamina.current < stam, "it stops asking, and takes it anyway")
        end,
    },
    {
        name = "the bowl stops asking on the same beat its relic sheds the grove",
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
    -- THE CHORISTER'S FIRST CASE IS DELETED WITH ITS TRAIT. It said that the singer Charms as part of
    -- acting and then HAS TO WAIT -- `trait_lure` declared a cooldown, and the cooldown is what made
    -- the song a decision rather than a lock. The trait had one bearer and went with it, so there is
    -- no cooldown anywhere to assert on: the succubus line's charm is priced by a ROLL against the
    -- target's wounds instead (Status.charmChance), which is a different answer to the same worry and
    -- is held by tests/succubus_spec.lua.
    --
    -- THE OTHER TWO SURVIVE, BECAUSE THEIR SUBJECT IS THE RELEASE AND NOT THE SINGER. Who is holding a
    -- charm, and whether a death hands it back, is Combat.releaseCharmedBy and is the circle's whole
    -- counterplay -- so both are staged on the stratum's own live charmer instead, with the status
    -- applied directly rather than rolled for. The roll is succubus_spec's business; this is the rule
    -- underneath it, and it must hold however the charm was landed.
    {
        name = "cut the charmer down and what it took comes back",
        fn = function()
            local map = Fixture.new(10, 10)
            local c = Fixture.combat(map,
                { unit("character_knight", 4, 4) },
                { unit("character_succubus", 5, 4) })
            local charmer, victim
            for _, u in ipairs(c.units) do
                if u.side == "party" then victim = u else charmer = u end
            end
            Status.apply(c, victim, "status_charm", { duration = 6, applier = charmer })
            assert(Status.has(victim, "status_charm") and victim.side == "enemy",
                "and the knight is standing on their line")

            -- The counterplay the circle is written to be read as: kill the thing that took it.
            Combat.dealFlatDamage(c, charmer, 9999, { "physical" }, "test")
            assert(not charmer.alive, "the charmer falls")
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
                { unit("character_succubus", 8, 8) })
            local bystander, victim
            for _, u in ipairs(c.units) do
                if u.side == "party" then victim = u else bystander = u end
            end
            -- A briar names no applier: the charm is the ground's, and the ground outlives everyone.
            Status.apply(c, victim, "status_charm", { duration = 6 })
            assert(victim.side == "enemy", "the flowers take it all the same")
            Combat.dealFlatDamage(c, bystander, 9999, { "physical" }, "test")
            assert(Status.has(victim, "status_charm"),
                "a body nobody is holding is not let go by a death")
        end,
    },
    -- THE BELOVED'S CASE IS DELETED WITH THE APEX, and this is what it said, since it is the one shape
    -- in the seven that escalated by making the PLAYER'S choice worse rather than its own stat line:
    --
    --     utility_beloveds_devotion, two phases
    --     every `bonus` response NEGATIVE       the apex turns itself down as it is cut
    --     every `summon` a character_petal_drift  and fills the room with chaff, so holding your one
    --                                             good ability back keeps feeling like the right call
    --
    -- Both the item and the drift are gone. A Lust apex that escalates by growing would be the
    -- opposite reading, and that is the thing this case existed to refuse.

    -- ------------------------------------------------------------ what a replacement is sized to
    --
    -- THE CASE THAT SIZED BOTH IS GONE WITH THE BODIES, and this is what it said, for either circle:
    --
    --     boss = true and a referenceLevel   a centrepiece that scales down toward the shallows
    --     health above its circle's line     a mini sin outweighs the stock it stands over
    --     health 60-85% of its general's     and stands below the sin whose stair it is holding
    --
    -- The same band tests/wrath_circle_spec.lua argues out in full.
    {
        name = "every Greed and Lust item is natural kit and nothing else",
        fn = function()
            -- Six of the twelve went with the bodies that swung them: weapon_coffer_shell,
            -- utility_assay_scales, utility_the_hoard, weapon_bloom_reach, weapon_antler_crown,
            -- utility_chorister_call and utility_beloveds_devotion. What is left is the naturals a
            -- survivor still carries and the two the deleted mini sins left behind -- and the contract
            -- is the same one either way, so a refill adds its pieces to this list.
            for _, id in ipairs({ "weapon_cutpurse_nip", "weapon_gilt_maw", "utility_the_reckoning",
                                  "weapon_petal_touch", "utility_offered_nothing" }) do
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

    -- ------------------------------------------- Lust: the two the building made, and what they meet in
    --
    -- The circle's FIRE verb -- "wanting costs, whether or not you get there" -- sat in prose in
    -- models/descent.lua for as long as this stratum existed, with nothing on the ground charging a
    -- company for reaching. These are the cases that make it real rather than authored
    -- ([[prose-can-be-the-only-implementation]] is the shape, and this entry has now been caught by it
    -- twice).
    {
        name = "a Fire Elemental bills whoever damages it, in melee and from across the room alike",
        fn = function()
            local map = Fixture.new(12, 12)
            local c = Fixture.combat(map,
                { unit("character_knight", 5, 5, { isolate = "bare",
                      items = { "weapon_iron_sword" } }),
                  unit("character_mage", 5, 11, { isolate = "bare" }) },
                { unit("character_fire_elemental", 5, 6) })
            local knight, mage, wick = c.units[1], c.units[2], c.units[3]
            for _, u in ipairs(c.units) do Combat.refreshPassives(u) end

            openTurn(c, knight)
            Combat.useItem(c, knight, itemNamed(knight.char, "weapon_iron_sword"), wick.x, wick.y)
            assert(Status.has(knight, "status_burn"),
                "the hand that reached in is what catches -- that is the whole of the circle's fire verb")

            -- AND THE RANGE GATE IS THE POINT. Every retaliation in the game is a reflex with a reach
            -- on it (Antler Toss, Shield Shove, Downdraft); this is a property of the thing, so a body
            -- six tiles off that has never been near it pays the same bill. If a reach ever creeps in
            -- here the Lamp Room silently becomes a fight a bow solves for free.
            assert(not Status.has(mage, "status_burn"), "nothing has touched the mage yet")
            Combat.dealFlatDamage(c, wick, 4, { "magical" }, "a spell", mage)
            assert(Status.has(mage, "status_burn"),
                "reaching for it from six tiles is still reaching for it")
        end,
    },
    {
        -- THE ONE FREE ANSWER, AND IT IS THE ENGINE'S RULE RATHER THAN THE TRAIT'S -- which is exactly
        -- why it is pinned here. A reflex is held while a cast resolves and Combat.endAnswers skips the
        -- fallen, so a body killed by the blow that reached it answers nothing. Every word of the Lamp
        -- Room's design rests on that (commit and the room is free, chip at it and every exchange is
        -- another burn), and nothing in this file would notice if the flush ever started dispatching to
        -- corpses.
        name = "a Fire Elemental put out by the blow that reached it bills nobody",
        fn = function()
            local map = Fixture.new(10, 10)
            local c = Fixture.combat(map,
                { unit("character_knight", 5, 5, { isolate = "bare",
                      items = { "weapon_iron_sword" } }) },
                { unit("character_fire_elemental", 5, 6, { stats = { health = 1 } }) })
            local knight, wick = c.units[1], c.units[2]
            for _, u in ipairs(c.units) do Combat.refreshPassives(u) end

            openTurn(c, knight)
            Combat.useItem(c, knight, itemNamed(knight.char, "weapon_iron_sword"), wick.x, wick.y)
            assert(not wick.alive, "the fixture put it inside one swing on purpose")
            assert(not Status.has(knight, "status_burn"),
                "a candle that has gone out does not charge anybody -- commit, and a lamp room is free")
        end,
    },
    {
        name = "a Wind Elemental cannot be held, dragged or thrown by anything -- its own circle included",
        fn = function()
            local map = Fixture.new(12, 12)
            local c = Fixture.combat(map,
                { unit("character_knight", 5, 5, { isolate = "bare" }) },
                { unit("character_wind_elemental", 5, 9), unit("character_lamia", 6, 9) })
            local knight, wind = c.units[1], c.units[2]
            for _, u in ipairs(c.units) do Combat.refreshPassives(u) end

            assert(Status.has(wind, "status_unheld"),
                "it wears the stance from the opening bell, not once somebody has tried")

            local x, y = wind.x, wind.y
            Combat.knockback(c, knight, wind, 3)
            assert(wind.x == x and wind.y == y, "a shove finds no shoulder")
            Combat.pull(c, knight, wind)
            assert(wind.x == x and wind.y == y, "and a hook finds no rib")

            -- THE CIRCLE ARGUING WITH ITSELF, ASSERTED RATHER THAN ONLY WRITTEN DOWN. The whole stratum
            -- is displacement; this is the one body outside that conversation, which is what makes the
            -- Bell Loft the only stop on the floor where reaching the thing IS the fight.
            Status.apply(c, wind, "status_root")
            assert(Status.blocksForcedMove(wind), "a coil closes on it and shuts on itself")
        end,
    },
    {
        name = "a bellstroke throws three tiles where the flock's gust throws one",
        fn = function()
            local map = Fixture.new(12, 12)
            local c = Fixture.combat(map,
                -- Three tiles apart, which is the bellstroke's whole reach: at four the cast is out of
                -- range, lands nothing, and the shove is correctly gated off the hit it never made.
                { unit("character_knight", 5, 6, { isolate = "bare" }) },
                { unit("character_wind_elemental", 5, 9) })
            local knight, wind = c.units[1], c.units[2]
            for _, u in ipairs(c.units) do Combat.refreshPassives(u) end

            openTurn(c, wind)
            local y0 = knight.y
            Combat.useItem(c, wind, itemNamed(wind.char, "weapon_bellstroke"), knight.x, knight.y)
            assert(y0 - knight.y == 3, string.format(
                "the stroke takes a body out of the ROOM, not out of a rank -- moved %d, wanted 3",
                y0 - knight.y))
        end,
    },
    {
        name = "the Chimney-Draw hauls what is burning and only stumbles what is not",
        fn = function()
            local map = Fixture.new(14, 14)
            local c = Fixture.combat(map,
                { unit("character_knight", 5, 10, { isolate = "bare" }),
                  unit("character_bulwark", 3, 10, { isolate = "bare" }) },
                { unit("character_whirl_elemental", 5, 5) })
            local lit, cold, draw = c.units[1], c.units[2], c.units[3]
            for _, u in ipairs(c.units) do Combat.refreshPassives(u) end
            Status.apply(c, lit, "status_burn")

            openTurn(c, draw)
            Combat.useItem(c, draw, itemNamed(draw.char, "weapon_chimney_draw"), 5, 8)
            -- The fire is the handhold: it comes the whole way and ends against the body.
            assert(Combat.unitGap(draw, lit) == 1, string.format(
                "a burning body is hauled all the way in -- it is standing %d tiles off",
                Combat.unitGap(draw, lit)))
            -- Nothing to hold: one step, and it keeps its rank. Measured as a move of exactly one
            -- rather than as "not adjacent", so a change that quietly hauled everyone a fixed two
            -- tiles would still fail here.
            assert(cold.y == 9, string.format(
                "a cold body only stumbles one tile -- it moved to y=%d from 10", cold.y))
        end,
    },
    {
        name = "Backdraught lights the whole room, which is what arms the draw",
        fn = function()
            local map = Fixture.new(12, 12)
            local c = Fixture.combat(map,
                { unit("character_knight", 5, 5, { isolate = "bare",
                      items = { "weapon_iron_sword" } }),
                  unit("character_bulwark", 6, 6, { isolate = "bare" }) },
                { unit("character_whirl_elemental", 5, 6) })
            local knight, bystander, draw = c.units[1], c.units[2], c.units[3]
            for _, u in ipairs(c.units) do Combat.refreshPassives(u) end

            openTurn(c, knight)
            Combat.useItem(c, knight, itemNamed(knight.char, "weapon_iron_sword"), draw.x, draw.y)
            assert(Status.has(knight, "status_burn"), "the hand that reached in")
            assert(Status.has(bystander, "status_burn"),
                "...and everybody standing next to it, which is what separates the alpha's copy from "
                .. "the wick's -- see trait_backdraught's family list")
        end,
    },
    {
        name = "the Climbing Flame drags a burning foe at range and declines to in melee",
        fn = function()
            local map = Fixture.new(12, 12)
            local c = Fixture.combat(map,
                { unit("character_archer", 5, 5, { isolate = "bare", items = {
                      "weapon_iron_bow", "weapon_iron_sword", "utility_the_climbing_flame" } }) },
                { unit("character_bandit", 5, 8), unit("character_bandit", 5, 6) })
            local archer, far, near = c.units[1], c.units[2], c.units[3]
            for _, u in ipairs(c.units) do Combat.refreshPassives(u) end
            Status.apply(c, far, "status_burn")
            Status.apply(c, near, "status_burn")

            openTurn(c, archer)
            Combat.useItem(c, archer, itemNamed(archer.char, "weapon_iron_bow"), far.x, far.y)
            assert(far.y == 7, string.format(
                "a burning foe shot at range comes a tile nearer -- it is at y=%d, was 8", far.y))

            -- AND NOT IN MELEE, WHICH IS A REFUSAL RATHER THAN A CATEGORY. The step would land on the
            -- bearer's own tile, Combat.knockback would find the shift blocked and bill impact damage
            -- instead -- so an ungated version is a free damage rider on every swing wearing a control
            -- rider's name. See data/traits/trait_climbing_flame.lua.
            openTurn(c, archer)
            Combat.useItem(c, archer, itemNamed(archer.char, "weapon_iron_sword"), near.x, near.y)
            assert(near.x == 5 and near.y == 6, "an adjacent body is not dragged anywhere")
        end,
    },
    {
        name = "the elementals' finds are three shelves' worth, and every one is a rift find",
        fn = function()
            -- Named literally rather than walked out of the blueprints, because
            -- tests/item_coverage_spec reads test files as TEXT: a table-walk exercises the items and
            -- covers none of them.
            local drops = {
                utility_the_answered_wish  = "sentinel",   -- the wick's bill, on the house that collects blows
                utility_the_unheld         = "bulwark",    -- the stance, on the house that already claims it
                utility_the_climbing_flame = "bombardier", -- the combination, on the house that lays the fire
            }
            for id, shelf in pairs(drops) do
                local def = Item.defs[id]
                assert(def, id .. " does not exist")
                assert(not def.price, id .. ": a rift find carries no price")
                assert(def.unlockLevel, id .. ": every graded ware sits somewhere on the ladder")
                assert(def.class == shelf, string.format(
                    "%s shelves at %s, expected %s -- the shelf is the argument, not a spare slot",
                    id, tostring(def.class), shelf))
            end

            -- THE THREE BODIES PAY THEM, which is the half that makes the shelf entry reachable at all.
            assert(Character.defs.character_fire_elemental.drops[1] == "utility_the_answered_wish")
            assert(Character.defs.character_wind_elemental.drops[1] == "utility_the_unheld")
            assert(Character.defs.character_whirl_elemental.drops[1] == "utility_the_climbing_flame")
        end,
    },
    {
        name = "every Fire, Wind and Whirl Elemental item is natural kit and nothing else",
        fn = function()
            for _, id in ipairs({ "weapon_flame_fists", "utility_living_flame",
                                  "weapon_bellstroke", "utility_moving_air",
                                  "weapon_flashover", "weapon_chimney_draw", "utility_flue_throat" }) do
                local def = Item.defs[id]
                assert(def, id .. " does not exist")
                assert(def.noSteal and not def.price and def.class == "creature",
                    id .. ": creature kit is unpriced, unshelved and unstealable")
            end
        end,
    },
    {
        name = "the Flue is a spare on the Lust circle rather than a billing",
        fn = function()
            local lust = sinNamed("lust")
            local found = false
            for _, id in ipairs(lust.elites.spares or {}) do
                if id == "encounter_lust_the_flue" then found = true end
            end
            assert(found, "the Flue turns up at ELITE_WEIGHT on either floor, beside the Lady Chapel")
            assert(lust.elites.approach == "encounter_lust_the_drowned_stair"
                and lust.elites.seat == "encounter_lust_the_eyrie",
                "the two rungs stay billed to the circle's two original animals -- cheapest rule first")
        end,
    },
}
