-- THE CREATURE IDENTITY PASS, WRATH (2026-11-19). An audit put every body the rift fields through one test --
-- does meeting it change what you BRING, where you stand (POSITION), or who you kill first (ORDER)? -- and the
-- author approved a fix for every Wrath row that failed it. Each case below plays the fix on a bare board:
--
--   Oni Student     Horn Out at its FIRST wound (`noRestraint`, trait_the_horn), not at half
--   Orc Grunt       Shouldering: a foe that ends its turn beside it is shoved a tile back, on every board
--   Orc Veteran     Passed Scars: when it falls the nearest orc of its side takes its Proven
--   Asura Adept     left alone it GATHERS (`idleHeats` on Four Arms) where an Acolyte cools
--   Fledgling       a lone feeder: in Bloodlust it hunts the nearest BLEEDING foe (Thirst.loneFeed)
--   Goblin Brute    Pent Up is a fixed charge: Primed from the start, the same burst however it was worn down
--   the alphas      three of six moved off the pack aura: the Warchief roots, the General's Clan Stands has a
--                   reach of 2, the Hobgoblin's named Feud holds
--   targeting       one preference per family (models/wrath_targeting.lua), wired to every body it names
--
-- The slimes (the Cinder Slime and the Caldera King) are another pass's; Ember Newt and Cinder Boar were denied.
local Character = require("models.character")
local Combat = require("models.combat")
local Item = require("models.item")
local Status = require("models.status")
local Trait = require("models.trait")
local AI = require("models.ai")
local Asura = require("models.asura")
local Thirst = require("models.thirst")
local Feud = require("models.feud")
local Targeting = require("models.wrath_targeting")
local Fixture = require("tests.support.fixture")

local unit, openTurn, itemNamed, hp = Fixture.unit, Fixture.openTurn, Fixture.itemNamed, Fixture.hp

local function walker(x, y, health)
    local spawn = Fixture.walker(x, y)
    spawn.char.stats.health.max, spawn.char.stats.health.current = health or 300, health or 300
    return spawn
end

local function board(n, opts) return Fixture.new(n or 11, n or 11, opts) end

local function one(c, id)
    for _, u in ipairs(c.units) do if u.char and u.char.id == id then return u end end
end

local function field(enemies, party, map)
    local list = {}
    for _, s in ipairs(enemies) do list[#list + 1] = unit(s[1], s[2], s[3]) end
    return Fixture.combat(map or board(), party or walker(1, 1), list)
end

local function kill(c, victim, killer)
    Combat.dealFlatDamage(c, victim, 9999, { "physical" }, "test", killer, { raw = true })
end

local function aimedAt(c, plan)
    return plan and plan.tx and Combat.unitAt(c, plan.tx, plan.ty) or nil
end

return {
    -- ------------------------------------------------------------------------------ Oni Student
    {
        name = "the Oni Student goes Horn Out at its first wound, at whoever drew it; a plain Oni holds to half",
        fn = function()
            local c = field({ { "character_oni_student", 5, 5 }, { "character_oni", 8, 5 } }, walker(5, 6))
            local foe = c.units[1]
            local student, oni = one(c, "character_oni_student"), one(c, "character_oni")
            Combat.dealFlatDamage(c, student, 1, { "physical" }, "test", foe, { raw = true })
            assert(Status.has(student, "status_horn_out"), "one point of damage and the Student's horn is out")
            assert(student.hornTarget == foe, "aimed at whoever drew it")
            Combat.dealFlatDamage(c, oni, 1, { "physical" }, "test", foe, { raw = true })
            assert(not Status.has(oni, "status_horn_out"), "the same chip does nothing to a grown Oni")
            openTurn(c, student)
            local plan = AI.plan(c, student)
            assert(plan and plan.reason == "horn out", "and the Student's turn goes to the body that chipped it")
        end,
    },
    -- ------------------------------------------------------------------------------ Orc Grunt
    {
        name = "the Orc Grunt shoulders a foe that ends its turn beside it one tile back, and leaves a far one be",
        fn = function()
            local c = field({ { "character_orc_grunt", 5, 5 } }, { walker(5, 6), walker(9, 9) })
            local near, far = c.units[1], c.units[2]
            local grunt = one(c, "character_orc_grunt")
            assert(itemNamed(grunt.char, "utility_shouldering"), "the Grunt carries Shouldering")
            assert(Item.defs["utility_shouldering"].bound and Item.defs["utility_shouldering"].noSteal,
                "an organ, never kit")
            Trait.onAnyTurnEnd(c, near)
            assert(near.x == 5 and near.y == 7, "shoved one tile straight back; got " .. near.x .. "," .. near.y)
            Trait.onAnyTurnEnd(c, far)
            assert(far.x == 9 and far.y == 9, "a foe that is not beside it is not moved")
            Status.apply(c, grunt, "status_spectating")
            near.x, near.y = 5, 6
            Trait.onAnyTurnEnd(c, near)
            assert(near.y == 6, "a Grunt in the Blood Ring's crowd leaves the shove to the Ring")
        end,
    },
    -- ------------------------------------------------------------------------------ Orc Veteran
    {
        name = "the Orc Veteran's scars pass to the nearest orc of its side when it falls",
        fn = function()
            local c = field({ { "character_orc_veteran", 5, 5 }, { "character_orc_grunt", 5, 4 },
                { "character_orc_grunt", 1, 11 } }, walker(9, 9))
            local foe = c.units[1]
            local vet = one(c, "character_orc_veteran")
            local near, far = c.units[3], c.units[4]
            -- The battle opens a body in its gear's boons (states/battle.lua); applied here the same way.
            for _, item in ipairs(Character.eachItem(vet.char)) do
                for _, b in ipairs(require("models.curse").openingBoons(item)) do Status.apply(c, vet, b.id, b.opts) end
            end
            assert(Status.stacksOf(vet, "status_proven") == 2, "the Veteran opens Proven twice over")
            assert(Status.stacksOf(near, "status_proven") == 0, "the Grunt opens fresh")
            kill(c, vet, foe)
            assert(not vet.alive, "the Veteran falls")
            assert(Status.stacksOf(near, "status_proven") == 2,
                "the Grunt beside it takes both scars; got " .. Status.stacksOf(near, "status_proven"))
            assert(Status.stacksOf(far, "status_proven") == 0, "the far one takes nothing")
        end,
    },
    -- ------------------------------------------------------------------------------ Asura Adept
    {
        name = "left alone, an Asura Adept gathers 2 chi where an Acolyte cools by 1",
        fn = function()
            local c = field({ { "character_asura_acolyte", 6, 6 }, { "character_asura_adept", 9, 9 } })
            local aco, adept = one(c, "character_asura_acolyte"), one(c, "character_asura_adept")
            Asura.grant(c, aco, 3)
            Asura.grant(c, adept, 3)
            Trait.onAnyTurnEnd(c, aco) -- the first turn end only sets the baseline
            Trait.onAnyTurnEnd(c, aco)
            Trait.onAnyTurnEnd(c, adept)
            Trait.onAnyTurnEnd(c, adept)
            assert(Asura.chi(aco) == 2, "the Acolyte cools; got " .. Asura.chi(aco))
            assert(Asura.chi(adept) == 5, "the Adept heats; got " .. Asura.chi(adept))
            for _ = 1, 3 do Trait.onAnyTurnEnd(c, adept) end
            assert(Status.has(adept, Asura.BURSTING), "ignored long enough, it bursts")
        end,
    },
    -- ------------------------------------------------------------------------------ Fledgling
    {
        name = "a Fledgling in Bloodlust hunts the nearest BLEEDING foe past the thrall beside it",
        fn = function()
            local c = field({ { "character_fledgling", 5, 5 }, { "character_blood_ghoul", 5, 6 } },
                { walker(8, 5), walker(1, 11) })
            local far = c.units[1]
            local f = one(c, "character_fledgling")
            local ghoul = one(c, "character_blood_ghoul")
            Thirst.enterBloodlust(c, f)
            openTurn(c, f)
            local plan = AI.plan(c, f)
            assert(plan and plan.reason == "bloodlust", "with nobody bleeding it bites as any vampire does")
            assert(aimedAt(c, plan) == ghoul, "the nearest body: its own thrall")
            Status.apply(c, far, "status_bleed", { applier = ghoul })
            openTurn(c, f)
            plan = AI.plan(c, f)
            assert(plan and plan.reason == "the open wound", "a foe bleeds: it goes for the wound")
            assert(aimedAt(c, plan) == far or (plan.move and not plan.tx),
                "at the bleeding foe, not the thrall beside it")
        end,
    },
    {
        name = "the Goblin Fledgling is no lone feeder: it still bites the goblin beside it, or Bad Blood never fires",
        fn = function()
            assert(Character.defs["character_fledgling"].loneFeeder, "the human Fledgling is")
            assert(not Character.defs["character_goblin_fledgling"].loneFeeder, "the goblin one is not")
            local c = field({ { "character_goblin_fledgling", 5, 5 }, { "character_goblin_cutter", 5, 6 } },
                { walker(8, 5), walker(1, 11) })
            local far = c.units[1]
            local f = one(c, "character_goblin_fledgling")
            Status.apply(c, far, "status_bleed", { applier = f })
            Thirst.enterBloodlust(c, f)
            openTurn(c, f)
            local plan = AI.plan(c, f)
            assert(plan and plan.reason == "bloodlust", "it bites the nearest body")
            assert(aimedAt(c, plan) == one(c, "character_goblin_cutter"), "the goblin beside it")
        end,
    },
    -- ------------------------------------------------------------------------------ Goblin Brute
    {
        name = "the Goblin Brute opens Primed and bursts for the same however often it was struck",
        fn = function()
            local function burst(blows)
                local c = field({ { "character_goblin_brute", 5, 5 } }, walker(5, 6))
                local foe, brute = c.units[1], one(c, "character_goblin_brute")
                assert(Status.has(brute, "status_primed"), "Primed before anybody touches it")
                for _ = 1, blows do Combat.dealFlatDamage(c, brute, 1, { "physical" }, "test", foe, { raw = true }) end
                assert(not Status.has(brute, "status_seething"), "the blows bank nothing")
                foe.char.stats.health.current = 300
                kill(c, brute, foe)
                assert(not brute.alive, "the Brute falls")
                return 300 - hp(foe)
            end
            local fresh, worn = burst(0), burst(5)
            assert(fresh > 0, "killed in one blow, it still bursts on whoever stands beside it")
            assert(fresh == worn, "and five blows first make it no bigger; got " .. fresh .. " and " .. worn)
        end,
    },
    -- ------------------------------------------------------------------------------ the alphas
    {
        name = "the Orc Warchief roots a foe that ends its turn beside him, and lends his warband no damage",
        fn = function()
            local c = field({ { "character_orc_warchief", 5, 5 }, { "character_orc_grunt", 2, 2 } },
                { walker(5, 6), walker(9, 9) })
            local near, far = c.units[1], c.units[2]
            local grunt = one(c, "character_orc_grunt")
            Trait.onAnyTurnEnd(c, near)
            assert(Status.has(near, "status_root"), "the foe beside him is held")
            assert(Status.defs["status_root"].debuff, "and a Cure frees it")
            Trait.onAnyTurnEnd(c, far)
            assert(not Status.has(far, "status_root"), "the far one is not")
            local alone = Combat.flatStat(grunt, "damage")
            grunt.x, grunt.y = 4, 5
            assert(Combat.flatStat(grunt, "damage") == alone, "the old +2 aura is gone")
        end,
    },
    {
        name = "the Oni General's Clan Stands holds up an oni within 2 of it and lets a far one fall",
        fn = function()
            local c = field({ { "character_oni_general", 5, 3 }, { "character_oni", 5, 5 }, { "character_oni", 5, 10 } },
                walker(1, 1))
            local foe = c.units[1]
            local near, far = c.units[3], c.units[4]
            kill(c, near, foe)
            assert(near.alive and hp(near) == 1, "the oni two tiles from the General stays up")
            kill(c, far, foe)
            assert(not far.alive, "the oni seven tiles off falls")
        end,
    },
    {
        name = "the Hobgoblin's named Feud is not moved by a blow on a goblin, and outlives the Hobgoblin",
        fn = function()
            local c = field({ { "character_hobgoblin", 5, 5 }, { "character_goblin_cutter", 2, 2 } },
                { walker(5, 7), walker(2, 4) })
            local named, other = c.units[1], c.units[2]
            local hob, cutter = one(c, "character_hobgoblin"), one(c, "character_goblin_cutter")
            openTurn(c, hob)
            assert(Combat.useItem(c, hob, itemNamed(hob.char, "ability_name_the_enemy"), named.x, named.y),
                "it names the enemy")
            assert(Feud.of(c, hob.side) == named and Feud.named(c, hob.side), "the Feud is named")
            Combat.dealFlatDamage(c, cutter, 1, { "physical" }, "test", other)
            assert(Feud.of(c, hob.side) == named, "a blow on another goblin does not move it")
            kill(c, hob, other)
            assert(Feud.of(c, hob.side) == named, "and it holds after the Hobgoblin falls")
            assert(Status.defs["status_blood_feud"].debuff, "a Cure is what lifts it")
            Status.remove(c, named, "status_blood_feud")
            Combat.dealFlatDamage(c, cutter, 1, { "physical" }, "test", other)
            assert(Feud.of(c, hob.side) == other, "lifted, the warband goes back to chasing whoever hurts it")
        end,
    },
    -- ------------------------------------------------------------------------------ targeting
    {
        name = "every Wrath family carries its one preference, from the planner's own vocabulary",
        fn = function()
            local known = {}
            for _, p in ipairs(AI.TARGET_PREF_ORDER) do known[p] = true end
            for family, ids in pairs(Targeting.FAMILIES) do
                local rules = Targeting[family]
                assert(rules and #rules > 0, family .. " has rules")
                for _, r in ipairs(rules) do
                    assert(known[r.targetPref], family .. " asks for a preference the planner knows: " .. tostring(r.targetPref))
                end
                for _, id in ipairs(ids) do
                    local def = Character.defs[id]
                    assert(def, id .. " exists")
                    assert(def.ai == rules, id .. " carries the " .. family .. " rules")
                    local seen = false
                    local c = field({ { id, 5, 5 } })
                    for _, e in ipairs(AI.rulesFor(one(c, id))) do
                        if e.rule == rules[#rules] then seen = true end
                    end
                    assert(seen, id .. "'s planner reads the family rule")
                end
            end
        end,
    },
    {
        name = "a goblin piles onto the cornered foe: of two beside it, the one walled in",
        fn = function()
            local walls = {}
            for _, p in ipairs({ { 7, 4 }, { 7, 5 }, { 7, 6 }, { 6, 4 }, { 6, 6 } }) do
                walls[#walls + 1] = { x = p[1], y = p[2], walkable = false, type = "wall" }
            end
            local function pick(withRule)
                local c = field({ { "character_goblin_cutter", 5, 5 } }, { walker(4, 5), walker(6, 5) },
                    board(11, { tiles = walls }))
                local g = one(c, "character_goblin_cutter")
                if not withRule then g.char.ai = nil end
                openTurn(c, g)
                local plan = AI.plan(c, g)
                return aimedAt(c, plan), c.units[1], c.units[2], plan
            end
            local got, open, cornered, plan = pick(true)
            assert(got == cornered, "the walled-in foe; got " .. tostring(plan and plan.reason))
            local control, open2 = pick(false)
            assert(control == open2, "and it is the rule that chose it: without one, the open foe first on the board")
            assert(open.alive, "the open one is spared the blow")
        end,
    },
    {
        name = "an oni goes for the foe its clan marked",
        fn = function()
            local c = field({ { "character_oni", 5, 5 } }, { walker(4, 5), walker(6, 5) })
            local plain, marked = c.units[1], c.units[2]
            Status.apply(c, marked, "status_mark")
            local oni = one(c, "character_oni")
            openTurn(c, oni)
            local plan = AI.plan(c, oni)
            assert(aimedAt(c, plan) == marked, "the marked foe; got " .. tostring(plan and plan.reason))
            assert(plain.alive, "not the plain one")
            -- ...and the unmarked case, so the pick above is the mark and not the board: with nothing marked the
            -- oni takes the first of two equal foes, which is the plain one.
            local c2 = field({ { "character_oni", 5, 5 } }, { walker(4, 5), walker(6, 5) })
            local oni2 = one(c2, "character_oni")
            openTurn(c2, oni2)
            assert(aimedAt(c2, AI.plan(c2, oni2)) == c2.units[1], "unmarked, the first foe on the board")
        end,
    },
}
