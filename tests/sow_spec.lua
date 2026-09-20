-- Tests for THE SOW and her cub -- the bears anybody fights, and the one compounding threat in the game.
--
-- Three of these hold rules that no other spec in the suite can see:
--
--   * Status.vulnerability was a sum over BLUEPRINT constants, so no status could carry a number that
--     grew. The scaling is opt-in, which means the regression it could cause is silent in the other
--     direction too -- every status shipping today must still read exactly as it did. Both halves are
--     asserted here, on the same call.
--   * trait_fury_swipes counts only blows that LAND, and tests/skirmish_spec.lua runs under a pinned
--     FORCE_HIT -- so the budget harness fights in a world where nothing ever misses and the gate can
--     never fire. It has to be driven directly, which the last case does.
--   * trait_bereaved is the only boss trigger in the game the PLAYER pulls. It fires on a specific
--     blueprint dying on her own side, so the two ways to get it wrong are firing for any corpse and
--     firing twice; neither shows up in a fight nobody has scripted.
--
-- And the first case is the Gralloch's lesson, asserted rather than trusted: character_dire_bear is
-- CARGO (a Wild Shape, tier 0, health = 1) and these two are combatants. A blueprint used as both has
-- shipped once already and cost a floor's centrepiece.

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

local function stacksOn(u)
    local s = Status.get(u, "status_fury_swipes")
    return s and s.magnitude or 0
end

return {
    {
        name = "the bears anybody fights are not the bear a druid wears",
        fn = function()
            -- THE SPLIT, asserted on the three facts that made the original bug what it was. The Dire
            -- Bear is cargo: rung 0, a placeholder pool the hunter's own body replaces, and no innate
            -- hide (tier 0 is outside the resist system entirely -- Balance.INNATE_BUDGET has no entry
            -- for it, so a `resist` line here would fail tests/bestiary_spec.lua rather than help).
            local shape = Character.defs.character_dire_bear
            assert(shape.tier == 0, "the shape is off the ladder")
            assert(shape.resist == nil, "and outside the innate-resist system with it")

            for _, id in ipairs({ "character_bear", "character_sow" }) do
                local def = Character.defs[id]
                assert(def, id .. " exists")
                assert((def.tier or 0) > 0, id .. " is on the ladder, unlike the shape")
                assert(def.resist, id .. " declares what it has instead of a coat")
                -- The pool the original bug turned into one health at level 1.
                local live = Character.instantiate(id)
                assert(live.stats.health.max > 30,
                    id .. " has a real pool, not the shape's placeholder")
            end

            -- The offer the whole fight is built on: the cub must be killable cheaply and early, so it
            -- carries none of the protections a centrepiece does.
            assert(Character.defs.character_sow.boss, "the sow is the fight")
            assert(not Character.defs.character_bear.boss,
                "the cub must stay on the execute and Charm tables -- being killable IS the offer")
        end,
    },
    {
        name = "both bears' kit is creature gear: unstealable, unpriced, on nobody's shelf",
        fn = function()
            -- docs/bestiary.md's rule, asserted structurally rather than by rolling the pool: a boss's
            -- own rule must never be minted onto a counter or carried home.
            for _, id in ipairs({ "utility_the_same_wound", "utility_the_year_behind_her",
                                  "ability_overpower" }) do
                local def = Item.defs[id]
                assert(def, id .. " exists")
                assert(def.class == "creature", id .. " belongs to no job")
                assert(def.noSteal, id .. " cannot be lifted off the animal")
                assert(def.price == nil, id .. " is on no shelf")
                assert(def.dropTier == nil, id .. " is at no depth")
            end
            -- The rage carries the whole back half of the fight, so it may not be disarmed out of it.
            assert(Item.defs.utility_the_year_behind_her.bound, "her relic does not come out")

            -- The cub teaches what the mother has: the same carrier on both bodies, which is what makes
            -- the opening turns a lesson rather than filler.
            for _, id in ipairs({ "character_bear", "character_sow" }) do
                assert(itemOf({ char = Character.instantiate(id) }, "utility_the_same_wound"),
                    id .. " carries the ramp")
            end
        end,
    },
    {
        name = "a scaling wound is worth its stack, and every other vulnerability is untouched",
        fn = function()
            -- THE ENGINE CHANGE, both directions on one call. Before `vulnerableScales` a status's bag
            -- was a blueprint constant, so this returned 2 at every depth.
            local c = Combat.new(arena(8, 8), { unit("character_rowan", 2, 2) },
                { unit("character_bear", 5, 5) })
            local victim = c.units[1]
            local per = Status.defs.status_fury_swipes.vulnerable.slash

            for n = 1, 4 do
                Status.apply(c, victim, "status_fury_swipes", { magnitude = n })
                assert(Status.vulnerability(victim, { "slash" }) == per * n,
                    string.format("at %d stacks a slash should find %d, got %d",
                        n, per * n, Status.vulnerability(victim, { "slash" })))
            end
            -- It is a SLASH wound. An axe finds it; a spear does not.
            assert(Status.vulnerability(victim, { "pierce" }) == 0,
                "the wound is keyed to the edge that opened it")

            -- THE REGRESSION GUARD. A status that does not opt in must read exactly as it always has,
            -- whatever magnitude it happens to be carrying -- which is what keeps the opt-in honest.
            local other = c.units[2]
            Status.apply(c, other, "status_vulnerable_slash", { magnitude = 9 })
            assert(Status.vulnerability(other, { "slash" })
                == Status.defs.status_vulnerable_slash.vulnerable.slash,
                "a non-scaling vulnerability must ignore its magnitude entirely")
        end,
    },
    {
        name = "a landed blow deepens the wound, and the fourth is the last one that does",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_rowan", 4, 5) },
                { unit("character_bear", 4, 4) })
            local victim, bear = c.units[1], c.units[2]
            local claws = itemOf(bear, "weapon_great_claws")
            assert(claws, "the bear swings claws")

            local cap = require("models.trait").defs.trait_fury_swipes.maxStacks
            for i = 1, cap + 2 do
                openTurn(c, bear)
                -- Kept on its feet and kept in stamina: this case is about the COUNTER, and a bear that
                -- ran dry or a body that fell would stop the chain for reasons that are not the rule.
                bear.char.stats.stamina.current = Combat.unreservedMax(bear.char, "stamina")
                victim.char.stats.health.current = victim.char.stats.health.max
                Combat.useItem(c, bear, claws, victim.x, victim.y)
                assert(stacksOn(victim) == math.min(i, cap), string.format(
                    "blow %d should leave %d stacks, got %d", i, math.min(i, cap), stacksOn(victim)))
            end
        end,
    },
    {
        name = "a blow that draws nothing opens nothing -- the one rule FORCE_HIT hides",
        fn = function()
            -- tests/skirmish_spec.lua pins FORCE_HIT, so under the budget harness the bear never misses
            -- and this gate never fires. Driven here through the trait directly, because what is being
            -- asserted is precisely the branch a world without misses cannot reach.
            local c = Combat.new(arena(8, 8), { unit("character_rowan", 4, 5) },
                { unit("character_bear", 4, 4) })
            local victim, bear = c.units[1], c.units[2]
            local claws = itemOf(bear, "weapon_great_claws")

            openTurn(c, bear)
            Combat.useItem(c, bear, claws, victim.x, victim.y)
            assert(stacksOn(victim) == 1, "the landed blow opened it")

            -- A swing that drew no blood. The trait is handed the same cast with nothing dealt, which is
            -- what a miss looks like to it (models/trait.lua passes the cast's total along).
            local Trait = require("models.trait")
            Trait.onCast(c, bear, { item = claws, ability = claws.activeAbility,
                                    tx = victim.x, ty = victim.y, damageDealt = 0 })
            assert(stacksOn(victim) == 1,
                "a swing that drew nothing must not deepen the wound -- got " .. stacksOn(victim))
        end,
    },
    {
        name = "she wakes when her cub falls, and not for anybody else's dead",
        fn = function()
            local c = Combat.new(arena(10, 10), { unit("character_rowan", 8, 8) },
                { unit("character_sow", 3, 3), unit("character_bear", 4, 3),
                  unit("character_boar", 5, 3) })
            local sow = c.units[2]
            local before = (sow.bonus and sow.bonus.damage) or 0
            assert(not Status.has(sow, "status_enraged"), "she opens calm")

            -- Something else on her side falls. A rage any corpse could trigger would hand the player
            -- the escalation on a turn they were not choosing anything.
            Combat.dealFlatDamage(c, c.units[4], 9999, {}, "test")
            assert(not Status.has(sow, "status_enraged"),
                "a boar dying beside her is not her loss")
            assert(((sow.bonus and sow.bonus.damage) or 0) == before, "and moves nothing")

            -- The cub.
            Combat.dealFlatDamage(c, c.units[3], 9999, {}, "test")
            assert(Status.has(sow, "status_enraged"), "the cub falling is what wakes her")
            local gained = ((sow.bonus and sow.bonus.damage) or 0) - before
            local owed = require("models.trait").defs.trait_bereaved.damage
            assert(gained == owed,
                string.format("she should bank %d Damage, got %d", owed, gained))
        end,
    },
    {
        name = "Overpower buys a second swing, and the cub is not given one",
        fn = function()
            -- THE RAMP HAS TO BE REACHABLE. Great Claws is 12 stamina and the sow regains 4 a tick, so
            -- without this she lands about one blow a turn and the four-stack ceiling is most of a fight
            -- away. Asserted as the thing it actually buys -- two stacks in one turn -- rather than as
            -- the two effects it is built from, because either alone does nothing.
            local c = Combat.new(arena(8, 8), { unit("character_rowan", 4, 5) },
                { unit("character_sow", 4, 3) })
            local victim, sow = c.units[1], c.units[2]
            local claws, burst = itemOf(sow, "weapon_great_claws"), itemOf(sow, "ability_overpower")
            assert(burst, "she carries the button")

            openTurn(c, sow)
            local full = Combat.unreservedMax(sow.char, "stamina")
            sow.char.stats.stamina.current = full
            Combat.useItem(c, sow, burst, sow.x, sow.y)
            assert(Status.has(sow, "status_overpowered"), "the window opened")
            assert((sow.extraActions or 0) >= 1, "and it handed back an action")

            -- The discount is real: a swing under the window costs less than the claw's authored price.
            local before = sow.char.stats.stamina.current
            Combat.useItem(c, sow, claws, victim.x, victim.y)
            local spent = before - sow.char.stats.stamina.current
            assert(spent < claws.activeAbility.cost.amount, string.format(
                "a discounted swing should cost under %d, spent %d",
                claws.activeAbility.cost.amount, spent))
            assert(stacksOn(victim) >= 1, "and it still opened the wound")

            -- THE CUB IS THE RULE WITHOUT THE PAYOFF, which is what makes the road bear a lesson rather
            -- than a smaller sow. It carries the wound and no way to cash it.
            local cub = Character.instantiate("character_bear")
            assert(itemOf({ char = cub }, "utility_the_same_wound"), "the cub opens wounds")
            assert(not itemOf({ char = cub }, "ability_overpower"),
                "...and must not be able to burst -- the ramp without the button is the lesson")
        end,
    },
    {
        name = "when she falls her cub leaves, and it leaves without paying out like a kill",
        fn = function()
            local c = Combat.new(arena(10, 10), { unit("character_rowan", 8, 8) },
                { unit("character_sow", 3, 3), unit("character_bear", 5, 3) })
            local sow, cub = c.units[2], c.units[3]
            assert(cub.alive, "the cub is on the board")

            Combat.dealFlatDamage(c, sow, 9999, {}, "test")
            assert(not sow.alive, "she is down")
            assert(not cub.alive, "and the cub does not stay without her")

            -- DISMISSED, NOT KILLED. Combat.dismiss leaves no corpse, which is what keeps the exit from
            -- paying spoils, feeding an Engorge or counting toward a kill objective.
            assert(Combat.corpseAt(c, cub.x, cub.y) == nil,
                "a body that walked off the field leaves nothing to loot")

            -- And the cub the party killed first is simply not there to run: dismiss no-ops on the dead.
            local c2 = Combat.new(arena(10, 10), { unit("character_rowan", 8, 8) },
                { unit("character_sow", 3, 3), unit("character_bear", 5, 3) })
            Combat.dealFlatDamage(c2, c2.units[3], 9999, {}, "test")
            Combat.dealFlatDamage(c2, c2.units[2], 9999, {}, "test")
            assert(not c2.units[2].alive and not c2.units[3].alive, "both are gone, in that order")
        end,
    },
    {
        name = "every piece she is known for can actually be found, and depth is the rarity",
        fn = function()
            -- THE DROP CONTRACT (docs/drops.md), asserted structurally. Each of these is a silent
            -- failure otherwise: a list entry with no dropTier is a row no floor can ever pay, and
            -- noSteal, bound or creature class all have the pool refuse it outright -- in every case the
            -- list still reads correctly in the file and simply never fires.
            local list = Character.defs.character_sow.drops
            assert(list and #list == 3, "she is known for three things")
            for _, id in ipairs(list) do
                local def = Item.defs[id]
                assert(def, "she names " .. id .. ", which does not exist")
                assert(def.dropTier, id .. " has no dropTier, so no floor can pay it")
                assert(not def.noSteal, id .. " is sealed to a body and can never drop")
                assert(not def.bound, id .. " is bound to one grid and can never drop")
                assert(def.class ~= "creature", id .. " is creature kit; the pool refuses it")
                assert(def.price == nil, id .. " is found in the rift, not bought")
            end

            -- Her own fight carries no axis at all, so the pool cannot reach any of it however the list
            -- above is written -- the rule a boss's whole rule lives behind.
            for _, id in ipairs({ "weapon_great_claws", "ability_overpower",
                                  "utility_the_same_wound", "utility_the_year_behind_her" }) do
                local def = Item.defs[id]
                assert(def.dropTier == nil and def.price == nil,
                    id .. " carries an axis, so the pool could reach her own fight")
            end

            -- DEPTH IS THE RARITY. A floor picks a rank before it looks at who died, so the ORDER of
            -- these three numbers is the entire drop-rate design; there is no per-entry weight.
            local hide = Item.defs["armor_winterhide"].dropTier
            local claw = Item.defs["utility_knapped_claw"].dropTier
            local pelt = Item.defs["utility_the_yearling_pelt"].dropTier
            assert(pelt > claw, "the pelt is the chase; a shallower tier would make it the COMMON drop")
            assert(claw > hide, "and her rule is dearer than her coat")

            -- The coat is one rung over the boar's, because the animal is one rung harder.
            assert(hide > Item.defs["armor_bristlehide"].dropTier,
                "Winterhide sits over Bristlehide -- a bear is not a boar")
        end,
    },
    {
        name = "Bereft is her rule from the other side, and it cannot be farmed",
        fn = function()
            -- TRAITS BIND AT Combat.new, so the pelt has to be on the body BEFORE the fight is built --
            -- handing it over afterwards leaves a unit carrying the item and none of its rule, which is
            -- how the first cut of this case measured a bonus of zero and called it a bug in the trait.
            -- A BARE BODY, STRIPPED. The first cut used character_rowan and measured nothing: she walks
            -- in wearing armor_sworn_aegis, which puts her in front of the blow aimed at the ally -- so
            -- the ally never fell, the bearer did, and a hook that correctly declines to fire for a
            -- living ally read as a broken trait. The carrier of a test about somebody else dying must
            -- own nothing that can intervene.
            local carrier = Character.instantiate("character_bandit")
            for i = 1, Character.MAX_INVENTORY do carrier.inventory[i] = nil end
            Character.addItem(carrier, Item.instantiate("utility_the_yearling_pelt"))
            -- The far side is a BOAR and not the sow on purpose: she carries trait_orphaned, which
            -- reaches across the board for bears when she drops, and a case about grief should not also
            -- be testing whose bears those were.
            local c = Combat.new(arena(10, 10), { { char = carrier, x = 4, y = 4 },
                                                  unit("character_bear", 5, 4),
                                                  unit("character_bear", 6, 4) },
                { unit("character_boar", 9, 9) })
            local bearer = c.units[1]
            assert(require("models.trait").has(bearer, "trait_bereft"), "the pelt carries its rule")
            local before = (bearer.bonus and bearer.bonus.damage) or 0

            -- An enemy falling is not a loss. This is the whole difference from Blood Fever.
            Combat.dealFlatDamage(c, c.units[4], 9999, {}, "test")
            assert(not c.units[4].alive, "the guard on this case: the far side actually fell")
            assert(((bearer.bonus and bearer.bonus.damage) or 0) == before,
                "their dead are not your grief -- this must not be farmable")

            -- One of your own.
            local ally = c.units[2]
            Combat.dealFlatDamage(c, ally, 9999, {}, "test")
            assert(not ally.alive, "the same guard: the ally actually fell")
            assert(bearer.alive, "...and the bearer is still standing to feel it")
            local owed = require("models.trait").defs.trait_bereft.magnitude
            local after = (bearer.bonus and bearer.bonus.damage) or 0
            assert(after - before == owed,
                string.format("losing one of your own should bank %d, got %d", owed, after - before))

            -- ...and only the first. One body is grief; four would be a strategy.
            Combat.dealFlatDamage(c, c.units[3], 9999, {}, "test")
            assert(((bearer.bonus and bearer.bonus.damage) or 0) == after,
                "a second loss must not stack -- Bereft latches once")
        end,
    },
    {
        name = "the fight is wired to a floor, and the lesson is gated in front of the exam",
        fn = function()
            -- A SPEC ON THE BODY IS NOT A SPEC ON THE WIRING. Every blueprint above can be perfect and
            -- reach no floor; what puts it in front of a player is an encounter in the pool.
            local Encounter = require("models.encounter")
            local lesson = Encounter.defs.encounter_bear
            local exam = Encounter.defs.encounter_the_sow
            assert(lesson and exam, "both fights exist in the pool")

            assert(exam.kind == "elite", "she is judged as an elite, not held to the road budget")
            assert(lesson.kind == "combat", "the road bear is an ordinary stop")
            assert(exam.minDay > lesson.minDay, string.format(
                "the ramp must be taught (day %s) before it is examined (day %s)",
                tostring(lesson.minDay), tostring(exam.minDay)))

            -- Every body either fight names is real, and hers is the pair the design is about.
            -- One sow, a litter of cubs, and no filler. The count of cubs climbs with depth so the
            -- fight stays rateable, but nothing else may join it: the decision is about the cubs.
            for _, day in ipairs({ 6, 20, 40 }) do
                local roster = exam.composition({ day = day })
                local sows, cubs = 0, 0
                for _, id in ipairs(roster) do
                    assert(Character.defs[id], id .. " is a real blueprint")
                    if id == "character_sow" then sows = sows + 1
                    elseif id == "character_bear" then cubs = cubs + 1
                    else error("day " .. day .. " fields " .. id .. " -- she brings no filler") end
                end
                assert(sows == 1, "day " .. day .. " fields " .. sows .. " sows; there is one mother")
                assert(cubs >= 1, "day " .. day .. " fields no cub -- the offer IS the cub")
            end
            assert(#exam.composition({ day = 40 }) > #exam.composition({ day = 1 }),
                "the litter has to grow, or a deep company can walk past her")
            for _, id in ipairs(lesson.composition({ day = 1 })) do
                assert(id == "character_bear", "the lesson fields bears and nothing else")
            end
        end,
    },
    {
        name = "the party's own dead never wake her, and she cannot be woken twice",
        fn = function()
            local c = Combat.new(arena(10, 10), { unit("character_rowan", 8, 8) },
                { unit("character_sow", 3, 3), unit("character_bear", 4, 3),
                  unit("character_bear", 5, 3) })
            local sow = c.units[2]

            -- A body of the same blueprint on the OTHER side. The trait reads the fallen's side before
            -- its blueprint, so a party druid's bear dying is not her cub.
            local strays = Combat.new(arena(6, 6), { unit("character_bear", 2, 2) },
                { unit("character_sow", 4, 4) })
            local farSow = strays.units[2]
            Combat.dealFlatDamage(strays, strays.units[1], 9999, {}, "test")
            assert(not Status.has(farSow, "status_enraged"),
                "a bear on the far side is not hers")

            -- Two cubs, one rage. `stacks` is the once-ever latch.
            Combat.dealFlatDamage(c, c.units[3], 9999, {}, "test")
            local afterFirst = (sow.bonus and sow.bonus.damage) or 0
            Combat.dealFlatDamage(c, c.units[4], 9999, {}, "test")
            assert(((sow.bonus and sow.bonus.damage) or 0) == afterFirst,
                "a second cub must not double her")
        end,
    },
}
