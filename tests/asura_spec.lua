-- THE ASURA OF WRATH (reviewed over two rounds, 2026-09-27/28): monks who turned their discipline to war, and
-- Furor, the Thousand-Armed, who replaced Ira on Wrath's stair. What this file holds the build to is the
-- settled design (models/asura.lua's header states it in full):
--
--   * the monk's own chi, with the vow broken: it fills when struck, drains on an idle turn, and a full pool is
--     thrown at the NEAREST FOE whether the body would or not -- on a company body the game takes the turn;
--   * Tapas: a Gather banks 2 chi and is not an idle turn; a shrine keeps the heat;
--   * arms are hits (the field Swift Fist raises), fixed by rank and never lost -- Furor's grow at 4 and 8 chi;
--   * a Burst heats every asura within 2; the Nio inherit each other's chi;
--   * the drops (the Broken Vow, Thousand Hands, Severing Blow, the Asura's Arm, Tapas Beads) and the wiring
--     (Descent's escort, elites and drop list).
local Character = require("models.character")
local Combat = require("models.combat")
local Item = require("models.item")
local Status = require("models.status")
local Trait = require("models.trait")
local Hazard = require("models.hazard")
local Asura = require("models.asura")
local Descent = require("models.descent")
local Encounter = require("models.encounter")

local function arena(cols, rows)
    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do tiles[y][x] = { type = "ground", moveCost = 1, walkable = true, sightCost = 0 } end
    end
    return { cols = cols, rows = rows, tiles = tiles, objective = { type = "killAll" } }
end

local function unit(id, x, y) return { char = Character.instantiate(id), x = x, y = y } end

local function itemOn(u, id)
    for _, it in ipairs(Character.eachItem(u.char)) do
        if it.id == id then return it end
    end
end

-- A party body at (1,1) and whatever enemies are asked for.
local function board(enemies, party)
    local c = Combat.new(arena(10, 10), party or { unit("character_rowan", 1, 1) }, enemies)
    return c
end

local function hit(c, target, attacker, n)
    Combat.dealFlatDamage(c, target, n or 1, { "impact" }, "a test blow", attacker)
end

return {
    {
        name = "every asura carries its blood, and its blood carries the broken vow",
        fn = function()
            for _, id in ipairs({ "character_asura_acolyte", "character_asura_adept", "character_asura_three_faced",
                                  "character_asura_agyo", "character_asura_ungyo", "character_general_wrath" }) do
                local c = board({ unit(id, 5, 5) })
                local a = c.units[2]
                assert(itemOn(a, "utility_asura_blood"), id .. " carries Asura Blood (the race grant)")
                assert(Asura.hasVow(a), id .. " lives under the broken vow")
                assert(Asura.isAsura(a), id .. " is an asura by race")
            end
            assert(Character.defs.character_general_wrath.name == "Furor, the Thousand-Armed",
                "Furor stands on Wrath's stair, on Ira's old id")
        end,
    },
    {
        name = "a blow taken fills an asura's chi, as a blow landed fills a monk's",
        fn = function()
            local c = board({ unit("character_asura_acolyte", 2, 1) })
            local rowan, a = c.units[1], c.units[2]
            assert(Asura.chi(a) == 0, "it opens cold")
            hit(c, a, rowan)
            hit(c, a, rowan)
            assert(Asura.chi(a) == 2, "two blows taken, two chi; got " .. Asura.chi(a))
        end,
    },
    {
        name = "an idle turn drains a point of chi, and a turn with a blow in it does not",
        fn = function()
            local c = board({ unit("character_asura_acolyte", 6, 6) })
            local rowan, a = c.units[1], c.units[2]
            Asura.grant(c, a, 3)
            Trait.onAnyTurnEnd(c, a) -- the first turn end only sets the baseline
            Trait.onAnyTurnEnd(c, a)
            assert(Asura.chi(a) == 2, "left alone, it cools by one; got " .. Asura.chi(a))
            hit(c, a, rowan)
            Trait.onAnyTurnEnd(c, a)
            assert(Asura.chi(a) == 3, "struck this turn: it filled and did not cool; got " .. Asura.chi(a))
        end,
    },
    {
        name = "a shrine keeps the heat: an asura standing on one does not cool",
        fn = function()
            local c = board({ unit("character_asura_acolyte", 6, 6) })
            local a = c.units[2]
            Hazard.place(c, a.x, a.y, "hazard_shrine", {})
            assert(Asura.onShrine(c, a), "the shrine is underfoot")
            Asura.grant(c, a, 3)
            Trait.onAnyTurnEnd(c, a)
            Trait.onAnyTurnEnd(c, a)
            assert(Asura.chi(a) == 3, "on a shrine the idle turn drains nothing; got " .. Asura.chi(a))
        end,
    },
    {
        name = "Tapas: a Gather banks 2 chi, and a coiled turn is not an idle one",
        fn = function()
            local c = board({ unit("character_asura_three_faced", 6, 6) })
            local a = c.units[2]
            Trait.onAnyTurnEnd(c, a) -- baseline
            assert(Combat.gather(c, a), "the Centering Charm's coil")
            assert(Asura.chi(a) == 2, "the coil heats it by 2; got " .. Asura.chi(a))
            assert(Status.has(a, "status_empowered"), "and it still coils the next blow")
        end,
    },
    {
        name = "a full pool lays Bursting, and the planner throws the Burst at the nearest FOE, not the nearest body",
        fn = function()
            local c = board({ unit("character_asura_acolyte", 5, 5), unit("character_asura_acolyte", 5, 6) },
                { unit("character_rowan", 5, 3), unit("character_bandit", 9, 9) })
            local a = c.units[3]
            Asura.grant(c, a, 10)
            assert(Status.has(a, Asura.BURSTING), "full: Bursting")
            local plan = Asura.plan(c, a)
            assert(plan and plan.item and plan.item.id == "utility_asura_blood", "it throws the Burst on its blood")
            assert(plan.tx == 5 and plan.ty == 3,
                "at the nearest foe (Rowan), not its own kin beside it; got " .. tostring(plan.tx) .. "," .. tostring(plan.ty))
            assert(plan.move, "closing on it first")
        end,
    },
    {
        name = "the Burst spends the pool, lifts Bursting, and heats every asura within 2 (Wrath spreads)",
        fn = function()
            local c = board({ unit("character_asura_acolyte", 2, 1), unit("character_asura_acolyte", 3, 1),
                              unit("character_asura_acolyte", 9, 9) })
            local rowan, a, near, far = c.units[1], c.units[2], c.units[3], c.units[4]
            Asura.grant(c, a, 10)
            local before = rowan.char.stats.health.current
            local ok = Combat.useItem(c, a, itemOn(a, "utility_asura_blood"), rowan.x, rowan.y)
            assert(ok, "the Burst is thrown")
            assert(rowan.char.stats.health.current < before, "and it lands")
            assert(Asura.chi(a) == 0, "the whole pool is spent")
            assert(not Status.has(a, Asura.BURSTING), "so Bursting lifts")
            assert(Asura.chi(near) == 2, "the kin beside it takes the heat; got " .. Asura.chi(near))
            assert(Asura.chi(far) == 0, "the kin across the board does not")
        end,
    },
    {
        name = "arms are hits: fixed by rank, stacking with Swift Fist, and Furor's grow at 4 and 8 chi",
        fn = function()
            local c = board({ unit("character_asura_acolyte", 5, 5), unit("character_asura_adept", 6, 5),
                              unit("character_asura_three_faced", 7, 5), unit("character_general_wrath", 8, 8) })
            local acolyte, adept, three, furor = c.units[2], c.units[3], c.units[4], c.units[5]
            assert(itemOn(adept, "utility_four_arms") and itemOn(three, "utility_six_arms")
                and itemOn(furor, "utility_thousand_arms"), "arms are organs, one per rank")
            assert(Item.defs.utility_four_arms.bound and Item.defs.utility_six_arms.bound, "and bound: never lost")
            assert(Asura.arms(acolyte) == 2 and acolyte.unarmedBonus.hits == 0, "the Acolyte: two arms, one landing")
            assert(Asura.arms(adept) == 4, "the Adept shows four arms")
            assert(adept.unarmedBonus.hits == 2, "four arms (+1) and Swift Fist (+1) stack; got " .. adept.unarmedBonus.hits)
            assert(Asura.arms(three) == 6 and three.unarmedBonus.hits == 2, "the Three-Faced: six arms, three landings")
            assert(Asura.arms(furor) == 4 and Asura.grownHits(furor) == 0, "Furor opens with four")
            Asura.grant(c, furor, 4)
            assert(Asura.arms(furor) == 6 and Asura.grownHits(furor) == 1, "a pair grows at 4 chi")
            Asura.grant(c, furor, 4)
            assert(Asura.arms(furor) == 8 and Asura.grownHits(furor) == 2, "and another at 8")
        end,
    },
    {
        name = "Furor bursts with Every Arm, a wind-up, one blow per pair of arms",
        fn = function()
            local c = board({ unit("character_general_wrath", 2, 1) })
            local furor = c.units[2]
            local item = Asura.burstItem(furor)
            assert(item and item.id == "ability_every_arm", "his signature, not the plain Burst")
            assert((item.activeAbility.windup or 0) > 0, "and it winds up: a shove breaks it")
            assert(itemOn(furor, "utility_burning_halo"), "he wears the Burning Halo")
            assert((furor.resist.fire or 0) >= 5, "and his fire +5 rides his arms")
            assert(itemOn(furor, "ability_keen_senses"), "and answers first")
        end,
    },
    {
        name = "the Nio take each other's chi, and the one that fills bursts",
        fn = function()
            local c = board({ unit("character_asura_agyo", 5, 5), unit("character_asura_ungyo", 6, 5) })
            local rowan, agyo, ungyo = c.units[1], c.units[2], c.units[3]
            assert(itemOn(agyo, "utility_nio") and itemOn(ungyo, "utility_nio"), "both carry the Gate Pair")
            Asura.grant(c, agyo, 5)
            Asura.grant(c, ungyo, 6)
            hit(c, agyo, rowan, 9999)
            assert(not agyo.alive, "the Open Mouth falls")
            assert(Asura.chi(ungyo) == 10, "the Closed Mouth takes its heat, to the cap; got " .. Asura.chi(ungyo))
            assert(Status.has(ungyo, Asura.BURSTING), "and bursts")
        end,
    },
    {
        name = "the Broken Vow takes a company monk's turn at a full pool, and hands it back after the Burst",
        fn = function()
            local monk = Character.instantiate("character_bandit")
            Character.addItem(monk, Item.instantiate("utility_the_broken_vow"))
            local c = Combat.new(arena(10, 10), { { char = monk, x = 1, y = 1 } },
                { unit("character_bandit", 2, 1) })
            local m, foe = c.units[1], c.units[2]
            assert(Asura.hasVow(m), "the vow's rule reaches its wearer")
            hit(c, m, foe)
            assert(Asura.chi(m) == 1, "struck, the monk fills")
            Asura.grant(c, m, 9)
            assert(Status.has(m, Asura.BURSTING) and m.control == "ai", "full: the game takes the turn")
            local plan = Asura.plan(c, m)
            assert(plan and plan.item and plan.item.id == "utility_the_broken_vow", "and throws the vow's Burst")
            assert(Combat.useItem(c, m, plan.item, plan.tx, plan.ty), "at the foe")
            assert(not Status.has(m, Asura.BURSTING) and m.control ~= "ai", "then the turn is the player's again")
        end,
    },
    {
        name = "Thousand Hands spends the pool as bare-handed blows spread across every foe in reach",
        fn = function()
            local monk = Character.instantiate("character_bandit")
            Character.addItem(monk, Item.instantiate("ability_thousand_hands"))
            local c = Combat.new(arena(10, 10), { { char = monk, x = 5, y = 5 } },
                { unit("character_bandit", 5, 4), unit("character_bandit", 6, 5) })
            local m, a, b = c.units[1], c.units[2], c.units[3]
            m.chargeSpent = { chi = -4 } -- four chi banked
            assert(Combat.chi(m) == 4, "four chi to spend")
            local ha, hb = a.char.stats.health.current, b.char.stats.health.current
            assert(Combat.useItem(c, m, itemOn(m, "ability_thousand_hands"), a.x, a.y), "the spray is thrown")
            assert(a.char.stats.health.current < ha, "the aimed foe is struck")
            assert(b.char.stats.health.current < hb, "and so is the other foe in reach")
            -- The pool is spent whole, and then each bare-handed landing banks one back -- chi is built by
            -- punching (Combat.CHARGE_DEFS), exactly as Flurry's own blows refill it. 4 chi: 2 blows, 2 back.
            assert(Combat.chi(m) == 2, "spent whole, and the two landings bank two back; got " .. Combat.chi(m))
        end,
    },
    {
        name = "Severing Blow disarms only on a blow worth a fifth of the target's max health",
        fn = function()
            local fighter = Character.instantiate("character_bandit")
            Character.addItem(fighter, Item.instantiate("ability_severing_blow"))
            local c = Combat.new(arena(10, 10), { { char = fighter, x = 5, y = 5 } },
                { unit("character_general_wrath", 5, 4) })
            local f, big = c.units[1], c.units[2]
            assert(Combat.useItem(c, f, itemOn(f, "ability_severing_blow"), big.x, big.y), "the blow lands")
            assert(not Status.has(big, "status_disarmed"), "a scratch on 220 health disarms nothing")

            local c2 = Combat.new(arena(10, 10), { { char = Character.instantiate("character_bandit"), x = 5, y = 5 } },
                { unit("character_asura_acolyte", 5, 4) })
            local f2, small = c2.units[1], c2.units[2]
            Character.addItem(f2.char, Item.instantiate("ability_severing_blow"))
            small.char.stats.health.max = 200
            small.char.stats.health.current = 200
            local sb = itemOn(f2, "ability_severing_blow")
            sb.activeAbility.damage = 80 -- a blow of 40% on the 200 we just set
            assert(Combat.useItem(c2, f2, sb, small.x, small.y), "the heavy blow lands")
            assert(Status.has(small, "status_disarmed"), "a fifth of its health: Disarmed")
        end,
    },
    {
        name = "the drops: the Broken Vow heads Furor's list (a relic), and the rest are monk and fighter trophies",
        fn = function()
            local list = Descent.DROPS.wrath.general
            assert(list[1] == "utility_the_broken_vow", "the relic first; got " .. tostring(list[1]))
            local want = { ability_thousand_hands = "monk", utility_burning_halo = "crusader",
                           ability_severing_blow = "fighter", utility_the_asuras_arm = "monk",
                           utility_tapas_beads = "monk", utility_the_broken_vow = "creature" }
            for id, class in pairs(want) do
                local found = false
                for _, d in ipairs(list) do if d == id then found = true end end
                assert(found, id .. " is on Furor's list")
                assert(Item.defs[id].class == class, id .. " sits on the " .. class .. " shelf")
            end
            for _, id in ipairs(list) do
                assert(id ~= "armor_mail_of_the_unappeased", "Ira's mail left the list with her")
            end
            assert(Item.defs["utility_tapas_beads"].gatherCharge == 2, "Tapas Beads bank 2 on a Gather")
            assert(Item.defs["utility_the_asuras_arm"].unarmedBonus.hits == 1, "the Asura's Arm lands once more")
        end,
    },
    {
        name = "the wiring: Adepts escort Furor, the Nio and the Meditation Hall stand on Wrath, and Ira is gone",
        fn = function()
            local wrath
            for _, s in ipairs(Descent.SINS) do if s.id == "wrath" then wrath = s end end
            assert(wrath.guardian.lead == "character_general_wrath", "Furor leads on the old id")
            assert(wrath.guardian.filler == "character_asura_adept", "Adepts are his escort")
            local spares = {}
            for _, id in ipairs(wrath.elites.spares) do spares[id] = true end
            assert(spares.encounter_wrath_the_nio and spares.encounter_wrath_the_meditation_hall,
                "both asura elites are billed to Wrath")
            local nio, hall = Encounter.get("encounter_wrath_the_nio"), Encounter.get("encounter_wrath_the_meditation_hall")
            assert(nio.kind == "elite" and nio.rung == 1, "the Nio on the approach")
            assert(hall.kind == "elite" and hall.rung == 2, "the Hall on the seat")
            assert(hall.scatter and hall.scatter[1].id == "hazard_shrine", "and it lays shrines")
            for id, rung in pairs({ encounter_wrath_the_vigil = 1, encounter_wrath_the_sparring_ground = 1,
                                    encounter_wrath_the_inner_hall = 2, encounter_wrath_the_three_faces = 2 }) do
                local e = Encounter.get(id)
                assert(e and e.kind == "combat" and e.rung == rung, id .. " is an ordinary fight on rung " .. rung)
            end
            for _, gone in ipairs({ "character_general_wrath_demon" }) do
                assert(Character.defs[gone] == nil, gone .. " is retired")
            end
            for _, gone in ipairs({ "utility_unappeased_heart", "utility_unbound_heart", "ability_the_only_hour",
                                    "ability_run_you_down" }) do
                assert(Item.defs[gone] == nil, gone .. " is retired")
            end
            assert(Character.defs.character_asura_acolyte.race == "asura", "the line is its own race, not oni")
        end,
    },
}
