-- Tests for the tactical AI (models/ai.lua): the condition vocabulary, the posture layer, and the
-- scored search over (stand tile, item, target). Pure logic only, so it runs headless.
--
-- The four cases that used to live in tests/combat_spec.lua under `planEnemyAction` are deliberately
-- left where they are: they describe the CONTRACT the battle state depends on (a plan is a move, an
-- item use, or a wait) and they are the regression net proving this module didn't change how an
-- ordinary enemy behaves. What is tested here is the judgement layered on top of that.

local Character = require("models.character")
local Item = require("models.item")
local Combat = require("models.combat")
local AI = require("models.ai")

-- A flat, all-walkable arena (no terrain), mirroring tests/combat_spec.lua's fixture.
local function arena(cols, rows, objective)
    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do
            tiles[y][x] = { type = "ground", moveCost = 1, walkable = true }
        end
    end
    return { cols = cols, rows = rows, tiles = tiles, objective = objective or { type = "killAll" } }
end

-- A { char, x, y } spawn entry. Strips the innate signature relic and its trait for the same reason
-- combat_spec does: a companion summon and a bound counter would perturb every unit count and every
-- risk term these fixtures reason about.
local function unit(charOrId, x, y, tweak)
    local char = type(charOrId) == "string" and Character.instantiate(charOrId) or charOrId
    char.traits = {}
    for i = 1, Character.MAX_INVENTORY do
        if char.inventory[i] and char.inventory[i].bound then char.inventory[i] = nil end
    end
    if tweak then tweak(char) end
    return { char = char, x = x, y = y }
end

-- "A melee unit carrying an iron sword", as in combat_spec: the fixture describes the unit it needs
-- rather than borrowing whichever blueprint happens to be equipped that way this month.
local function swordsman(archetype)
    local char = Character.instantiate("character_knight")
    char.inventory[1] = Item.instantiate("weapon_iron_sword")
    char.archetype = archetype
    return char
end

local function setHp(u, current)
    u.char.stats.health.current = current
end

-- A bandit re-kitted as a caster. The blueprint has `mana = 0`, so a spell dropped into its grid is
-- blocked by Combat.itemBlockReason before the AI ever weighs it -- fill the pool, or the fixture is
-- testing the cost gate rather than the decision.
local function caster(abilityId, archetype)
    local char = Character.instantiate("character_bandit")
    char.inventory[1] = Item.instantiate(abilityId)
    char.stats.mana = { max = 40, current = 40 }
    char.archetype = archetype
    return char
end

local function hpOf(u) return u.char.stats.health.current end

return {
    -- ---------------------------------------------------------------------
    -- Condition vocabulary
    -- ---------------------------------------------------------------------
    {
        name = "a rule condition reads subject x test, and an unconditional rule always matches",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit(swordsman(), 1, 1) }, { unit("character_bandit", 4, 4) })
            local bandit = c.units[2]
            local ctx = { combat = c, unit = bandit, items = {} }

            assert(AI.matches(ctx, { act = "attack" }), "a rule with no `when` is unconditional")
            assert(AI.matches(ctx, { when = { subject = "any_foe", test = "exists" } }),
                "the knight exists as a foe")
            assert(not AI.matches(ctx, { when = { subject = "any_foe", test = "within", value = 2 } }),
                "the knight is six tiles off, not within two")
            assert(AI.matches(ctx, { when = { subject = "any_foe", test = "within", value = 6 } }),
                "...but it is within six")

            setHp(c.units[1], 1)
            assert(AI.matches(ctx, { when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } }),
                "the wounded knight is the lowest-hp foe and reads as below half")
        end,
    },
    {
        name = "a typo'd subject or test is a loud error, never a silently-true condition",
        fn = function()
            local c = Combat.new(arena(6, 6), { unit(swordsman(), 1, 1) }, { unit("character_bandit", 3, 3) })
            local ctx = { combat = c, unit = c.units[2], items = {} }
            -- This is the single most expensive bug this system could have: a misspelled gambit that
            -- always fires looks exactly like working behavior until a battle goes strange.
            assert(not pcall(AI.matches, ctx, { when = { subject = "nearest_fo", test = "exists" } }),
                "an unknown subject raises")
            assert(not pcall(AI.matches, ctx, { when = { subject = "any_foe", test = "hp_below" } }),
                "an unknown test raises")
        end,
    },
    {
        name = "describeRule renders every action and preference without erroring",
        fn = function()
            for _, act in ipairs({ "attack", "support", "cast", "retreat", "wait" }) do
                for _, pref in ipairs({ "nearest", "lowest_hp", "lethal", "self", "objective" }) do
                    local text = AI.describeRule({ act = act, targetPref = pref,
                        when = { subject = "any_foe", test = "within", value = 2 } })
                    assert(type(text) == "string" and #text > 0, "rule renders as a sentence")
                end
            end
            assert(AI.describeRule(nil):find("no rule"), "a nil rule still renders something")
        end,
    },

    -- ---------------------------------------------------------------------
    -- Scoring
    -- ---------------------------------------------------------------------
    {
        name = "a lethal blow beats a closer target that would survive",
        fn = function()
            -- Two knights flank the bandit. The one it is standing next to is healthy; the one a step
            -- further off is at 1hp. The old planner took whichever was nearest; this one finishes
            -- the kill, because a corpse stops taking turns.
            local c = Combat.new(arena(9, 9),
                { unit(swordsman(), 5, 4), unit(swordsman(), 5, 7) },
                { unit("character_bandit", 5, 5) })
            local healthy, dying, bandit = c.units[1], c.units[2], c.units[3]
            setHp(dying, 1)

            local act = AI.plan(c, bandit)
            assert(act.item, "the bandit acts")
            assert(act.tx == dying.x and act.ty == dying.y,
                "it walks past the healthy knight to finish the dying one")
            assert(act.tx ~= healthy.x or act.ty ~= healthy.y, "not the adjacent healthy knight")
        end,
    },
    {
        name = "an AoE is not aimed so that it catches the caster's own allies",
        fn = function()
            -- Fireball's blast is a 3x3. Aimed at the lone knight it hits one body; aimed at the
            -- knight standing in the middle of the bandit's own friends it would hit four. Both
            -- knights are in range, so only the friendly-fire term separates them.
            local mage = caster("ability_fireball")
            local c = Combat.new(arena(11, 11),
                { unit(swordsman(), 6, 3), unit(swordsman(), 6, 8) },
                {
                    unit(mage, 6, 6),
                    unit("character_bandit", 5, 8), unit("character_bandit", 7, 8),
                    unit("character_bandit", 6, 9),
                })
            local lone, huddled, caster = c.units[1], c.units[2], c.units[3]

            local act = AI.plan(c, caster)
            assert(act.item, "the mage casts")
            if act.item.id == "ability_fireball" then
                assert(not (act.tx == huddled.x and act.ty == huddled.y),
                    "it does not centre the blast on its own three friends")
                assert(act.tx == lone.x and act.ty == lone.y, "it takes the clean target instead")
            end
        end,
    },
    {
        name = "an action must accomplish something, but need not be a bargain",
        fn = function()
            -- A sword costs stamina and a parrying target answers it, so the NET score of an
            -- ordinary attack is routinely negative. A unit that refused those would never fight.
            local c = Combat.new(arena(8, 8),
                { unit(swordsman(), 4, 4) }, { unit("character_bandit", 4, 5) })
            local act = AI.plan(c, c.units[2])
            assert(act.item and not act.move, "it swings anyway, from where it stands")

            -- ...but a heal aimed at an ally already at full health accomplishes nothing, and is
            -- correctly passed over.
            local full = Combat.new(arena(10, 10),
                { unit(swordsman(), 1, 1) },
                { unit(caster("ability_heal", "support"), 8, 8), unit("character_bandit", 8, 7) })
            local plan = AI.plan(full, full.units[2])
            assert(not (plan.item and plan.item.id == "ability_heal"),
                "nobody is hurt, so the heal is not cast")
        end,
    },

    {
        name = "the weapon that actually lands harder is the one drawn, fists included",
        fn = function()
            -- The bare fists are appended to every unit's option list and cost nothing, so a cost
            -- term priced too dearly would quietly talk the whole roster into punching. Watched for
            -- here because it is invisible in play until you read the combat log.
            local c = Combat.new(arena(8, 8),
                { unit("character_bandit", 4, 4) }, { unit("character_bandit", 4, 5) })
            local act = AI.plan(c, c.units[2])
            assert(act.item and act.item.id == "weapon_iron_sword",
                "against ordinary armor the sword wins on damage (chose: " .. tostring(act.item.id) .. ")")

            -- The converse, and the reason this is a judgement rather than a rule: against armor
            -- heavy enough to floor BOTH blows at the damage minimum, the sword buys exactly nothing
            -- for its stamina, and the free hand is the correct play. The old planner could not see
            -- this -- it took whichever ability came first in inventory order.
            local tank = swordsman()
            tank.stats.defense = 999
            local armored = Combat.new(arena(8, 8),
                { unit(tank, 4, 4) }, { unit("character_bandit", 4, 5) })
            local punch = AI.plan(armored, armored.units[2])
            assert(punch.item and punch.item.id == "weapon_unarmed",
                "no point spending stamina for the same 1 damage (chose: " .. tostring(punch.item.id) .. ")")
        end,
    },

    -- ---------------------------------------------------------------------
    -- Postures
    -- ---------------------------------------------------------------------
    {
        name = "holdGround never leaves its tile, but still strikes what comes into reach",
        fn = function()
            local sentry = Character.instantiate("character_bandit")
            sentry.archetype = "holdGround"
            local far = Combat.new(arena(10, 10),
                { unit(swordsman(), 9, 9) }, { unit(sentry, 2, 2) })
            local plan = AI.plan(far, far.units[2])
            assert(plan.wait and not plan.move, "with nothing in reach it holds its post")

            local sentry2 = Character.instantiate("character_bandit")
            sentry2.archetype = "holdGround"
            local near = Combat.new(arena(10, 10),
                { unit(swordsman(), 4, 4) }, { unit(sentry2, 4, 5) })
            local act = AI.plan(near, near.units[2])
            assert(act.item and not act.move, "it strikes what walks into its reach, without moving")
        end,
    },
    {
        name = "defensive holds until provoked, then commits",
        fn = function()
            local guard = Character.instantiate("character_bandit")
            guard.archetype = "defensive"
            local quiet = Combat.new(arena(12, 12),
                { unit(swordsman(), 11, 11) }, { unit(guard, 2, 2) })
            local plan = AI.plan(quiet, quiet.units[2])
            assert(plan.wait, "an unengaged defensive unit does not walk across the map to start a fight")

            -- Someone shot at it: it is in the fight now, whether it wanted to be or not.
            local guard2 = Character.instantiate("character_bandit")
            guard2.archetype = "defensive"
            local poked = Combat.new(arena(12, 12),
                { unit(swordsman(), 8, 8) }, { unit(guard2, 2, 2) })
            setHp(poked.units[2], hpOf(poked.units[2]) - 1)
            local act = AI.plan(poked, poked.units[2])
            assert(act.move, "a wounded defensive unit advances")
        end,
    },
    {
        name = "a support unit heals its wounded ally instead of throwing a punch",
        fn = function()
            -- Nothing in the pre-AI planner ever pointed a heal at anything: it only ever scanned for
            -- units on the OTHER side, so an enemy healer's whole kit was decoration.
            local c = Combat.new(arena(10, 10),
                { unit(swordsman(), 5, 5) },
                { unit(caster("ability_heal", "support"), 5, 6), unit("character_bandit", 5, 7) })
            local caster, hurt = c.units[2], c.units[3]
            setHp(hurt, 3)

            local act = AI.plan(c, caster)
            assert(act.item and act.item.id == "ability_heal", "it casts Heal, with a knight in its face")
            assert(act.tx == hurt.x and act.ty == hurt.y, "on the wounded ally")
        end,
    },
    {
        name = "a guard pursues inside its leash and goes home once past it",
        fn = function()
            local sentry = Character.instantiate("character_bandit")
            sentry.archetype = "guard"
            local c = Combat.new(arena(20, 20),
                { unit(swordsman(), 4, 12) }, { unit(sentry, 4, 4) })
            local guard = c.units[2]
            local leash = AI.POSTURES.guard.leash

            local plan = AI.plan(c, guard)
            assert(plan.move, "it gives chase")
            local d = math.abs(plan.move.x - guard.anchorX) + math.abs(plan.move.y - guard.anchorY)
            assert(d <= leash, "but never steps outside its leash: " .. d .. " > " .. leash)

            -- Dragged off its post (a knockback, a charm that wore off): it walks back.
            guard.x, guard.y = 4, 16
            local home = AI.plan(c, guard)
            assert(home.move, "off the leash, it returns")
            local after = math.abs(home.move.x - guard.anchorX) + math.abs(home.move.y - guard.anchorY)
            assert(after < math.abs(guard.x - guard.anchorX) + math.abs(guard.y - guard.anchorY),
                "and the step it takes is homeward")
        end,
    },
    {
        name = "an objective posture hunts the unit the objective names, not the nearest body",
        fn = function()
            -- An escort map: the caravan master is what the raid is actually FOR. The old planner
            -- never read combat.objective at all, so a `protect` map played exactly like a killAll.
            local escortee = swordsman()
            escortee.id = "character_caravan_master"
            local raider = Character.instantiate("character_bandit")
            raider.archetype = "objective"

            local c = Combat.new(arena(14, 14),
                { unit(swordsman(), 7, 6), unit(escortee, 7, 11) },
                { unit(raider, 7, 4) })
            c.objective = { type = "killAll", protect = "character_caravan_master" }
            local charge = c.units[2]

            local plan = AI.plan(c, c.units[3])
            assert(plan.move, "the raider advances")
            local before = math.abs(7 - charge.x) + math.abs(4 - charge.y)
            local after = math.abs(plan.move.x - charge.x) + math.abs(plan.move.y - charge.y)
            assert(after < before, "and it closes on the charge, walking past the nearer escort")
        end,
    },

    -- ---------------------------------------------------------------------
    -- Rules as data: items, blueprints, and the merge
    -- ---------------------------------------------------------------------
    {
        name = "priority is authored as a name, and reads back as one",
        fn = function()
            -- A bare integer says nothing about what a rule is FOR, and two authors picking numbers
            -- independently cannot agree. The names are the interface; the numbers are an
            -- implementation detail of the sort.
            assert(AI.priorityOf({ priority = "emergency" }) < AI.priorityOf({ priority = "urgent" }),
                "an emergency outranks something merely urgent")
            assert(AI.priorityOf({ priority = "urgent" }) < AI.priorityOf({ priority = "normal" }),
                "urgent outranks the ordinary business of the turn")
            assert(AI.priorityOf({ priority = "normal" }) < AI.priorityOf({ priority = "fallback" }),
                "and anything outranks the floor")

            -- Posture defaults sit at `normal`, which is what makes that band mean what it says.
            assert(AI.priorityOf({}) == AI.PRIORITY.normal, "an unnamed rule is normal")

            -- A raw number still works, for the rule that must slot between two bands...
            assert(AI.priorityOf({ priority = 25 }) == 25, "a number is taken at face value")
            -- ...and still explains itself by the band it landed in rather than as a bare integer.
            assert(AI.priorityName({ priority = 25 }) == "urgent", "25 reads back as urgent")
            assert(AI.priorityName({ priority = "high" }) == "high", "a name reads back as itself")

            assert(not pcall(AI.priorityOf, { priority = "verygreat" }), "a typo'd band raises")
            assert(AI.describeRule({ priority = "urgent", act = "support" }):find("urgent"),
                "the band leads the rendered sentence")
        end,
    },
    {
        name = "behavior travels with the item: an NPC handed Heal starts healing",
        fn = function()
            -- The point of the whole feature. The bandit blueprint says nothing about healing and has
            -- no archetype; the rule arrives in its grid attached to the spell.
            local medic = caster("ability_heal") -- note: no archetype
            local c = Combat.new(arena(10, 10),
                { unit(swordsman(), 5, 5) },
                { unit(medic, 5, 6), unit("character_bandit", 5, 7) })
            local hurt = c.units[3]
            setHp(hurt, 3)

            local act = AI.plan(c, c.units[2])
            assert(act.item and act.item.id == "ability_heal",
                "the spell brought its own tactics (chose: " .. tostring(act.item and act.item.id) .. ")")
            assert(act.tx == hurt.x and act.ty == hurt.y, "aimed at the wounded ally")
        end,
    },
    {
        name = "an item's rule fires only for that item, never for whatever else is to hand",
        fn = function()
            -- "When an ally is hurt, cast THIS" must not be satisfiable by drawing a sword. Both are
            -- in the grid and the sword would happily reach the knight.
            local medic = caster("ability_heal")
            medic.inventory[2] = Item.instantiate("weapon_iron_sword")
            local c = Combat.new(arena(10, 10),
                { unit(swordsman(), 5, 5) },
                { unit(medic, 5, 6), unit("character_bandit", 5, 7) })
            setHp(c.units[3], 3)
            local act = AI.plan(c, c.units[2])
            assert(act.item.id == "ability_heal", "the heal rule reached for the heal")
        end,
    },
    {
        name = "an item rule whose item is blocked is skipped, not fired with something else",
        fn = function()
            -- Same board, but the caster cannot pay for the spell. The rule must fall through to the
            -- posture defaults rather than firing the sword under the heal rule's name.
            local medic = caster("ability_heal")
            medic.inventory[2] = Item.instantiate("weapon_iron_sword")
            medic.stats.mana = { max = 40, current = 0 }
            local c = Combat.new(arena(10, 10),
                { unit(swordsman(), 5, 5) },
                { unit(medic, 5, 6), unit("character_bandit", 5, 7) })
            setHp(c.units[3], 3)
            local act = AI.plan(c, c.units[2])
            assert(not (act.item and act.item.id == "ability_heal"), "the unaffordable spell is not cast")
            assert(act.item or act.move or act.wait, "and the turn still resolves to something")
        end,
    },
    {
        name = "a player rule can name an item by id, and only that item is used",
        fn = function()
            -- The thing a player actually wants to write: "when an ally is hurt, cast HEAL" -- not
            -- "cast something". The sword is in the grid too and would happily reach the knight.
            local medic = caster("ability_heal")
            medic.inventory[2] = Item.instantiate("weapon_iron_sword")
            medic.aiRules = { {
                priority = "urgent", act = "support", item = "ability_heal", targetPref = "lowest_hp",
                when = { subject = "any_ally", test = "hp_pct_below", value = 0.5 },
            } }
            local c = Combat.new(arena(10, 10),
                { unit(swordsman(), 5, 5) },
                { unit(medic, 5, 6), unit("character_bandit", 5, 7) })
            setHp(c.units[3], 3)

            local act = AI.plan(c, c.units[2])
            assert(act.item and act.item.id == "ability_heal",
                "the id resolved to the spell in the grid (chose: " .. tostring(act.item and act.item.id) .. ")")
            assert(act.item == medic.inventory[1], "and to THIS character's copy of it")
        end,
    },
    {
        name = "a rule naming an item the character no longer carries goes dormant, not wide",
        fn = function()
            -- The failure to avoid: losing the item makes "cast Heal" quietly become "cast anything",
            -- so a rule the player wrote for one purpose starts doing something else entirely.
            local char = Character.instantiate("character_bandit")
            char.inventory[2] = Item.instantiate("weapon_iron_sword")
            char.aiRules = { {
                priority = "urgent", act = "attack", item = "ability_fireball",
                when = { subject = "any_foe", test = "exists" },
            } }
            local c = Combat.new(arena(8, 8),
                { unit(swordsman(), 4, 4) }, { unit(char, 4, 5) })

            local merged = AI.rulesFor(c.units[2])
            assert(merged[1].missing, "the merge flags the rule as naming something absent")
            assert(merged[1].item == nil, "and resolves no item for it")

            local act = AI.plan(c, c.units[2])
            assert(not (act.item and act.item.id == "ability_fireball"), "it cannot cast what it lacks")
            -- ...and the turn still resolves, via a later rule rather than via the dead one widening.
            assert(act.item or act.move or act.wait, "the turn still resolves")
        end,
    },
    {
        name = "resolveItem finds a grid item, the bare fists, and nothing else",
        fn = function()
            local char = Character.instantiate("character_bandit")
            char.inventory[1] = Item.instantiate("weapon_iron_sword")
            assert(AI.resolveItem(char, "weapon_iron_sword") == char.inventory[1], "finds a grid item")
            assert(AI.resolveItem(char, char.unarmed.id) == char.unarmed,
                "finds the hidden unarmed weapon, which is never in the grid")
            assert(AI.resolveItem(char, "ability_fireball") == nil, "and nothing for an item not held")
            assert(AI.resolveItem(char, nil) == nil, "nil in, nil out")

            -- An item block hands over the live table rather than an id; both forms must resolve.
            local live = char.inventory[1]
            assert(AI.resolveItem(char, live) == live, "a live item passes through untouched")
        end,
    },
    {
        name = "a pinned item is named in the rendered sentence",
        fn = function()
            local text = AI.describeRule({ act = "cast", item = "ability_heal", targetPref = "lowest_hp" })
            assert(text:find("Heal"), "the item's display name appears: " .. text)
            local anyText = AI.describeRule({ act = "attack", targetPref = "nearest" })
            assert(not anyText:find("Heal"), "and an unpinned rule names no item")
        end,
    },
    {
        name = "a blueprint's own rules back an untouched unit, below its item rules",
        fn = function()
            -- No player overlay: the character is still on the list the blueprint authored, at the
            -- character rank -- below the item's own rule, above the posture floor.
            local char = caster("ability_heal")       -- Heal's block is `urgent`
            char.ai = { { priority = "normal", act = "attack" } }
            assert(char.aiRules == nil, "the unit was never edited")
            local c = Combat.new(arena(8, 8),
                { unit(swordsman(), 4, 4) }, { unit(char, 4, 6) })
            local merged = AI.rulesFor(c.units[2])

            assert(merged[1].item and merged[1].item.id == "ability_heal",
                "the item rule (urgent) leads")
            local sawChar = false
            for _, e in ipairs(merged) do if e.rule == char.ai[1] then sawChar = true end end
            assert(sawChar, "the blueprint's own rule is used when there is no player overlay")
        end,
    },
    {
        name = "the player's overlay replaces the blueprint's rules, and still layers over item and posture",
        fn = function()
            -- The overlay was seeded FROM the blueprint (ui/tactics_editor.lua), so it already holds
            -- whatever the blueprint authored plus the player's edits. Collecting `char.ai` as well
            -- would double every untouched rule, so once the overlay exists the blueprint list drops.
            local char = caster("ability_heal")
            char.ai = { { priority = "high", act = "attack" } }          -- the blueprint's own rule
            char.aiRules = { { priority = "high", act = "wait" } }       -- the player took the list over
            local c = Combat.new(arena(8, 8),
                { unit(swordsman(), 4, 4) }, { unit(char, 4, 6) })
            local merged = AI.rulesFor(c.units[2])

            -- Heal's own block is `urgent`, which outranks `high`, so it leads whatever the source.
            assert(merged[1].item and merged[1].item.id == "ability_heal",
                "priority is the primary sort, whatever the source")
            -- The player's `high` rule is present at the player rank...
            assert(merged[2].rule.act == "wait", "the player's rule leads the `high` band")
            -- ...and the blueprint's own `attack` rule is GONE, replaced rather than stacked.
            for _, e in ipairs(merged) do
                assert(e.rule ~= char.ai[1], "the blueprint's own rule does not also appear")
            end
            -- Posture defaults are the floor, so they land last.
            assert(#merged >= 3 and merged[#merged].rule ~= nil, "posture defaults still backstop the list")
        end,
    },
    {
        name = "two wielders of the same item each bind their own copy of it",
        fn = function()
            -- A merge that resolved `rule.item` by writing the item back into the rule table would
            -- bind the first wielder's spell to the second wielder's list. It would work perfectly
            -- until a battle contained two healers, which is exactly the kind of bug that ships.
            --
            -- Item.instantiate deep-copies the blueprint, so each instance already owns its `ai`
            -- table and there is no shared state left to corrupt -- but the merge must not rely on
            -- that, and this pins the property the merge is actually responsible for.
            local a = caster("ability_heal")
            local b = caster("ability_heal")
            local c = Combat.new(arena(10, 10),
                { unit(swordsman(), 1, 1) }, { unit(a, 8, 8), unit(b, 8, 7) })
            local ra, rb = AI.rulesFor(c.units[2]), AI.rulesFor(c.units[3])

            assert(ra[1].item and rb[1].item, "both resolved the heal rule to an item")
            assert(ra[1].item ~= rb[1].item, "each unit's rule points at its OWN copy of the spell")
            assert(ra[1].item == a.inventory[1], "specifically, the one in its own grid")
            assert(rb[1].item == b.inventory[1], "and likewise for the other")
            assert(ra[1].rule.priority == rb[1].rule.priority, "reading the same authored rule")
        end,
    },
    {
        name = "every authored ai block in data/ names a vocabulary that exists",
        fn = function()
            -- A misspelled subject raises at evaluation time, which means it raises mid-battle. This
            -- walks every item shipped in the game so it raises here instead.
            local checked = 0
            for id, def in pairs(Item.defs) do
                local rules = def.activeAbility and def.activeAbility.ai
                if rules then
                    if rules.act or rules.when or rules.whenFn then rules = { rules } end
                    for _, rule in ipairs(rules) do
                        checked = checked + 1
                        if rule.when then
                            assert(AI.SUBJECTS[rule.when.subject],
                                id .. " names an unknown subject: " .. tostring(rule.when.subject))
                            assert(AI.TESTS[rule.when.test],
                                id .. " names an unknown test: " .. tostring(rule.when.test))
                        end
                        assert(AI.ACTIONS[rule.act or "attack"],
                            id .. " names an unknown act: " .. tostring(rule.act))
                        assert(pcall(AI.priorityOf, rule),
                            id .. " names an unknown priority: " .. tostring(rule.priority))
                    end
                end
            end
            assert(checked > 0, "the sweep actually found some authored rules")
        end,
    },
    {
        name = "every character's authored ai block names a vocabulary that exists",
        fn = function()
            -- The blueprint half of the same sweep: a character `ai` rule with a typo'd subject raises
            -- the first time that body takes an AI turn, which is mid-battle. Walk every shipped
            -- blueprint so it raises here instead. (docs/adding-content.md promises this sweep.)
            local checked = 0
            for id, def in pairs(Character.defs) do
                local rules = def.ai
                if rules then
                    if rules.act or rules.when or rules.whenFn then rules = { rules } end
                    for _, rule in ipairs(rules) do
                        checked = checked + 1
                        if rule.when then
                            assert(AI.SUBJECTS[rule.when.subject],
                                id .. " names an unknown subject: " .. tostring(rule.when.subject))
                            assert(AI.TESTS[rule.when.test],
                                id .. " names an unknown test: " .. tostring(rule.when.test))
                        end
                        assert(AI.ACTIONS[rule.act or "attack"],
                            id .. " names an unknown act: " .. tostring(rule.act))
                        assert(pcall(AI.priorityOf, rule),
                            id .. " names an unknown priority: " .. tostring(rule.priority))
                    end
                end
            end
            assert(checked > 0, "the sweep actually found some authored character rules")
        end,
    },
    {
        name = "every archetype named in data/characters is a real posture",
        fn = function()
            local seen = 0
            for id, def in pairs(Character.defs) do
                if def.archetype then
                    seen = seen + 1
                    assert(AI.POSTURES[def.archetype],
                        id .. " names an unknown archetype: " .. tostring(def.archetype))
                end
            end
            assert(seen > 0, "the sweep actually found some archetypes")
        end,
    },
    {
        name = "an archetype survives instantiation onto the runtime character",
        fn = function()
            -- Character.instantiate copies field by field, so a new blueprint field that isn't named
            -- there reads back nil at runtime and fails silently (docs/adding-content.md).
            local archer = Character.instantiate("character_archer")
            assert(archer.archetype == "skirmish", "the blueprint's archetype reached the instance")
            local plain = Character.instantiate("character_bandit")
            assert(plain.archetype == nil, "and a character that names none stays nil")
            assert(select(2, AI.posture({ char = plain })) == "aggressive",
                "...which resolves to the default posture")
        end,
    },

    {
        -- The regression this exists for: EXPOSURE is a COUNT of enemies who could reach the tile, so
        -- it is a cliff. Once one foe is quick enough to threaten the whole board, every candidate
        -- carries the same exposure, the term stops discriminating, and a kiter's positional judgement
        -- silently collapses -- it walked into arm's reach and punched with a bow in its hands.
        -- STANDOFF is the slope underneath the cliff (AI.riskScore).
        name = "a kiter with nowhere safe to stand still shoots rather than closing",
        fn = function()
            -- An 8x1 corridor, so there is no flank and no escape: the swordsman's move-and-strike band
            -- covers every tile the archer could stand on. Exposure is therefore identical everywhere
            -- and cannot be what decides this.
            local bow = Character.instantiate("character_archer")
            for i = 1, Character.MAX_INVENTORY do bow.inventory[i] = nil end
            bow.inventory[1] = Item.instantiate("weapon_iron_bow")

            -- The knight is placed at exactly the bow's range, so SHOOTING FROM WHERE IT ALREADY
            -- STANDS is on the table -- which is what makes standing still a real choice the scorer
            -- has to get right, rather than a walk it was going to make anyway.
            --
            -- A WHOLE knight, chainmail included, rather than this file's stripped `swordsman()`.
            -- That is load-bearing: chainmail resists `pierce` harder than it resists a bare fist, so
            -- against an armoured target the archer's punch genuinely out-damages its own bow, and
            -- closing is the choice the outcome term prefers. Strip the mail and the bow wins on
            -- damage alone -- the positional judgement is never consulted and the test proves nothing.
            local c = Combat.new(arena(8, 1), { unit("character_knight", 4, 1) }, { unit(bow, 1, 1) })
            local knight, archer = c.units[1], c.units[2]

            local threat = select(2, Combat.threatMap(c, "enemy", archer))
            local covered = 0
            for x = 1, 8 do if threat[x .. ",1"] then covered = covered + 1 end end
            assert(covered >= 7, "the knight threatens essentially the whole corridor, got " .. covered)
            assert(Combat.moveBudget(knight) >= 3, "and it is the post-rebalance pace that does it")

            local plan = Combat.planEnemyAction(c, archer)
            assert(plan and plan.item, "the archer acts")
            assert(plan.item.name == Item.defs.weapon_iron_bow.name,
                "it shoots rather than punching, got " .. tostring(plan.item.name))
            -- It holds the tile it was already on. Without STANDOFF every tile scores the same
            -- exposure and the planner walks it into the knight's face to punch instead.
            assert(not plan.move, "and it holds its ground to do it")
        end,
    },

    -- ---------------------------------------------------------------------
    -- Preemption and the shared threat map
    -- ---------------------------------------------------------------------
    {
        name = "every plan carries a reason naming what decided it",
        fn = function()
            -- Not decoration: a priority system whose choices can't be read back is one nobody can
            -- author against.
            local c = Combat.new(arena(8, 8), { unit(swordsman(), 4, 4) }, { unit("character_bandit", 4, 5) })
            local act = AI.plan(c, c.units[2])
            assert(type(act.reason) == "string" and #act.reason > 0, "an action explains itself")
            assert(AI.explain(act) == act.reason, "explain surfaces it")

            local idle = Combat.new(arena(8, 8), {}, { unit("character_bandit", 1, 1) })
            local waiting = AI.plan(idle, idle.units[1])
            assert(waiting.wait and type(waiting.reason) == "string", "so does a wait")
        end,
    },
    {
        name = "threatMap unions the reach of every hostile, and skips the asking unit",
        fn = function()
            local c = Combat.new(arena(9, 9),
                { unit(swordsman(), 2, 2) }, { unit("character_bandit", 8, 8) })
            local knight, bandit = c.units[1], c.units[2]

            -- What the party is threatened by: the bandit's walk-and-strike band.
            local cells, sources = Combat.threatMap(c, "party")
            assert(next(cells), "the bandit threatens something")
            for k, list in pairs(sources) do
                for _, s in ipairs(list) do
                    assert(s.x == bandit.x and s.y == bandit.y, "every source is the bandit, at " .. k)
                end
            end
            assert(not cells[knight.x .. "," .. knight.y],
                "the knight is far out of the bandit's reach this turn")

            -- ...and a unit asking about its own footing does not count itself as a danger to it.
            local mine = Combat.threatMap(c, "enemy", bandit)
            local theirs = Combat.threatMap(c, "enemy")
            assert(next(theirs), "the knight threatens tiles")
            local skipped = true
            for k in pairs(mine) do if not theirs[k] then skipped = false end end
            assert(skipped, "skipping a unit never ADDS threatened tiles")
        end,
    },
}
