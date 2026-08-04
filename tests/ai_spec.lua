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
local Wall = require("models.wall")
local Prop = require("models.prop")
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
    local char = Character.instantiate("character_rowan")
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
        name = "a defensive unit engages on hostile reach, not on its own potion",
        fn = function()
            -- `defensive` asks whether anything it carries has a target from where it stands. An
            -- ally-targeted ability counts its own caster as a target (Combat.abilityTargets), so
            -- reading the whole kit meant a guard activated on turn 1 because it could drink its own
            -- potion -- and the posture never actually held anything on any map with a healer's kit.
            local function guard(withPotion)
                local char = Character.instantiate("character_bandit")
                char.archetype = "defensive"
                if withPotion then char.inventory[2] = Item.instantiate("consumable_healing_potion") end
                return char
            end
            local dry = Combat.new(arena(12, 12), { unit(swordsman(), 11, 11) }, { unit(guard(false), 2, 2) })
            assert(AI.plan(dry, dry.units[2]).wait, "nothing in reach: it holds")

            local wet = Combat.new(arena(12, 12), { unit(swordsman(), 11, 11) }, { unit(guard(true), 2, 2) })
            assert(AI.plan(wet, wet.units[2]).wait,
                "carrying a potion is not a reason to start walking at someone")
        end,
    },
    {
        name = "a defensive unit takes the post the objective names, and then holds it",
        fn = function()
            -- `defensive` means "assigned to something", and only the objective knows what. On a
            -- control map that is the node: the posture has to WALK to ground it was never spawned
            -- on -- taking up a station is not joining a fight -- and then stop there.
            local node = { { x = 5, y = 5 }, { x = 6, y = 5 }, { x = 5, y = 6 }, { x = 6, y = 6 } }
            local objective = { type = "control", maxTicks = 240, nodes = { node } }
            local function board(gx, gy)
                local g = Character.instantiate("character_bandit")
                g.archetype = "defensive"
                return Combat.new(arena(10, 10, objective), { unit(swordsman(), 10, 10) }, { unit(g, gx, gy) })
            end

            local far = board(1, 1)
            local march = AI.plan(far, far.units[2])
            assert(march.move, "an unmanned post moves a defender that has not engaged")
            assert(Combat.cellGap(march.move.x, march.move.y, node[1]) < Combat.cellGap(1, 1, node[1]),
                "and it moves TOWARD the node")

            local held = board(5, 5)
            assert(AI.plan(held, held.units[2]).wait, "standing on the node, holding is the move")
        end,
    },
    {
        name = "a posted defender will not be baited off its post",
        fn = function()
            -- The leash is what makes the posture mean anything: a unit free to enumerate every
            -- reachable tile walks four squares off the node to land a hit, banks nothing that tick,
            -- and hands the point to whoever stayed.
            local node = { { x = 5, y = 5 }, { x = 6, y = 5 }, { x = 5, y = 6 }, { x = 6, y = 6 } }
            local objective = { type = "control", maxTicks = 240, nodes = { node } }
            local g = Character.instantiate("character_bandit")
            g.archetype = "defensive"
            local c = Combat.new(arena(10, 10, objective),
                { unit(swordsman(), 10, 10) }, { unit(g, 5, 5) })
            setHp(c.units[2], hpOf(c.units[2]) - 1) -- provoked, and the bait is across the board

            local plan = AI.plan(c, c.units[2])
            assert(plan.wait, "a provoked defender still does not abandon the ground it is holding")

            -- ...but it fights whatever comes to the post.
            c.units[1].x, c.units[1].y = 6, 6
            local act = AI.plan(c, c.units[2])
            assert(act.item, "a foe standing on the node is struck, not watched")
        end,
    },
    {
        name = "a defensive unit posted to a BODY rings the body, not the map",
        fn = function()
            -- An assassination's guards are there for the boss. The post is the same lookup as
            -- AI.objectiveUnit with the side test flipped: the named body on MY side.
            local boss = Character.instantiate("character_mage")
            local g = Character.instantiate("character_bandit")
            g.archetype = "defensive"
            local c = Combat.new(arena(12, 12, { type = "assassinate", target = boss.id }),
                { unit(swordsman(), 12, 12) }, { unit(g, 1, 1), unit(boss, 9, 3) })
            local guard, mark = c.units[2], c.units[3]

            local post = AI.post(c, guard)
            assert(post and post.what == mark.char.name, "the guard is posted to the boss it shares a side with")
            local plan = AI.plan(c, guard)
            assert(plan.move, "and walks to it before the party ever arrives")
            assert(Combat.cellGap(plan.move.x, plan.move.y, mark) < Combat.cellGap(1, 1, mark),
                "closing on the charge, not on the enemy across the board")
        end,
    },
    {
        name = "a bodyguard picks its charge off the board, and the player's body outranks everything",
        fn = function()
            -- Rowan's blueprint asks for the ranking, not an id. On a killAll -- which names nothing
            -- to defend, and is exactly the case that used to leave her an ordinary aggressor -- the
            -- avatar is what the side cannot afford to lose, so that is the post.
            local rowan = Character.instantiate("character_rowan")
            assert(rowan.archetype == "defensive" and rowan.guards == AI.GUARD_PRIORITY,
                "the blueprint's posture and standing assignment survive instantiation")

            local c = Combat.new(arena(14, 14),
                { unit(rowan, 1, 1), unit("character_avatar", 9, 9), unit("character_priest", 2, 9) },
                { unit("character_bandit", 14, 14) })
            local guard, avatar = c.units[1], c.units[2]

            local post = AI.post(c, guard)
            assert(post and post.what == avatar.char.name, "posted to the player, over the healer")
            local plan = AI.plan(c, guard)
            assert(plan.move, "and she walks to the body rather than holding where she spawned")
            assert(Combat.cellGap(plan.move.x, plan.move.y, avatar) < Combat.cellGap(1, 1, avatar),
                "closing on the player, not on the bandit across the board")

            -- The map naming a charge is heard, but does not shout down the avatar: an escort's
            -- witness is what the REST of the party is for.
            c.objective = { type = "killAll", protect = "character_priest" }
            assert(AI.post(c, guard).what == avatar.char.name, "the player still outranks the map")
        end,
    },
    {
        name = "with no player on the board the ranking falls to the healer, then to the fragile",
        fn = function()
            -- The point of ranking rather than naming: the oath has to mean something in the fights
            -- the avatar is not standing in.
            local function rowan(x, y) return unit("character_rowan", x, y) end
            local healer = Combat.new(arena(14, 14),
                { rowan(1, 1), unit("character_priest", 9, 9), unit(swordsman(), 3, 3) },
                { unit("character_bandit", 14, 14) })
            assert(AI.post(healer, healer.units[1]).what == healer.units[2].char.name,
                "the body carrying the heals is what the side cannot replace")

            -- A hitter is never a charge, however valuable: guarding one would just be two units
            -- standing where one was. A side of nothing but hitters names nobody.
            local hitters = Combat.new(arena(14, 14),
                { rowan(1, 1), unit(swordsman(), 3, 3) },
                { unit("character_bandit", 14, 14) })
            assert(AI.charge(hitters, hitters.units[1]) == nil, "a swordsman guards itself")
            assert(AI.plan(hitters, hitters.units[1]).wait, "so she is a plain defender, holding")
        end,
    },
    {
        name = "the charge ranking is stable as the fight moves",
        fn = function()
            -- A guard that re-picks its charge on current hp or distance oscillates between two posts
            -- and defends neither. Every term is a fact about the BODY, not about the moment.
            local c = Combat.new(arena(14, 14),
                { unit("character_rowan", 5, 5), unit("character_avatar", 6, 5),
                  unit("character_priest", 7, 5) },
                { unit("character_bandit", 14, 14) })
            local guard, avatar, priest = c.units[1], c.units[2], c.units[3]

            assert(AI.charge(c, guard) == avatar, "the player, to begin with")
            setHp(avatar, 1)                       -- bleeding badly
            setHp(priest, 1)                       -- so is the healer
            priest.x, priest.y = 5, 6              -- and the healer is now the nearer body
            assert(AI.charge(c, guard) == avatar, "and the player still, after all of that")
        end,
    },
    {
        name = "a bodyguard engages on the ring being contested, and holds it once manned",
        fn = function()
            local c = Combat.new(arena(14, 14),
                { unit("character_rowan", 9, 8), unit("character_avatar", 9, 9) },
                { unit("character_bandit", 14, 1) })
            local guard = c.units[1]
            assert(AI.plan(c, guard).wait, "at her post with the fight elsewhere, holding IS the move")

            -- Something walks up to the player. A contested post is the fight starting, whether or
            -- not it has come within her own reach yet.
            c.units[3].x, c.units[3].y = 10, 10
            local act = AI.plan(c, guard)
            assert(act.item, "she steps in rather than waiting to be hit first")
        end,
    },
    {
        name = "with nobody worth guarding, defensive is the old hold-until-provoked rule",
        fn = function()
            -- killAll names no ground and no body, and a lone bandit's side has nobody the ranking
            -- would point at either -- so there is no post, and the quiet-corner maps every authored
            -- killAll is built on keep playing exactly as they did.
            local g = Character.instantiate("character_bandit")
            g.archetype = "defensive"
            local c = Combat.new(arena(12, 12), { unit(swordsman(), 11, 11) }, { unit(g, 2, 2) })
            assert(AI.post(c, c.units[2]) == nil, "nothing named, and nobody to rank")
            assert(AI.plan(c, c.units[2]).wait, "so it holds, exactly as it always has")
        end,
    },
    {
        name = "on a map that names nothing, a defender falls back to guarding its own side's charge",
        fn = function()
            -- Every `defensive` unit gets here, not just the ones whose blueprint asks: a killAll is
            -- most maps, and a wall that stands where it spawned while its healer is cut down two
            -- tiles away is not defending anything. No `guards` field anywhere in this fixture.
            local g = Character.instantiate("character_bandit")
            g.archetype = "defensive"
            local c = Combat.new(arena(14, 14),
                { unit(swordsman(), 14, 14) },
                { unit(g, 2, 2), unit(caster("ability_heal"), 9, 9) })
            local wall, medic = c.units[2], c.units[3]

            local post = AI.post(c, wall)
            assert(post and post.what == medic.char.name, "the healer is what this squad cannot replace")
            local plan = AI.plan(c, wall)
            assert(plan.move and Combat.cellGap(plan.move.x, plan.move.y, medic) < Combat.cellGap(2, 2, medic),
                "and the wall walks to it, rather than waiting to be found")
        end,
    },
    {
        name = "the ground the map is scored on still outranks the ranking",
        fn = function()
            -- A defender that rings its healer while the other side banks the node has lost the
            -- battle it was winning. Only a blueprint that asks for the ranking outright (`guards`)
            -- gets to put a body above the objective's ground.
            local node = { { x = 5, y = 5 }, { x = 6, y = 5 } }
            local objective = { type = "control", maxTicks = 240, nodes = { node } }
            local g = Character.instantiate("character_bandit")
            g.archetype = "defensive"
            local c = Combat.new(arena(12, 12, objective),
                { unit(swordsman(), 12, 12) },
                { unit(g, 1, 1), unit(caster("ability_heal"), 9, 9) })
            assert(AI.post(c, c.units[2]).what == "the objective", "the node, not the medic")

            -- ...and the bodyguard form is exactly the opposite reading.
            c.units[2].char.guards = AI.GUARD_PRIORITY
            assert(AI.post(c, c.units[2]).what == c.units[3].char.name,
                "a sworn shield lets the node be somebody else's job")
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
        name = "a foe walled off by terrain rounds the wall instead of standing at it",
        fn = function()
            -- The stall this exists to prevent: the approach used to rank stand tiles by the straight
            -- line to its goal, and every tile that rounds a corner is FARTHER in a straight line than
            -- the one already stood on. So the unit marched up to the masonry, found nothing that got
            -- it "closer", and held -- every turn, for the rest of the battle.
            --
            -- A five-wide slab across the middle of a nine-wide board, open down both flanks.
            local map = arena(9, 9)
            for x = 3, 7 do
                for y = 4, 5 do
                    map.tiles[y][x] = { type = "obstacle", moveCost = math.huge,
                                        walkable = false, sightCost = math.huge }
                end
            end
            local c = Combat.new(map, { unit(swordsman(), 5, 9) }, { unit("character_bandit", 5, 1) })
            local hero, bandit = c.units[1], c.units[2]

            -- Walk the plan out turn by turn: the stall was never visible in one step (the first move
            -- toward the wall looks fine), only in the fact that the second one never came.
            local moves, struck = 0, false
            for _ = 1, 10 do
                local plan = AI.plan(c, bandit)
                assert(plan.move or plan.item, "the bandit keeps closing rather than holding at the wall")
                if plan.move then
                    bandit.x, bandit.y = plan.move.x, plan.move.y
                    moves = moves + 1
                end
                if plan.item then struck = true; break end -- in reach: the approach is done
            end
            assert(struck and moves > 0, "it arrives and swings, in a finite number of walks")
            assert(Combat.cellGap(bandit.x, bandit.y, hero) <= 1,
                "from a tile adjacent to the party, having taken the long way around the slab")
        end,
    },
    {
        name = "a foe walled in by a conjured barrier breaks the one panel that opens its road",
        fn = function()
            -- The corner pocket: solid terrain east of the bandit, a conjured wall south of it. Nothing
            -- to walk to, nobody in reach -- the old planner declared "nothing worth doing" and did it
            -- again every turn for the rest of the fight, which is what made Summon Wall a stalemate
            -- button rather than a delay.
            local map = arena(7, 7)
            map.tiles[1][2] = { type = "obstacle", moveCost = math.huge, walkable = false, sightCost = math.huge }
            local raider = swordsman()
            local c = Combat.new(map, { unit(swordsman(), 5, 5) }, { unit(raider, 1, 1) })
            local bandit = c.units[2]
            local wall = Wall.place(c, 1, 2, "illusory_wall")
            assert(wall, "the barrier stands, sealing the pocket")

            local plan = AI.plan(c, bandit)
            assert(plan.strike, "it takes a swing at the way out instead of holding: " .. AI.explain(plan))
            assert(plan.tx == 1 and plan.ty == 2, "at the wall, the only thing between it and the party")
            assert(plan.item and plan.item.activeAbility, "with something it can actually hit for")

            -- And the plan RESOLVES: the descriptor the battle state executes is the object verb, not
            -- Combat.useItem, which has no notion of a target that isn't a body.
            local before = wall.health
            assert(Combat.strikeObject(c, bandit, plan.item, plan.tx, plan.ty), "the blow lands")
            assert(wall.health < before, "and the barrier is coming down: " .. before .. " -> " .. wall.health)
        end,
    },
    {
        name = "a barrier is broken when the detour costs more turns than the axework",
        fn = function()
            -- The trade the whole clearing pass exists to make, set up twice on the same board. A
            -- terrain wall spans the map at y=8 with the party on the far side; the ONE gap in it is
            -- plugged by a conjured barrier, and the only other way round is the far edge.
            local function board(hole)
                local map = arena(15, 15)
                for x = 1, 14 do
                    map.tiles[8][x] = { type = "obstacle", moveCost = math.huge,
                                        walkable = false, sightCost = math.huge }
                end
                map.tiles[8][2] = { type = "ground", moveCost = 1, walkable = true, sightCost = 0 }
                -- A second gap, when the case wants the detour to be cheap.
                if hole then
                    map.tiles[8][hole] = { type = "ground", moveCost = 1, walkable = true, sightCost = 0 }
                end
                local c = Combat.new(map, { unit(swordsman(), 2, 9) }, { unit(swordsman(), 2, 7) })
                assert(Wall.place(c, 2, 8, "illusory_wall"), "the barrier plugs the gap")
                return c, c.units[2]
            end

            -- Thirteen tiles out to the map edge, across, and thirteen back -- against a couple of
            -- turns swinging at the thing standing in the doorway.
            local long, raider = board(nil)
            local plan = AI.plan(long, raider)
            assert(plan.strike and plan.tx == 2 and plan.ty == 8,
                "the long way round is not worth it, so it breaks through: " .. AI.explain(plan))

            -- Same barrier, same unit, one tile of detour: now walking is plainly cheaper, and a
            -- planner that broke it anyway would be demolishing scenery for its own sake.
            local short, walker = board(3)
            local walk = AI.plan(short, walker)
            assert(not walk.strike, "with a gap beside it, it walks: " .. AI.explain(walk))
            assert(walk.move, "and the walk is toward the party")
        end,
    },
    {
        name = "furniture that is not in the way is walked around, not demolished",
        fn = function()
            -- The other half of the judgement, and the one that keeps a cluttered board from turning
            -- into a demolition derby: a crate beside the bandit is breakable, in reach, and utterly
            -- beside the point, because the road to the party is open.
            local c = Combat.new(arena(9, 9), { unit(swordsman(), 5, 9) }, { unit(swordsman(), 5, 1) })
            local bandit = c.units[2]
            assert(Prop.place(c, 4, 1, "prop_crate"), "the crate stands beside it")

            local plan = AI.plan(c, bandit)
            assert(not plan.strike, "it ignores the crate: " .. AI.explain(plan))
            assert(plan.move, "and gets on with closing the distance")
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
        name = "priority is authored as a name, and orders the sources the player never sees",
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
            assert(AI.priorityOf({}) == AI.PRIORITY.normal, "an unnamed rule is normal")
            assert(AI.priorityOf({ priority = 25 }) == 25, "a number is taken at face value")
            assert(not pcall(AI.priorityOf, { priority = "verygreat" }), "a typo'd band raises")

            -- A blueprint rule CAN reach across a source boundary: this is the whole reason the band
            -- exists, and the case that has no other expression. `urgent` on the character's own list
            -- must beat an item's `high`, even though the item source ranks above the character one.
            local char = caster("ability_fireball") -- fireball's own block is `high`
            char.ai = { { priority = "urgent", act = "wait" } }
            local c = Combat.new(arena(8, 8),
                { unit(swordsman(), 4, 4) }, { unit(char, 4, 6) })

            local merged = AI.rulesFor(c.units[2])
            assert(merged[1].rule == char.ai[1],
                "the blueprint's urgent rule leads the item's high one, across the rank boundary")
        end,
    },
    {
        name = "the player's own list leads every authored band, and orders itself by position",
        fn = function()
            -- The two regimes meeting. The player's list is the one on screen and the one they can
            -- drag, so it is authoritative: it sits below every authored band, and within itself it
            -- is ordered by POSITION alone -- no band, because there is none to author.
            local char = caster("ability_heal") -- heal's own block is `urgent`
            local firstRow  = { act = "wait" }
            local secondRow = { act = "attack" }
            char.aiRules = { firstRow, secondRow }
            local c = Combat.new(arena(8, 8),
                { unit(swordsman(), 4, 4) }, { unit(char, 4, 6) })

            local merged = AI.rulesFor(c.units[2])
            assert(merged[1].rule == firstRow, "the row the player put first leads")
            assert(merged[2].rule == secondRow, "then the row they put second")
            assert(merged[3].item and merged[3].item.id == "ability_heal",
                "and only then the item's own urgent rule -- your list, then what the game brought")

            -- Position is the ONLY thing separating the player's rows, so swapping them swaps the
            -- merge. This is what makes dragging a row in the Tactics tab a real edit.
            char.aiRules = { secondRow, firstRow }
            local again = AI.rulesFor(c.units[2])
            assert(again[1].rule == secondRow and again[2].rule == firstRow,
                "reordering the list reorders the merge")

            -- And the rendered sentence carries no band, because the player's rules have none.
            local sentence = AI.describeRule({ act = "support" })
            assert(sentence:sub(1, 3) == "if ", "a rule reads as a plain if/then, got: " .. sentence)
        end,
    },
    {
        name = "the merge is totally ordered, so two runs cannot disagree",
        fn = function()
            -- table.sort is not stable in Lua 5.1, so the comparator has to be total. It very nearly
            -- wasn't: `order` used to be the index WITHIN the list being collected, so two items each
            -- contributing one rule scored the same rank and the same order, and were separated only
            -- if their authored priorities happened to differ. Two rules at the same band would have
            -- sorted arbitrarily. The running ordinal in `collect` is what closes that.
            local char = caster("ability_heal")
            -- Two item-borne rule sources on one body, plus its own list and the posture floor.
            char.inventory = char.inventory or {}
            local c = Combat.new(arena(8, 8),
                { unit(swordsman(), 4, 4) }, { unit(char, 4, 6) })

            local first = AI.rulesFor(c.units[2])
            for _ = 1, 8 do
                local again = AI.rulesFor(c.units[2])
                assert(#again == #first, "the same body merges to the same number of rules")
                for i = 1, #first do
                    assert(again[i].rule == first[i].rule,
                        "and to the same order every time (slot " .. i .. ")")
                end
            end
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
                act = "support", item = "ability_heal", targetPref = "lowest_hp",
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
                act = "attack", item = "ability_fireball",
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
            char.ai = { { act = "attack" } }
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
            char.ai = { { act = "attack" } }          -- the blueprint's own rule
            char.aiRules = { { act = "wait" } }       -- the player took the list over
            local c = Combat.new(arena(8, 8),
                { unit(swordsman(), 4, 4) }, { unit(char, 4, 6) })
            local merged = AI.rulesFor(c.units[2])

            -- The player's list sits below every authored band, so their rule leads outright -- even
            -- ahead of Heal's own `urgent` block, which is the point of the overlay being theirs.
            assert(merged[1].rule.act == "wait", "the player's own list leads every other source")
            assert(merged[2].item and merged[2].item.id == "ability_heal",
                "and the item's own block comes next, ahead of the posture floor")
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
            assert(ra[1].rule.act == rb[1].rule.act, "reading the same authored rule")
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
            local c = Combat.new(arena(8, 1), { unit("character_rowan", 4, 1) }, { unit(bow, 1, 1) })
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
        name = "an acting plan names its target unit; a wait names none",
        fn = function()
            -- The plan descriptor carries the MARK, not just the aimed cell -- models/intent.lua
            -- compares "who would this unit hit" against the party's own units, and a wide body is
            -- aimed at its nearest cell, so tx,ty need not be any unit's position.
            local c = Combat.new(arena(8, 8),
                { unit(swordsman(), 4, 4) }, { unit("character_bandit", 4, 5) })
            local knight, bandit = c.units[1], c.units[2]
            local act = AI.plan(c, bandit)
            assert(act.item, "the bandit acts")
            assert(act.target == knight, "and the plan names the knight it struck, not just its cell")

            local idle = Combat.new(arena(8, 8), {}, { unit("character_bandit", 1, 1) })
            local waiting = AI.plan(idle, idle.units[1])
            assert(waiting.wait and waiting.target == nil, "a wait comes for nobody")
        end,
    },
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
