-- Tests for THE UNSEEING -- the boar lord who never touches you, and the thing he becomes.
--
-- Four of these pin failures that actually happened while the fight was being built, and each was
-- invisible to every other spec in the suite:
--
--   * the clan had no ceiling that held, because a rule is not a gate (AI.plan falls through to the
--     posture, which just takes the best thing in the kit -- and the Call is the ONLY thing in his kit).
--     He called 25 boars, gridlocked the arena, and the fight could neither be won nor lost.
--   * the planner could not see a summon AT ALL: AI.scoreCandidate's outcome gate reads per-unit damage
--     and healing, a summon produces neither, and an action scoring zero is refused. No enemy blueprint
--     had ever carried one, so nothing said so.
--   * the fix for that was too broad and quietly broke the boar: `mutates` is set by anything touching
--     the board INCLUDING moving the caster, so a Gore down an empty lane started scoring as an
--     accomplishment. tests/boar_spec.lua asserts the footprint catches nobody; only this asserts the
--     planner then declines to spend a turn on it.
--   * the Taking has to reach the dying as well as the dead -- two different engine states, two
--     different calls -- or half the bodies on the floor are invisible to it.

local AI = require("models.ai")
local Character = require("models.character")
local Combat = require("models.combat")
local Item = require("models.item")
local Status = require("models.status")

local function arena(cols, rows)
    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do
            tiles[y][x] = { type = "ground", moveCost = 1, walkable = true, sightCost = 0 }
        end
    end
    return { cols = cols, rows = rows, tiles = tiles, objective = { type = "killAll" } }
end

local function unit(id, x, y) return { char = Character.instantiate(id), x = x, y = y } end
local function openTurn(c, u) c.turn = { unit = u, moved = false, moveCost = 0 } end

local function itemOf(u, id)
    for _, it in ipairs(Character.eachItem(u.char)) do
        if it.id == id then return it end
    end
end

local function enemies(c)
    local n = 0
    for _, u in ipairs(c.units) do
        if u.alive and u.side ~= "party" then n = n + 1 end
    end
    return n
end

return {
    {
        name = "his kit is creature gear: unstealable, unpriced, on nobody's shelf",
        fn = function()
            -- docs/bestiary.md's rule, asserted structurally rather than by rolling the drop pool: a
            -- boss's whole fight is in these files, and `class = "creature"` with no axis at all is
            -- what keeps any of it from being minted onto a counter or carried home.
            for _, id in ipairs({ "ability_the_call", "ability_the_taking", "weapon_writhing_mass",
                                  "utility_the_iron_in_him", "utility_the_turned_hide" }) do
                local def = Item.defs[id]
                assert(def, id .. " exists")
                assert(def.class == "creature", id .. " belongs to no job")
                assert(def.noSteal, id .. " cannot be lifted off him")
                assert(def.price == nil, id .. " is on no shelf")
                assert(def.unlockLevel == nil, id .. " is at no depth")
            end
            -- The signature relic is the one that would hurt most to lose in a grab: it carries the
            -- whole phase script, so lifting it would delete the second half of the fight.
            local iron = Item.defs.utility_the_iron_in_him
            assert(iron.bound, "the iron does not come out")
            assert(iron.phases and #iron.phases == 1, "and it holds the one stage the fight has")
        end,
    },
    {
        name = "he walks in carrying nothing that can hurt anybody",
        fn = function()
            -- The design, asserted rather than trusted: phase one is the clan, and he is the reason
            -- there keeps being one. If a weapon ever lands in this kit the fight stops being that.
            local lord = Character.instantiate("character_the_unseeing")
            for _, it in ipairs(Character.eachItem(lord)) do
                local ab = it.activeAbility
                assert(not (ab and ab.damage), it.id .. " can hurt somebody, and he must not be able to")
            end
            assert(itemOf({ char = lord }, "ability_the_call"), "the call is the whole of his turn")
        end,
    },
    {
        name = "the planner will actually spend his turn calling -- a summon scores as an outcome",
        fn = function()
            -- THE GATE. AI.scoreCandidate's `outcome` decides whether an action is worth taking at all,
            -- and it is summed from per-unit damage/heal/status entries -- of which a summon produces
            -- exactly none. Before AI.WEIGHTS.MUTATION this scored 0 and was refused, which means the
            -- enemy AI could not plan a summon in any fight, however its rules were written.
            local c = Combat.new(arena(14, 14), { unit("character_rowan", 10, 10) },
                { unit("character_the_unseeing", 3, 3) })
            local lord = c.units[2]
            openTurn(c, lord)
            local plan = AI.plan(c, lord)
            assert(plan and plan.item, "he plans an action rather than standing there")
            assert(plan.item.id == "ability_the_call",
                "and it is the call, got " .. tostring(plan.item.id))
        end,
    },
    {
        name = "the clan has a ceiling he cannot afford to break, not one his rules decline to break",
        fn = function()
            -- A RULE IS NOT A GATE. `count_at_most` on the ai block is honoured and beside the point:
            -- when no authored rule matches, AI.plan falls through to the posture, which scores the kit
            -- and takes the best thing in it. The reservation is the ceiling because it makes the cast
            -- unaffordable rather than merely unchosen.
            local c = Combat.new(arena(16, 16), { unit("character_rowan", 14, 14) },
                { unit("character_the_unseeing", 4, 4) })
            local lord = c.units[2]
            local call = itemOf(lord, "ability_the_call")
            -- Let him call as often as the engine will allow, with the turn re-opened every time.
            for _ = 1, 12 do
                openTurn(c, lord)
                lord.char.stats.stamina.current = Combat.unreservedMax(lord.char, "stamina")
                Combat.useItem(c, lord, call, lord.x, lord.y)
            end
            local n = enemies(c)
            assert(n > 1, "he called at least one of the clan, got " .. n)
            assert(n <= 5, "twelve turns of calling produced " .. n ..
                " bodies -- the reservation is not holding the clan down")
        end,
    },
    {
        name = "each of his boars leaves curse where it falls, and a roadside boar leaves clean ground",
        fn = function()
            -- The bargain rides on the CALL, not on the blueprint (Summon.spawn's opts.traits), which
            -- is what keeps data/characters/character_boar.lua out of this fight entirely.
            local Hazard = require("models.hazard")
            local c = Combat.new(arena(14, 14), { unit("character_rowan", 12, 12) },
                { unit("character_the_unseeing", 4, 4) })
            local lord = c.units[2]
            openTurn(c, lord)
            Combat.useItem(c, lord, itemOf(lord, "ability_the_call"), lord.x, lord.y)
            local called
            for _, u in ipairs(c.units) do
                if u.alive and u.char.id == "character_boar" then called = u end
            end
            assert(called, "a boar arrived")
            local cx, cy = called.x, called.y
            Combat.dealFlatDamage(c, called, 9999, { "physical" }, "a test")
            assert(not called.alive, "and it is down")
            assert(Hazard.at(c, cx, cy), "the tile it fell on is cursed")

            -- The control: an ordinary Wild Boar, same blueprint, no bargain struck.
            local c2 = Combat.new(arena(10, 10), { unit("character_rowan", 8, 8) },
                { unit("character_boar", 3, 3) })
            local wild = c2.units[2]
            local wx, wy = wild.x, wild.y
            Combat.dealFlatDamage(c2, wild, 9999, { "physical" }, "a test")
            assert(not Hazard.at(c2, wx, wy),
                "a boar off the road leaves clean ground -- the curse belongs to the call")
        end,
    },
    {
        name = "curse eats at you and denies healing, and both stop when you step off",
        fn = function()
            local Hazard = require("models.hazard")
            local c = Combat.new(arena(10, 10), { unit("character_rowan", 3, 3) },
                { unit("character_boar", 9, 9) })
            local knight = c.units[1]
            Combat.openBattle(c)
            openTurn(c, knight) -- Combat.moveUnit plans a real walk, and a walk needs a turn to spend
            Hazard.place(c, 4, 3, "hazard_curse", {})
            local hp = knight.char.stats.health
            hp.current = math.max(1, hp.max - 30)

            Combat.moveUnit(c, knight, 4, 3)
            assert(Status.has(knight, "status_cursed"), "standing in it, the ground has hold of you")
            local before = hp.current
            Combat.applyHeal(c, knight, 20)
            assert(hp.current == before, "and nothing heals it")
            -- ...and it BLEEDS. A zone-bound status still fires onTick (Status.tick skips the countdown,
            -- not the hook), which is the whole reason ground can eat a body without a duration on the
            -- badge -- and the half that makes the refusal bite, since it is what creates the wound
            -- there is then no way to close.
            Combat.rebase(c)
            Status.tick(c, 10)
            assert(hp.current < before, "and standing there costs health, got " .. hp.current)

            openTurn(c, knight) -- a fresh turn: the walk above spent the last one
            Combat.moveUnit(c, knight, 5, 3)
            assert(not Status.has(knight, "status_cursed"),
                "off the ground it lapses -- it is zone-bound, so walking out IS the answer")
            local wounded = hp.current
            Combat.applyHeal(c, knight, 20)
            assert(hp.current > wounded, "and the healing lands again")
        end,
    },
    {
        name = "at half his blood he stops being a boar, and the bar does not jump",
        fn = function()
            local c = Combat.new(arena(14, 14), { unit("character_rowan", 12, 12) },
                { unit("character_the_unseeing", 4, 4) })
            local lord = c.units[2]
            -- THE OPENING BELL ATTACHES THE TRAITS. Combat.new seats the bodies; Trait.attach runs for
            -- an opening unit at Combat.openBattle, so a phase script tested without it is inert and
            -- the case passes or fails on nothing.
            Combat.openBattle(c)
            local hp = lord.char.stats.health
            -- A blow that crosses the threshold without killing: the phase fires on a SURVIVOR. Sized
            -- well past half rather than just over it, because this lands MITIGATED -- his defense is 11,
            -- and a blow measured to leave him at exactly 45% leaves him at 53% and turns nothing.
            Combat.dealFlatDamage(c, lord, math.floor(hp.max * 0.7), { "physical" }, "a test")
            assert(lord.alive, "he survives the blow that turns him")
            assert(lord.char.id == "character_the_turning",
                "the iron wins, got " .. tostring(lord.char.id))
            local after = lord.char.stats.health
            assert(after.current == hp.current,
                "the wound carries across the transform -- it changes what he can do, never how much "
                .. "killing he takes")
            assert(itemOf(lord, "weapon_writhing_mass"), "and now, for the first time, he has a blow")
        end,
    },
    {
        name = "the Taking stands up the dying and the dead alike",
        fn = function()
            -- TWO ENGINE STATES, and reaching only one of them would leave half the floor invisible.
            -- A downed body is inside its revive window and Combat.corpseAt refuses it outright; a cold
            -- one is past reviving and Combat.reanimate refuses THAT. The ability has to ask both.
            local c = Combat.new(arena(14, 14), { unit("character_rowan", 12, 12) },
                -- THE BODIES MUST LIE OUTSIDE HIS OWN FOOTPRINT. He is 2x2 anchored at (5,5), so he
                -- stands on (5,5)-(6,6) -- and Combat.corpseAt refuses a tile a living unit occupies,
                -- which would make a corpse under his own feet permanently unreachable.
                { unit("character_the_turning", 5, 5),
                  unit("character_boar", 4, 4), unit("character_boar", 4, 7) })
            local lord, a, b = c.units[2], c.units[3], c.units[4]
            Combat.openBattle(c)
            Combat.dealFlatDamage(c, a, 9999, { "physical" }, "a test")
            Combat.dealFlatDamage(c, b, 9999, { "physical" }, "a test")
            assert(not a.alive and not b.alive, "both are down")
            -- One left dying, one taken all the way cold.
            b.incapacitated, b.corpse = false, true
            b.statuses = {}
            assert(a.incapacitated, "the first is still inside its window")

            openTurn(c, lord)
            lord.char.stats.stamina.current = 99
            assert(Combat.useItem(c, lord, itemOf(lord, "ability_the_taking"), lord.x, lord.y),
                "the taking resolves")

            assert(a.alive, "the dying one is stood back up as itself")
            local standing = 0
            for _, u in ipairs(c.units) do
                if u.alive and u.char.id == "character_boar" then standing = standing + 1 end
            end
            assert(standing == 2, "and a fresh body takes the cold one's place -- got " .. standing)
        end,
    },
    {
        name = "the ground he crosses takes the curse, and the wake closes behind him",
        fn = function()
            local Hazard = require("models.hazard")
            local c = Combat.new(arena(12, 12), { unit("character_rowan", 10, 10) },
                { unit("character_the_turning", 3, 3) })
            local lord = c.units[2]
            Combat.openBattle(c)
            openTurn(c, lord)
            Combat.moveUnit(c, lord, 4, 3)
            assert(Hazard.at(c, 3, 3), "the tile he left is cursed -- a trail is ground you LEAVE")
            -- Shorter than what a dead boar leaves: a monument sits, a wake closes.
            local hide = Item.defs.utility_the_turned_hide
            assert(hide.trail and hide.trail.duration
                and hide.trail.duration < Hazard.defs.hazard_curse.duration,
                "his wake is shorter-lived than the ground a body leaves, or a five-movement animal "
                .. "paints the whole arena in three turns")
        end,
    },
    {
        name = "a charge that catches nobody is still refused -- the summon fix did not widen the gate",
        fn = function()
            -- REGRESSION. AI.WEIGHTS.MUTATION exists so a summon can clear the outcome gate, and
            -- `mutates` is set by anything touching the board -- which includes fx.chargeInto moving the
            -- charger. Credited to hostile casts it paid a boar for charging at nothing: the ordinary
            -- road fight went 19 unit-turns -> 44 with the animals running empty lanes.
            local c = Combat.new(arena(14, 14), { unit("character_rowan", 6, 9) },
                { unit("character_boar", 6, 3) })
            local boar = c.units[2]
            -- Far enough that the knight is outside the charge's reach entirely: the only thing Gore
            -- could do here is move the boar, which is exactly the whiff that must not score.
            local gore = itemOf(boar, "ability_gore")
            local preview = Combat.previewAbility(c, boar, gore, 6, 6)
            assert(preview and preview.mutates == true,
                "the charge does mark the board -- which is what made the broad version pay out")
            assert(#(preview.order or {}) == 0, "and it catches nobody standing there")
            openTurn(c, boar)
            local plan = AI.plan(c, boar)
            assert(not (plan and plan.item and plan.item.id == "ability_gore"),
                "so the planner must not spend the turn on it")
        end,
    },
}
