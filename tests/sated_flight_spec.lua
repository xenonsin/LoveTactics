-- Tests for THE SATED AND THE FLIGHT (Gluttony, reviewed over two rounds on 2026-09-23): the Sated's meals,
-- the wood's hawk and the Glove's hawk split apart, the Griffin, their fights, their drops, and the engine
-- seams they needed --
--   * `statBonusScales` (a status table read per stack) and Status.spendStacks / fx.spendStacks
--   * `damageTakenScale` (On the Wing), applied last in Combat.mitigatedDamage
--   * Combat.chargeInto's `lane` / `trample` options (Settle heaves a four-tile body)
--   * Status.belled (Hawk Bells) and Combat.applyHeal's `passesHeals` hand-off (Sated)
--   * an instance-level `unmovable` rider read by Status.blocksForcedMove (Second Helping)
-- Each case pins a rule a review line approved, on a bare board.

local Character = require("models.character")
local Combat = require("models.combat")
local Descent = require("models.descent")
local Encounter = require("models.encounter")
local Item = require("models.item")
local Status = require("models.status")
local Trait = require("models.trait")
local Fixture = require("tests.support.fixture")

local unit, openTurn, itemNamed, hp = Fixture.unit, Fixture.openTurn, Fixture.itemNamed, Fixture.hp

local KIT = { "weapon_glutted_bulk", "utility_distended_hide", "ability_retch", "ability_settle",
              "weapon_raking_talons", "weapon_beak_and_claw", "utility_griffin_wings",
              "utility_griffin_temper" }
local DROPS = {
    character_the_sated = { "ability_bile_sac", "utility_bottomless_gut", "armor_distended_girth",
                            "ability_second_helping", "utility_sated_charm" },
    character_hawk = { "utility_hawk_bells" },
    character_griffin = { "utility_gorgers_beak", "utility_tithe_feather" },
}

local function board(n) return Fixture.new(n or 9, n or 9) end

-- A company body sturdy enough to take what a case throws at it.
local function walker(x, y, health)
    local spawn = Fixture.walker(x, y)
    spawn.char.stats.health.max, spawn.char.stats.health.current = health or 300, health or 300
    return spawn
end

local function meals(u) return Status.stacksOf(u, "status_full") end
local function stat(u, name) return Combat.flatStat(u, name) end

local function kill(c, u, by) Combat.dealFlatDamage(c, u, 9999, { "physical" }, "test", by) end

return {
    -- ------------------------------------------------------------------------------ the content
    {
        name = "the kit is creature stock, and every drop is a person's unstocked trophy, shallow to deep",
        fn = function()
            for _, id in ipairs(KIT) do
                local def = Item.defs[id]
                assert(def, "kit item exists: " .. id)
                assert(def.class == "creature" and def.noSteal, id .. " is unstealable creature kit")
                assert(def.price == nil and def.unlockLevel == nil, id .. " carries no price and no rung")
            end
            for bodyId, list in pairs(DROPS) do
                local body = Character.defs[bodyId]
                assert(body, "body exists: " .. bodyId)
                local depth = -1
                for i, id in ipairs(list) do
                    local def = Item.defs[id]
                    assert(def and def.class ~= "creature", "drop is a person's item: " .. id)
                    assert(def.unstocked and def.price == nil, id .. " is seen on the rack and never sold")
                    assert(def.unlockLevel >= depth, id .. " sits no shallower than the drop above it")
                    depth = def.unlockLevel
                    assert(body.drops[i] == id, bodyId .. " drop " .. i .. " is " .. id)
                end
            end
        end,
    },
    {
        name = "the Glove's hawk is split from the wood's: the glove fields its own, and it keeps the old Talons",
        fn = function()
            local glove = Character.defs.character_falconers_hawk
            assert(glove and glove.startingItems[1] == "weapon_talons", "the glove's hawk is untouched")
            assert(not glove.drops, "and drops nothing: it is a summon")
            local wild = Character.defs.character_hawk
            assert(wild.startingItems[1] == "weapon_raking_talons", "the wood's hawk rakes and mantles")
            local c = Combat.new(board(), { walker(2, 2) }, { walker(8, 8) })
            local bearer = c.units[1]
            Fixture.give(bearer.char, "utility_falconers_glove")
            local ctx = { unit = bearer, combat = c, openTileNear = function(x, y) return Combat.openTileNear(c, x, y) end,
                summon = function(id, x, y, o) return require("models.summon").spawn(c, bearer, id, x, y, o) end,
                applyStatus = function(t, id) return Status.apply(c, t, id) end, log = function() end }
            Trait.defs.trait_falconers_hawk.onCombatStart(ctx)
            assert(bearer.hawkCompanion and bearer.hawkCompanion.char.id == "character_falconers_hawk",
                "the glove summons the falconer's hawk, not the wood's")
        end,
    },
    {
        name = "the Eyrie is a pair of griffins on the approach, and a Cast of Hawks is ordinary traffic there",
        fn = function()
            local eyrie, cast = Encounter.get("encounter_the_eyrie"), Encounter.get("encounter_a_cast_of_hawks")
            assert(eyrie.kind == "elite" and eyrie.rung == 1, "the Eyrie is an elite on rung 1")
            assert(cast.kind == "combat" and cast.rung == 1, "a Cast of Hawks is homed on rung 1")
            for _, enc in ipairs({ eyrie, cast }) do
                assert(enc.condition({ biome = "forest" }) and not enc.condition({ biome = "castle" }),
                    "locked to the wood")
            end
            for seed = 1, 30 do
                local ctx = { depth = 1, rung = 1, biome = "forest", seed = seed }
                local pair = eyrie.composition(ctx)
                assert(pair[1] == "character_griffin" and pair[2] == "character_griffin", "a mated pair")
                local hawks = cast.composition(ctx)
                assert(#hawks >= 3 and #hawks <= 5, "three to five hawks (" .. #hawks .. ")")
            end
            local listed = false
            for _, sin in ipairs(Descent.SINS) do
                for _, id in ipairs((sin.elites and sin.elites.spares) or {}) do
                    if id == "encounter_the_eyrie" then listed = true end
                end
            end
            assert(listed, "the Eyrie is billed as one of Gluttony's spares")
        end,
    },

    -- ------------------------------------------------------------------------------ the Sated
    {
        name = "the Sated opens holding three meals, and each meal spent makes it lighter, quicker and softer",
        fn = function()
            local c = Combat.new(board(), { walker(1, 1) }, { unit("character_the_sated", 5, 5) })
            local sated = c.units[2]
            assert(meals(sated) == 3, "three meals at the bell, got " .. meals(sated))
            assert(stat(sated, "damage") == 18 and stat(sated, "defense") == 13, "full: 18 damage, 13 defense")
            assert(stat(sated, "movement") == 1 and stat(sated, "speed") == 2, "full: move 1, speed 2")
            assert(Status.spendStacks(c, sated, "status_full", 1), "a meal can be spent")
            assert(stat(sated, "damage") == 15 and stat(sated, "defense") == 10 and stat(sated, "movement") == 2,
                "two meals: 15 / 10 / move 2")
            assert(Status.spendStacks(c, sated, "status_full", 2) and not Status.has(sated, "status_full"),
                "the last meal takes the badge with it")
            assert(stat(sated, "damage") == 9 and stat(sated, "movement") == 4, "empty: 9 damage, move 4")
            assert(not Status.spendStacks(c, sated, "status_full", 1), "an empty belly spends nothing")
        end,
    },
    {
        name = "a critical knocks a meal loose, and an ordinary blow does not",
        fn = function()
            local c = Combat.new(board(), { walker(4, 5) }, { unit("character_the_sated", 5, 5) })
            local foe, sated = c.units[1], c.units[2]
            Trait.onDamaged(c, sated, { amount = 4, attacker = foe, tags = { "physical" } })
            assert(meals(sated) == 3, "a plain blow leaves the meals where they are")
            Trait.onDamaged(c, sated, { amount = 12, attacker = foe, critical = true, tags = { "physical" } })
            assert(meals(sated) == 2, "a critical knocks one loose, got " .. meals(sated))
            -- Stunned, it still loses it: the meal is not an answer it throws.
            Status.apply(c, sated, "status_stun")
            Trait.onDamaged(c, sated, { amount = 12, attacker = foe, critical = true, tags = { "physical" } })
            assert(meals(sated) == 1, "and a stunned Sated still loses one")
        end,
    },
    {
        name = "anything that dies beside it is eaten and puts a meal back, to three; a body across the glade is not",
        fn = function()
            local c = Combat.new(board(), { walker(1, 1) },
                { unit("character_the_sated", 4, 4), unit("character_hawk", 6, 4), unit("character_hawk", 9, 9) })
            local foe, sated, near, far = c.units[1], c.units[2], c.units[3], c.units[4]
            Status.spendStacks(c, sated, "status_full", 2)
            kill(c, far, foe)
            assert(meals(sated) == 1, "a hawk dying across the glade feeds nothing")
            kill(c, near, foe)
            assert(meals(sated) == 2, "a hawk dying at its feet is eaten, got " .. meals(sated))
            assert(near.devoured, "and it is gone whole")
        end,
    },
    {
        name = "a company body that goes down beside it is eaten: out for this fight, and never revived",
        fn = function()
            local c = Combat.new(board(), { walker(6, 4, 20) }, { unit("character_the_sated", 4, 4) })
            local hero, sated = c.units[1], c.units[2]
            Status.spendStacks(c, sated, "status_full", 1)
            kill(c, hero, sated)
            assert(hero.devoured and not hero.incapacitated, "the body is eaten where it fell")
            assert(meals(sated) == 3, "and the Sated is full again")
        end,
    },
    {
        name = "Retch costs a meal and leaves Acid in the cone; an empty Sated cannot retch",
        fn = function()
            local c = Combat.new(board(), { walker(6, 4) }, { unit("character_the_sated", 4, 4) })
            local hero, sated = c.units[1], c.units[2]
            local retch = itemNamed(sated.char, "ability_retch")
            openTurn(c, sated)
            assert(Combat.useItem(c, sated, retch, 6, 4), "it retches at the body beside it")
            assert(Status.has(hero, "status_acid"), "the bile eats the armour off it")
            assert(hp(hero) < 300, "and burns")
            assert(meals(sated) == 2, "it cost a meal, got " .. meals(sated))
            Status.spendStacks(c, sated, "status_full", 2)
            assert(Combat.itemBlockReason(sated, retch), "nothing left to bring up: refused")
        end,
    },
    {
        name = "Settle heaves the whole body two tiles for a meal, and crushes what is in the way aside",
        fn = function()
            local c = Combat.new(board(10), { walker(7, 4) }, { unit("character_the_sated", 4, 4) })
            local hero, sated = c.units[1], c.units[2]
            local settle = itemNamed(sated.char, "ability_settle")
            openTurn(c, sated)
            -- The body covers (4..5, 4..5); aim the tile beside its right edge.
            assert(Combat.useItem(c, sated, settle, 6, 4), "it settles to the east")
            assert(sated.x == 6 and sated.y == 4, "two tiles east, got " .. sated.x .. "," .. sated.y)
            assert(hp(hero) < 300, "the body in the lane took its weight")
            assert(not (hero.x == 7 and hero.y == 4), "and was shoved out of the way")
            assert(meals(sated) == 2, "it cost a meal")
        end,
    },

    {
        -- THE REAL PLANNER, over a board where Retch and Settle are both live and a hawk has a body below
        -- half in reach. Planning forecasts every option through the dry-run fx, so a meal spent or a
        -- grip taken during planning would be a preview reaching into the fight.
        name = "the planner weighs the Sated's and the hawk's options without spending a meal or pinning anyone",
        fn = function()
            local AI = require("models.ai")
            local c = Combat.new(board(10), { walker(6, 4), walker(8, 8, 300) },
                { unit("character_the_sated", 4, 4), unit("character_hawk", 8, 6) })
            local near, weak, sated, hawk = c.units[1], c.units[2], c.units[3], c.units[4]
            weak.char.stats.health.current = 60
            openTurn(c, sated)
            local act = AI.plan(c, sated)
            assert(act, "the Sated has a plan")
            assert(meals(sated) == 3, "and planning it spent no meal")
            openTurn(c, hawk)
            assert(AI.plan(c, hawk), "the hawk has a plan")
            assert(not Status.has(weak, "status_mantled") and not hawk.mantlingPrey, "and planning pinned nobody")
            assert(near.alive, "nobody was hurt by a forecast")
        end,
    },

    -- ------------------------------------------------------------------------------ the hawk
    {
        name = "Swoop: every tile the hawk flew before the strike is a point of damage, to six",
        fn = function()
            local c = Combat.new(board(10), { unit("character_hawk", 2, 4) }, { walker(9, 4) })
            local hawk, foe = c.units[1], c.units[2]
            local talons = itemNamed(hawk.char, "weapon_raking_talons")
            hawk.turnStartX, hawk.turnStartY = 2, 4
            assert(Trait.outgoingDamageBonus(c, hawk, foe, talons, {}) == 0, "no run, no bonus")
            hawk.x = 5
            assert(Trait.outgoingDamageBonus(c, hawk, foe, talons, {}) == 3, "three tiles, +3")
            hawk.turnStartX = 1
            hawk.x, hawk.y = 9, 5
            assert(Trait.outgoingDamageBonus(c, hawk, foe, talons, {}) == 6, "capped at +6")
        end,
    },
    {
        name = "a rake that leaves its quarry above half flies home; below half, the hawk mantles and stays",
        fn = function()
            local c = Combat.new(board(), { unit("character_hawk", 2, 4) }, { walker(5, 4, 300) })
            local hawk, foe = c.units[1], c.units[2]
            local talons = itemNamed(hawk.char, "weapon_raking_talons")
            openTurn(c, hawk)
            c.turn.startX, c.turn.startY = 2, 4
            hawk.x, hawk.y = 4, 4
            assert(Combat.useItem(c, hawk, talons, 5, 4), "the rake lands")
            assert(hawk.x == 2 and not Status.has(foe, "status_mantled"), "healthy quarry: back to the perch")

            foe.char.stats.health.current = 100 -- a third of 300
            hawk.x, hawk.y = 4, 4
            assert(Combat.useItem(c, hawk, talons, 5, 4), "the rake lands again")
            assert(Status.has(foe, "status_mantled") and Status.has(hawk, "status_mantling"), "it mantles")
            assert(hawk.x == 4, "and does not fly home")
            assert(Status.blocksForcedMove(foe) and Status.blocksMove(foe), "the prey is rooted")
            assert(Status.blocksMove(hawk), "and the hawk will not leave it")
        end,
    },
    {
        name = "the mantled body bleeds each turn, a Cure does not lift the bird, and any blow on the hawk does",
        fn = function()
            local c = Combat.new(board(), { unit("character_hawk", 4, 4) }, { walker(5, 4, 300) })
            local hawk, foe = c.units[1], c.units[2]
            Status.apply(c, foe, "status_mantled", { applier = hawk })
            assert(hawk.mantlingPrey == foe and foe.mantledBy == hawk, "the two are tied")
            local before = hp(foe)
            for _ = 1, 5 do Status.tick(c, 1) end
            assert(hp(foe) < before, "a turn's feeding drew blood")
            Status.cleanse(c, foe)
            assert(Status.has(foe, "status_mantled"), "a Cure does not take a bird off you")
            Combat.dealFlatDamage(c, hawk, 1, { "physical" }, "test", foe)
            assert(not Status.has(foe, "status_mantled") and not Status.has(hawk, "status_mantling"),
                "a blow on the hawk breaks the grip")
            assert(not foe.mantledBy and not hawk.mantlingPrey, "and unties them")
        end,
    },
    {
        name = "a mantled body that dies beside the Sated is eaten with the hawk still on it",
        fn = function()
            local c = Combat.new(board(), { walker(6, 4, 20) },
                { unit("character_the_sated", 4, 4), unit("character_hawk", 7, 4) })
            local hero, sated, hawk = c.units[1], c.units[2], c.units[3]
            Status.spendStacks(c, sated, "status_full", 3)
            Status.apply(c, hero, "status_mantled", { applier = hawk })
            kill(c, hero, hawk)
            assert(not hawk.alive and hawk.devoured, "the hawk went down with its meal")
            assert(meals(sated) == 2, "two meals from one death, got " .. meals(sated))
        end,
    },

    -- ------------------------------------------------------------------------------ the Griffin
    {
        name = "On the Wing: half damage for three blows, then the crash, then it flies again",
        fn = function()
            local c = Combat.new(board(), { walker(4, 5) }, { unit("character_griffin", 5, 5) })
            local foe, griffin = c.units[1], c.units[2]
            assert(Status.stacksOf(griffin, "status_on_the_wing") == 3, "three stacks at the bell")
            local base = 40
            local flying = Combat.mitigatedDamage(griffin, base, { "physical" })
            Status.remove(c, griffin, "status_on_the_wing")
            local whole = Combat.mitigatedDamage(griffin, base, { "physical" })
            assert(flying == math.floor(whole * 0.5 + 0.5), "flying halves the blow (" .. flying .. " vs " .. whole .. ")")
            Status.apply(c, griffin, "status_on_the_wing", { magnitude = 3 })
            for i = 1, 3 do Trait.onDamaged(c, griffin, { amount = 5, attacker = foe, tags = { "physical" } }) end
            assert(not Status.has(griffin, "status_on_the_wing"), "three blows strip the wing")
            assert(Status.has(griffin, "status_grounded") and Status.has(griffin, "status_stun"), "grounded and stunned")
            Status.remove(c, griffin, "status_grounded")
            assert(Status.stacksOf(griffin, "status_on_the_wing") == 3, "and it takes wing again with three")
        end,
    },
    {
        name = "Answers Every Blow bites back at every melee blow, free, however many come",
        fn = function()
            local c = Combat.new(board(), { walker(4, 5), walker(6, 5) }, { unit("character_griffin", 5, 5) })
            local a, b, griffin = c.units[1], c.units[2], c.units[3]
            -- Grounded first: a third blow would otherwise strip the last wing and STUN it, and a stunned
            -- body answers nothing -- which is right, and is not what this case is about.
            Status.remove(c, griffin, "status_on_the_wing")
            local stamina = griffin.char.stats.stamina.current
            for _, who in ipairs({ a, b, a }) do
                local before = hp(who)
                Trait.onDamaged(c, griffin, { amount = 3, attacker = who, tags = { "physical" } })
                assert(hp(who) < before, "every blow is answered")
            end
            assert(griffin.char.stats.stamina.current == stamina, "and it never pays for one")
            local far = walker(1, 1)
            local c2 = Combat.new(board(), { far }, { unit("character_griffin", 5, 5) })
            local before = hp(c2.units[1])
            Trait.onDamaged(c2, c2.units[2], { amount = 3, attacker = c2.units[1], tags = { "physical" } })
            assert(hp(c2.units[1]) == before, "a blow from range is not bitten")
        end,
    },
    {
        name = "Mated for Life: when one of the pair falls, the other eats it and is Gorged for the fight",
        fn = function()
            local c = Combat.new(board(), { walker(1, 1) },
                { unit("character_griffin", 5, 5), unit("character_griffin", 7, 7), unit("character_hawk", 3, 3) })
            local foe, one, two, hawk = c.units[1], c.units[2], c.units[3], c.units[4]
            kill(c, hawk, foe)
            assert(not Status.has(one, "status_gorged"), "a hawk falling is not a mate")
            kill(c, two, foe)
            local g = Status.get(one, "status_gorged")
            assert(g and g.remaining >= 999, "the survivor is Gorged for the rest of the battle")
        end,
    },

    -- ------------------------------------------------------------------------------ the drops
    {
        name = "Bottomless Gut: a foe dying beside you is a meal, to three",
        fn = function()
            local hero = walker(4, 4)
            Fixture.give(hero.char, "utility_bottomless_gut")
            local c = Combat.new(board(), { hero },
                { unit("character_hawk", 5, 4), unit("character_hawk", 3, 4), unit("character_hawk", 9, 9) })
            local me = c.units[1]
            local dmg0, mv0 = stat(me, "damage"), stat(me, "movement")
            kill(c, c.units[4], me)
            assert(meals(me) == 0, "a death across the field is not a meal")
            kill(c, c.units[2], me)
            assert(meals(me) == 1 and stat(me, "damage") == dmg0 + 2 and stat(me, "movement") == mv0 - 1,
                "one meal: +2 damage, -1 movement")
            assert(stat(me, "speed") == Combat.flatStat(me, "speed"), "and it costs no speed")
        end,
    },
    {
        name = "Distended Girth: full at the bell, and each quarter lost sheds a meal and a debuff",
        fn = function()
            local hero = walker(4, 4, 100)
            Fixture.give(hero.char, "armor_distended_girth")
            local c = Combat.new(board(), { hero }, { walker(8, 8) })
            local me = c.units[1]
            assert(meals(me) == 3, "three meals at the bell")
            Status.apply(c, me, "status_acid")
            me.char.stats.health.current = 70
            Trait.onDamaged(c, me, { amount = 30, tags = { "physical" } })
            assert(meals(me) == 2 and not Status.has(me, "status_acid"), "past 75%: one meal and the Acid go")
            me.char.stats.health.current = 20
            Trait.onDamaged(c, me, { amount = 50, tags = { "physical" } })
            assert(meals(me) == 0, "past 50% and 25% at once: both remaining meals go")
        end,
    },
    {
        name = "Second Helping devours a corpse for two meals, and while full you cannot be moved",
        fn = function()
            local hero = walker(4, 4)
            Fixture.give(hero.char, "ability_second_helping")
            local c = Combat.new(board(), { hero }, { unit("character_hawk", 5, 4) })
            local me, hawk = c.units[1], c.units[2]
            kill(c, hawk, me)
            openTurn(c, me)
            assert(Combat.useItem(c, me, itemNamed(me.char, "ability_second_helping"), 5, 4), "it eats")
            assert(meals(me) == 2, "two meals")
            assert(Status.blocksForcedMove(me), "planted")
        end,
    },
    {
        name = "Sated passes a heal to the most hurt neighbour while its bearer is whole",
        fn = function()
            local hero = walker(4, 4, 100)
            Fixture.give(hero.char, "utility_sated_charm")
            local c = Combat.new(board(), { hero, walker(5, 4, 100), walker(3, 4, 100) }, { walker(9, 9) })
            local me, left, right = c.units[1], c.units[2], c.units[3]
            left.char.stats.health.current, right.char.stats.health.current = 90, 60
            Combat.applyHeal(c, me, 10)
            assert(hp(right) == 70 and hp(left) == 90, "the heal went to the most hurt beside it")
            me.char.stats.health.current = 50
            Combat.applyHeal(c, me, 10)
            assert(hp(me) == 60, "hurt, it keeps its own heal")
        end,
    },
    {
        name = "Gorger's Beak pays on a consumable used and not on a swing, to three",
        fn = function()
            local hero = walker(4, 4)
            Fixture.give(hero.char, "utility_gorgers_beak")
            local c = Combat.new(board(), { hero }, { walker(9, 9) })
            local me = c.units[1]
            local d0 = stat(me, "damage")
            local potion = Item.instantiate("consumable_healing_potion")
            local sword = Item.instantiate("weapon_iron_sword")
            for _ = 1, 4 do Trait.onCast(c, me, { item = potion }) end
            Trait.onCast(c, me, { item = sword })
            assert(stat(me, "damage") == d0 + 6, "+2 a draught, capped at +6, got " .. (stat(me, "damage") - d0))
        end,
    },
    {
        name = "Tithe Feather heals its bearer when a beast it summoned strikes",
        fn = function()
            local hero = walker(4, 4, 100)
            Fixture.give(hero.char, "utility_tithe_feather")
            local c = Combat.new(board(), { hero }, { walker(9, 9) })
            local me, foe = c.units[1], c.units[2]
            me.char.stats.health.current = 50
            local wolf = require("models.summon").spawn(c, me, "character_wolf_grunt", 8, 9)
            Trait.onAllyStrike(c, wolf, foe)
            assert(hp(me) == 53, "the beast's blow is tithed home, got " .. hp(me))
        end,
    },
    {
        name = "Hawk Bells: an Invisible foe within three tiles can be targeted, one further out cannot",
        fn = function()
            local hero = walker(4, 4)
            Fixture.give(hero.char, "utility_hawk_bells")
            local c = Combat.new(board(10), { hero }, { walker(7, 4), walker(9, 9) })
            local near, far = c.units[2], c.units[3]
            Status.apply(c, near, "status_invisible")
            Status.apply(c, far, "status_invisible")
            assert(not Status.untargetable(near, c), "three tiles off: the bells find it")
            assert(Status.untargetable(far, c), "further out: still hidden")
        end,
    },
}
