-- Tests for the combat model (models/combat.lua): initiative + timeline turn order,
-- movement cost, item actions (range / resource / speed / consume), the tag-driven
-- damage + heal helpers, effect-as-function abilities, and objective evaluation. Pure
-- logic only, so it runs headless.

local Character = require("models.character")
local Item = require("models.item")
local Combat = require("models.combat")

-- A flat, all-walkable arena of the given size (no terrain), with an objective.
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

-- A { char, x, y } spawn entry. Accepts a blueprint id or a prebuilt character instance.
local function unit(charOrId, x, y)
    local char = type(charOrId) == "string" and Character.instantiate(charOrId) or charOrId
    -- Isolate these mechanics tests from a character's innate, which now rides on a bound signature
    -- relic in the grid (an archer's wolf companion, a knight's Oathward): strip that relic, since its
    -- trait, stats, and combat-start summon would otherwise perturb the unit counts and initiative
    -- these fixtures assume. Innate delivery itself is exercised in tests/innate_spec.lua.
    char.traits = {}
    for i = 1, Character.MAX_INVENTORY do
        if char.inventory[i] and char.inventory[i].bound then char.inventory[i] = nil end
    end
    return { char = char, x = x, y = y }
end

-- Open a turn for a specific unit, independent of initiative order, so a test can exercise
-- moveUnit/endTurn on the unit it cares about (mirrors what Combat.startTurn sets up).
local function openTurn(c, u)
    c.turn = { unit = u, moved = false, moveCost = 0 }
end

-- Current value of a unit's resource pool, whether the stat is a {current,max} table or a plain
-- number (Combat.resourceValue's rule, mirrored here so the channel tests can read mana either way).
local function poolOf(u, stat)
    local m = u.char.stats[stat]
    return type(m) == "table" and m.current or m
end

return {
    {
        name = "initiative is the average ability speed minus the speed stat (higher speed acts sooner)",
        fn = function()
            -- Knight: avg(iron_sword 3, healing_potion 2) - speed 3 = 2.5 - 3 = -0.5.
            local knight = Character.instantiate("knight")
            assert(Combat.initiative(knight) == -0.5, "knight initiative should be -0.5")

            -- No ability items -> DEFAULT_SPEED - speed fallback (5 - 3 = 2).
            local bare = Character.instantiate("knight")
            bare.inventory = {}
            assert(Combat.initiative(bare) == Combat.DEFAULT_SPEED - 3, "bare char -> DEFAULT_SPEED - speed")

            -- The speed stat defaults to 0 when unset.
            assert(Combat.speed({ stats = {} }) == 0, "missing speed stat reads as 0")
        end,
    },
    {
        name = "the current unit sits at 0, and ending a turn rebases the next unit to 0",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("knight", 3, 3) }, { unit("bandit", 3, 4) })
            local knight, bandit = c.units[1], c.units[2]
            knight.initiative, knight.speed = 0, 3
            bandit.initiative, bandit.speed = 2, 4
            assert(Combat.startTurn(c) == knight, "the 0-initiative unit is current")

            -- Knight strikes with the sword (speed 3): initiative -> 3, rebase by min(3, 2) = 2.
            local clock0 = c.clock
            assert(Combat.useItem(c, knight, knight.char.inventory[1], 3, 4), "adjacent attack")
            assert(bandit.initiative == 0, "the next unit (bandit, 2) is rebased to 0")
            assert(knight.initiative == 1, "the actor trails one tick behind (3 - 2)")
            assert(c.clock == clock0 + 2, "clock advances by the elapsed 2")
            assert(Combat.currentUnit(c) == bandit, "bandit now acts")
        end,
    },
    {
        name = "moveUnit repositions without ending the turn; endTurn folds the move cost",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("archer", 2, 2) }, {}) -- movement 4, sole unit
            local u = c.units[1]
            Combat.startTurn(c)
            assert(u.initiative == 0, "the sole unit starts at 0")
            local ok, cost = Combat.moveUnit(c, u, 2, 4)
            assert(ok and cost == 2, "2-tile move succeeds, cost 2")
            assert(u.x == 2 and u.y == 4, "position updated")
            assert(u.initiative == 0, "moving does not change initiative on its own")
            assert(Combat.moveUnit(c, u, 2, 5) == false, "a unit may only move once per turn")
            Combat.pass(c, u) -- moved: initiative -> 2, then the sole unit rebases back to 0
            assert(u.initiative == 0, "the sole unit rebases back to 0")
            assert(c.clock == 2, "the move cost (2) shows up as elapsed clock")

            -- Beyond the movement budget: unreachable.
            local far = Combat.new(arena(8, 8), { unit("archer", 1, 1) }, {})
            openTurn(far, far.units[1])
            assert(Combat.moveUnit(far, far.units[1], 6, 6) == false, "10 tiles > movement 4")

            -- Occupied destination is rejected.
            local occ = Combat.new(arena(8, 8),
                { unit("archer", 2, 2), unit("knight", 2, 3) }, {})
            openTurn(occ, occ.units[1])
            assert(Combat.moveUnit(occ, occ.units[1], 2, 3) == false, "cannot move onto a unit")
        end,
    },
    {
        name = "planMove lays out an origin-first path that stepMove walks one tile per call",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("archer", 2, 2) }, {})
            local u = c.units[1]
            Combat.startTurn(c)

            local plan = Combat.planMove(c, u, 2, 5)
            assert(plan and plan.cost == 3, "a 3-tile walk is planned at cost 3")
            assert(#plan.path == 4, "the path holds the origin plus one tile per step, got " .. #plan.path)
            assert(plan.path[1].x == 2 and plan.path[1].y == 2, "path[1] is the tile the unit stands on")
            assert(plan.path[4].x == 2 and plan.path[4].y == 5, "the last tile is the destination")
            -- Every hop is a single cardinal step, so nothing is skipped over on the way.
            for i = 2, #plan.path do
                local a, b = plan.path[i - 1], plan.path[i]
                assert(math.abs(a.x - b.x) + math.abs(a.y - b.y) == 1, "path tiles are adjacent")
            end
            assert(u.x == 2 and u.y == 2 and not Combat.hasMoved(c), "planning alone moves nothing")

            local walk = Combat.beginMove(c, plan)
            assert(Combat.hasMoved(c), "opening the walk spends the turn's one move")
            assert(u.x == 2 and u.y == 2, "but the unit hasn't left the origin yet")

            for i = 2, #plan.path do
                assert(Combat.stepMove(c, walk), "a step remains")
                assert(u.x == plan.path[i].x and u.y == plan.path[i].y,
                    "the unit stands on path tile " .. i)
            end
            assert(Combat.stepMove(c, walk) == false, "the walk is over once the destination is reached")
            assert(u.initiative == 0, "walking does not change initiative on its own")
        end,
    },
    {
        name = "useItem attacks: range, resource cost, speed, and damage all apply",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("knight", 3, 3) }, { unit("bandit", 3, 4) })
            local knight, bandit = c.units[1], c.units[2]
            knight.initiative, bandit.initiative = 0, 100 -- keep bandit far so the cost shows as elapsed
            knight.char.stats.staminaRegen = 0 -- isolate the spend from tick-proportional regen
            local sword = knight.char.inventory[1]
            assert(sword.name == "Iron Sword", "knight's first item is the sword")

            local stam0 = knight.char.stats.stamina.current
            local clock0 = c.clock
            local hp0 = bandit.char.stats.health.current

            local ok, res = Combat.useItem(c, knight, sword, 3, 4)
            assert(ok, "adjacent attack should succeed")
            assert(res.damageDealt == 14, "sword power 6 + 14 dmg - 6 def = 14, got " .. res.damageDealt)
            assert(bandit.char.stats.health.current == hp0 - 14, "target lost 14 HP")
            assert(knight.char.stats.stamina.current == stam0 - 8, "stamina cost spent")
            assert(c.clock == clock0 + 3, "the turn cost the ability speed 3")

            -- Out of range.
            assert(Combat.useItem(c, knight, sword, 3, 8) == false, "range 1 can't hit 5 tiles away")

            -- Unaffordable cost.
            knight.char.stats.stamina.current = 2
            assert(Combat.useItem(c, knight, sword, 3, 4) == false, "8-cost with 2 stamina rejected")
        end,
    },
    {
        name = "a lethal hit marks the target dead",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("knight", 3, 3) }, { unit("bandit", 3, 4) })
            local knight, bandit = c.units[1], c.units[2]
            bandit.char.stats.health.current = 3
            assert(Combat.useItem(c, knight, knight.char.inventory[1], 3, 4), "attack lands")
            assert(bandit.alive == false, "target at <=0 HP is dead")
            assert(bandit.char.stats.health.current == 0, "HP clamped to 0")
        end,
    },
    {
        name = "a spent consumable keeps its (now empty) slot and can't be reused",
        fn = function()
            local c = Combat.new(arena(8, 8),
                { unit("mage", 3, 3), unit("knight", 3, 4) }, {})
            local mage, knight = c.units[1], c.units[2]
            local potion = mage.char.inventory[1]
            assert(potion.name == "Healing Potion", "mage carries the potion")

            knight.char.stats.health.current = 50
            local invBefore = #mage.char.inventory
            local ok, res = Combat.useItem(c, mage, potion, 3, 4) -- heal adjacent ally
            assert(ok, "healing an ally should succeed")
            assert(res.healed == 30, "flat 30 heal, got " .. res.healed)
            assert(knight.char.stats.health.current == 80, "ally healed 50 -> 80")
            -- The single-use potion is now spent (quantity 0) but its slot is KEPT.
            assert(#mage.char.inventory == invBefore, "empty stack keeps its inventory slot")
            assert(potion.quantity == 0, "stack is spent")
            assert(Combat.isDepleted(potion), "a spent consumable reads as depleted")
            -- A depleted stack refuses another use until it's restocked.
            c.turn = { unit = mage, moved = false, moveCost = 0 }
            local ok2, why = Combat.useItem(c, mage, potion, 3, 4)
            assert(not ok2 and why == "out of stock", "spent stack can't be used again")
        end,
    },
    {
        name = "dealDamage floors at 1 and applyHeal caps at max",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("mage", 1, 1) }, { unit("warlord", 1, 2) })
            local sword = Item.instantiate("iron_sword") -- power 6
            -- Sword power 6 + mage damage 5 (physical) - warlord defense 16 -> negative, floored to 1.
            local d = Combat.dealDamage(c, c.units[1], c.units[2], sword, {})
            assert(d == 1, "damage floors at 1, got " .. d)

            local knight = Character.instantiate("knight")
            knight.stats.health.current = 90
            local healed = Combat.applyHeal(c, { char = knight }, 30)
            assert(healed == 10, "heal capped at max (90 -> 100), got " .. healed)
            assert(knight.stats.health.current == 100, "HP capped at max")
        end,
    },
    {
        name = "tags route the scaling stat and armor mitigates matching tags",
        fn = function()
            -- Magical attack scales off magicDamage/magicDefense.
            local mc = Combat.new(arena(8, 8), { unit("mage", 1, 1) }, { unit("bandit", 1, 2) })
            local gem = Item.instantiate("ability_fireball") -- tags { fire, magical }, power 8
            local dm = Combat.dealDamage(mc, mc.units[1], mc.units[2], gem, {})
            assert(dm == 23, "fireball power 8 + 18 magicDmg - 3 magicDef = 23, got " .. dm)

            -- Leather armor: +4 defense and tag resist { slash = 3, physical = 2 }. A slash
            -- weapon is mitigated more than a same-power pierce weapon, isolating the tag match.
            local armored = Character.instantiate("bandit") -- base defense 6, health 60
            assert(Character.addItem(armored, Item.instantiate("leather_armor")), "equip armor")
            local ac = Combat.new(arena(8, 8), { unit("warlord", 1, 1) }, { unit(armored, 1, 2) })
            local attacker, defender = ac.units[1], ac.units[2] -- warlord damage 28
            local sword = Item.instantiate("iron_sword") -- tags { sword, slash, physical }
            local bow = Item.instantiate("bow")          -- tags { bow, pierce, physical }

            local dSlash = Combat.dealDamage(ac, attacker, defender, sword, {}) -- sword power 6
            defender.char.stats.health.current = defender.char.stats.health.max -- reset for a clean 2nd hit
            local dPierce = Combat.dealDamage(ac, attacker, defender, bow, {})  -- bow power 5
            assert(dSlash == 19, "6 + 28 - (6+4) def - (3 slash + 2 physical) = 19, got " .. dSlash)
            assert(dPierce == 21, "5 + 28 - (6+4) def - (2 physical only) = 21, got " .. dPierce)
            assert(dSlash < dPierce, "slash-resisting armor mitigates the sword more than the bow")

            -- No armor: full power + stat, minus defense, no tag mitigation.
            local uc = Combat.new(arena(8, 8), { unit("knight", 1, 1) }, { unit("bandit", 1, 2) })
            local du = Combat.dealDamage(uc, uc.units[1], uc.units[2], uc.units[1].char.inventory[1], {})
            assert(du == 14, "un-resisted attack does full 6 + 14 - 6 = 14, got " .. du)
        end,
    },
    {
        name = "an effect function composes helpers (damage + lifesteal heal)",
        fn = function()
            local wand = {
                name = "Draining Wand", tags = { "arcane", "magical" },
                activeAbility = {
                    name = "Drain", target = "enemy", range = 3, speed = 3, damage = 5,
                    effect = function(fx)
                        local dealt = fx.damage(fx.target) -- damage + magicDamage - magicDefense
                        fx.heal(fx.user, dealt) -- lifesteal the amount dealt
                    end,
                },
            }
            local c = Combat.new(arena(8, 8), { unit("mage", 2, 2) }, { unit("bandit", 2, 3) })
            local mage = c.units[1]
            mage.char.stats.health.current = 40
            local ok, res = Combat.useItem(c, mage, wand, 2, 3)
            assert(ok, "ranged drain should succeed")
            assert(res.damageDealt == 20, "wand power 5 + 18 magicDmg - 3 magicDef = 20")
            assert(res.healed == 20, "lifesteal heals the amount dealt")
            assert(mage.char.stats.health.current == 60, "40 + 20 = 60")
        end,
    },
    {
        name = "abilityOutput previews raw damage/heal/status with no board target",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("knight", 1, 1), unit("mage", 2, 1) }, {})
            local knight, mage = c.units[1], c.units[2]

            -- Iron Sword: power 6 + knight damage 14 = 20 (the stand-in has no defense).
            local swOut = Combat.abilityOutput(knight, knight.char.inventory[1])
            assert(swOut.damage == 20, "sword preview = 6 + 14 = 20, got " .. swOut.damage)
            assert(swOut.heal == 0 and not swOut.multi, "a single strike: no heal, not AoE")

            -- Fireball: magical, power 8 + mage magicDamage 18 = 26 per target; AoE flag set.
            local fbOut = Combat.abilityOutput(mage, Item.instantiate("ability_fireball"))
            assert(fbOut.damage == 26, "fireball preview = 8 + 18 = 26, got " .. fbOut.damage)
            assert(fbOut.multi, "fireball is an AoE ability (its number is per target)")

            -- Healing Potion: heal scales with Power (30); no damage.
            local hpOut = Combat.abilityOutput(mage, Item.instantiate("healing_potion"))
            assert(hpOut.heal == 30 and hpOut.damage == 0, "potion previews a 30 heal")

            -- Jolt: light magical hit (4 + 18 = 22) PLUS a stun whose magnitude scales with Power.
            local jOut = Combat.abilityOutput(mage, Item.instantiate("ability_jolt"))
            assert(jOut.damage == 22, "jolt preview = 4 + 18 = 22, got " .. jOut.damage)
            assert(#jOut.statuses == 1 and jOut.statuses[1].id == "stun", "jolt applies stun")
            assert(jOut.statuses[1].opts.magnitude == 4, "stun magnitude scales with Power (4)")

            -- A passive item (no active ability) previews nothing.
            assert(Combat.abilityOutput(knight, Item.instantiate("leather_armor")) == nil,
                "a passive item has no ability output")
        end,
    },
    {
        name = "evaluate resolves killAll, party wipe, and assassinate",
        fn = function()
            local kill = Combat.new(arena(8, 8), { unit("knight", 1, 1) }, { unit("bandit", 1, 2) })
            assert(Combat.evaluate(kill) == nil, "ongoing while both sides live")
            kill.units[2].alive = false
            assert(Combat.evaluate(kill) == "win", "all enemies dead -> win")

            local wipe = Combat.new(arena(8, 8), { unit("knight", 1, 1) }, { unit("bandit", 1, 2) })
            wipe.units[1].alive = false
            assert(Combat.evaluate(wipe) == "loss", "party wiped -> loss")

            local hunt = Combat.new(arena(8, 8, { type = "assassinate", target = "bandit_chief" }),
                { unit("knight", 1, 1) },
                { unit("bandit_chief", 1, 2), unit("bandit", 1, 3) })
            assert(Combat.evaluate(hunt) == nil, "target still alive")
            hunt.units[2].alive = false -- chief falls; a lesser bandit still stands
            assert(Combat.evaluate(hunt) == "win", "target dead -> win even with foes left")
        end,
    },
    {
        name = "previewOrder reorders only the named unit without mutating state",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("knight", 4, 7) }, { unit("wolf_grunt", 4, 2) })
            local knight, wolf = c.units[1], c.units[2]
            wolf.initiative, knight.initiative = 0, 0.5 -- wolf current

            assert(Combat.turnOrder(c)[1] == wolf, "wolf (0) acts first live")

            -- Preview the wolf acting (initiative 0 -> 3): knight (0.5) should jump ahead.
            local preview = Combat.previewOrder(c, wolf, wolf.initiative + 3)
            assert(preview[1] == knight, "preview puts knight (0.5) ahead of wolf (3)")
            assert(preview[2] == wolf, "wolf now trails in the preview")

            -- Nothing was mutated: live initiatives and order are unchanged.
            assert(wolf.initiative == 0, "previewOrder must not mutate unit.initiative")
            assert(Combat.turnOrder(c)[1] == wolf, "live order unchanged after preview")
        end,
    },
    {
        name = "previewTimeline keeps the actor's real slot and adds a ghost at its new initiative",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("knight", 4, 7) }, { unit("wolf_grunt", 4, 2) })
            local knight, wolf = c.units[1], c.units[2]
            wolf.initiative, knight.initiative = 0, 0.5

            local entries = Combat.previewTimeline(c, wolf, wolf.initiative + 3) -- wolf 0 -> ghost 3
            assert(#entries == 3, "two units + one ghost = 3 entries, got " .. #entries)

            assert(entries[1].unit == wolf and not entries[1].preview, "real wolf stays first")
            assert(entries[2].unit == knight, "knight (0.5) sits between")
            assert(entries[3].unit == wolf and entries[3].preview, "wolf ghost lands last")

            local ghosts = 0
            for _, e in ipairs(entries) do if e.preview then ghosts = ghosts + 1 end end
            assert(ghosts == 1, "exactly one preview ghost")
            assert(wolf.initiative == 0, "previewTimeline must not mutate unit.initiative")
        end,
    },
    {
        name = "a wait preview ghost lands just AFTER the unit it delays past at a shared initiative",
        fn = function()
            -- Two party units tied at initiative 2 with equal speed; previewing the first one
            -- waiting to the second's initiative must place its ghost behind the (real) second.
            local c = Combat.new(arena(8, 8), { unit("knight", 1, 1), unit("archer", 2, 2) }, {})
            local knight, archer = c.units[1], c.units[2]
            knight.initiative, archer.initiative = 2, 2
            knight.speed, archer.speed = 5, 5 -- equal, so spawn index decides knight-before-archer

            local entries = Combat.previewTimeline(c, knight, archer.initiative) -- wait: newInit = 2
            assert(entries[1].unit == knight and not entries[1].preview, "knight keeps its live slot")
            assert(entries[2].unit == archer and not entries[2].preview, "the next unit sits ahead")
            assert(entries[3].unit == knight and entries[3].preview, "the wait ghost lands after it")
        end,
    },
    {
        name = "previewTimeline sorts strictly by initiative (a high-initiative ghost lands last)",
        fn = function()
            -- A ghost projected far down the timeline must sort purely by its initiative -- a
            -- guard-rail against a comparator that isn't a valid weak order (which corrupts sort).
            local c = Combat.new(arena(8, 8),
                { unit("knight", 1, 1), unit("mage", 2, 1), unit("archer", 3, 1) },
                { unit("bandit", 1, 8), unit("bandit", 2, 8), unit("bandit_chief", 3, 8) })
            c.units[1].initiative = 1.5 -- knight
            c.units[2].initiative = 1.0 -- mage
            c.units[3].initiative = 0.0 -- archer (current)
            c.units[4].initiative, c.units[5].initiative, c.units[6].initiative = 1.0, 1.0, 1.0

            local entries = Combat.previewTimeline(c, c.units[3], 4.0) -- archer's ghost at 4.0
            for i = 2, #entries do
                assert(entries[i].initiative >= entries[i - 1].initiative,
                    "entries must be ascending by initiative")
            end
            assert(entries[#entries].preview and entries[#entries].initiative == 4.0,
                "the 4.0 ghost is last, after the 1.5 unit")
        end,
    },
    {
        name = "speed breaks a tie in turn order (the faster unit acts first)",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("knight", 1, 1) }, { unit("bandit", 1, 2) })
            local knight, bandit = c.units[1], c.units[2]
            knight.initiative, bandit.initiative = 0, 0 -- exact tie
            knight.speed, bandit.speed = 3, 7           -- bandit is faster
            assert(Combat.currentUnit(c) == bandit, "the higher-speed unit wins the tie")
        end,
    },
    {
        name = "planEnemyAction attacks in range, else steps toward the nearest party unit",
        fn = function()
            -- Bandit adjacent to the knight: it should attack in place (iron_sword range 1).
            local adj = Combat.new(arena(8, 8), { unit("knight", 4, 4) }, { unit("bandit", 4, 5) })
            local act = Combat.planEnemyAction(adj, adj.units[2])
            assert(act.item and not act.move, "adjacent bandit attacks without moving")
            assert(act.tx == 4 and act.ty == 4, "targets the knight's tile")

            -- Bandit far away (can't reach striking distance): it should move, closing the gap.
            local far = Combat.new(arena(8, 8), { unit("knight", 4, 8) }, { unit("bandit", 4, 1) })
            local bandit = far.units[2]
            local move = Combat.planEnemyAction(far, bandit)
            assert(move.move and not move.item, "far bandit moves without attacking")
            local before = math.abs(bandit.x - 4) + math.abs(bandit.y - 8)
            local after = math.abs(move.move.x - 4) + math.abs(move.move.y - 8)
            assert(after < before, "the chosen move gets strictly closer to the knight")

            -- No party units left: wait.
            local none = Combat.new(arena(8, 8), {}, { unit("bandit", 1, 1) })
            assert(Combat.planEnemyAction(none, none.units[1]).wait, "no targets -> wait")
        end,
    },
    {
        name = "planEnemyAction moves then attacks when a foe is one step out of range",
        fn = function()
            -- Bandit two tiles from the knight (iron_sword range 1): move adjacent, then strike.
            local c = Combat.new(arena(8, 8), { unit("knight", 4, 4) }, { unit("bandit", 4, 6) })
            local act = Combat.planEnemyAction(c, c.units[2])
            assert(act.move, "bandit moves to close the gap")
            assert(math.abs(act.move.x - 4) + math.abs(act.move.y - 4) == 1, "lands adjacent")
            assert(act.item and act.tx == 4 and act.ty == 4, "attacks the knight after moving")
        end,
    },
    {
        name = "move then attack folds the move cost and the ability speed into one turn",
        fn = function()
            -- Knight (movement 3, iron_sword speed 3) steps 2 tiles then strikes the bandit.
            local c = Combat.new(arena(8, 8), { unit("knight", 3, 3) }, { unit("bandit", 3, 6) })
            local knight, bandit = c.units[1], c.units[2]
            knight.initiative, bandit.initiative = 0, 100 -- bandit far so the cost shows as elapsed
            local sword = knight.char.inventory[1]
            openTurn(c, knight)
            local clock0 = c.clock
            assert(Combat.moveUnit(c, knight, 3, 5), "step two tiles down toward the bandit")
            assert(knight.initiative == 0, "the move alone does not change initiative")
            assert(Combat.useItem(c, knight, sword, 3, 6), "now adjacent -> attack lands")
            assert(c.clock == clock0 + 2 + 3, "turn cost = move cost 2 + ability speed 3")
        end,
    },
    {
        name = "terrain enter-cost limits reach and raises move time",
        fn = function()
            -- 5x1 corridor: ground, forest(2), ground, ground, ground; archer has movement 4,
            -- less 1 for its leather armor = an effective budget of 3.
            local row = {
                { type = "ground",   moveCost = 1, walkable = true },
                { type = "forest",   moveCost = 2, walkable = true },
                { type = "ground",   moveCost = 1, walkable = true },
                { type = "ground",   moveCost = 1, walkable = true },
                { type = "ground",   moveCost = 1, walkable = true },
            }
            local a = { cols = 5, rows = 1, tiles = { row }, objective = { type = "killAll" } }
            local c = Combat.new(a, { unit("archer", 1, 1) }, {})
            local u = c.units[1]
            Combat.startTurn(c)

            local r = Combat.reachable(c, u)
            assert(r["3,1"] and r["3,1"].cost == 3, "path through the forest costs 3 of the budget")
            assert(r["4,1"] == nil, "the forest cost puts x=4 out of a movement-3 reach")

            assert(Combat.moveUnit(c, u, 3, 1), "move across the forest to x=3")
            Combat.pass(c, u) -- sole unit rebases back to 0; the cost 3 shows on the clock
            assert(c.clock == 3, "move time is the terrain-weighted cost 3, not the 2 tiles")
        end,
    },
    {
        name = "wait delays the actor to just after the next unit (nextInit + 1)",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("knight", 4, 7) }, { unit("wolf_grunt", 4, 2) })
            local knight, wolf = c.units[1], c.units[2]
            wolf.initiative, knight.initiative = 0, 3 -- wolf current, knight next at 3

            assert(Combat.startTurn(c) == wolf, "wolf (0) is up first")
            assert(Combat.wait(c, wolf), "wolf waits")
            -- wait: wolf initiative = knight(3) + 1 = 4; rebase by min(4, 3) = 3.
            assert(knight.initiative == 0, "the delayed-past unit (knight) is now current")
            assert(wolf.initiative == 1, "the waiter lands one tick behind it (4 - 3)")
            assert(Combat.currentUnit(c) == knight, "knight acts next")

            -- Last unit standing: no one to delay past, so wait falls back to a WAIT_COST bump.
            local solo = Combat.new(arena(8, 8), { unit("knight", 1, 1) }, {})
            local k = solo.units[1]
            Combat.startTurn(solo)
            assert(Combat.wait(solo, k), "a lone unit can still wait")
            assert(solo.clock == Combat.WAIT_COST, "a lone wait advances the clock by WAIT_COST")
            assert(k.initiative == 0, "and the lone unit rebases back to 0")
        end,
    },
    {
        name = "moving then waiting still pays the move cost (delay floors at the move cost)",
        fn = function()
            -- Move cost decides: the next unit is close, so the move cost (3) sets the landing.
            local c = Combat.new(arena(8, 8), { unit("archer", 2, 2) }, { unit("knight", 6, 6) })
            local archer, other = c.units[1], c.units[2]
            archer.initiative, other.initiative = 0, 1
            openTurn(c, archer)
            local ok, cost = Combat.moveUnit(c, archer, 2, 5) -- 3 tiles of open ground
            assert(ok and cost == 3, "the move itself costs 3")
            Combat.wait(c, archer)
            -- wait: max(moveCost 3, other 1 + 1) = 3; rebase by min(3, 1) = 1.
            assert(archer.x == 2 and archer.y == 5, "the reposition still happened")
            assert(other.initiative == 0, "the next unit becomes current")
            assert(archer.initiative == 2, "the move cost dominates (3), landing archer at 3 - 1")

            -- Delay decides: a 1-tile move can't push past a far-ahead next unit.
            local c2 = Combat.new(arena(8, 8), { unit("archer", 2, 2) }, { unit("knight", 6, 6) })
            local a2, k2 = c2.units[1], c2.units[2]
            a2.initiative, k2.initiative = 0, 10
            openTurn(c2, a2)
            assert(Combat.moveUnit(c2, a2, 2, 3), "step one tile (cost 1)")
            Combat.wait(c2, a2)
            -- wait: max(moveCost 1, k2 10 + 1) = 11; rebase by min(11, 10) = 10.
            assert(k2.initiative == 0 and a2.initiative == 1, "delay dominates: one tick after k2")
        end,
    },
    {
        name = "every character carries a hidden unarmed weapon, overridable by blueprint",
        fn = function()
            -- Default: the generic unarmed item, kept OUT of inventory (never in the 9 slots).
            local knight = Character.instantiate("knight")
            assert(knight.unarmed and knight.unarmed.id == "unarmed", "default unarmed attached")
            for _, it in ipairs(knight.inventory) do
                assert(it.id ~= "unarmed", "unarmed must never sit in inventory")
            end

            -- A blueprint can name its own unarmed weapon (e.g. a beast's natural bite).
            Character.defs.test_beast = {
                name = "Test Beast", sprite = "assets/none.png",
                stats = { health = 10, speed = 0 }, unarmed = "fangs",
            }
            local beast = Character.instantiate("test_beast")
            assert(beast.unarmed.id == "fangs", "blueprint unarmed override honoured")
            Character.defs.test_beast = nil -- don't leak the fixture to other specs
        end,
    },
    {
        name = "defaultWeapon picks the first inventory weapon, else the unarmed fallback",
        fn = function()
            -- Knight: iron_sword is the first (and only) weapon -> it is the default attack.
            local knight = Character.instantiate("knight")
            assert(Combat.defaultWeapon(knight).name == "Iron Sword", "first weapon wins")

            -- No weapon in inventory -> the hidden unarmed weapon.
            knight.inventory = {}
            assert(Combat.defaultWeapon(knight) == knight.unarmed, "empty inventory -> unarmed")

            -- Non-weapon ability items do NOT count as the default weapon.
            local mage = Character.instantiate("mage")
            mage.inventory = { Item.instantiate("ability_fireball") } -- type "ability", not "weapon"
            assert(Combat.defaultWeapon(mage) == mage.unarmed, "an ability item isn't a default weapon")
        end,
    },
    {
        name = "defaultActionSlot pins any ability as the default action, with safe fallbacks",
        fn = function()
            -- Knight carries iron_sword in slot 1; add a bow in a later slot as a second option.
            local knight = Character.instantiate("knight")
            local bow = Item.instantiate("bow")
            knight.inventory[3] = bow
            assert(Combat.defaultAction(knight).name == "Iron Sword", "no pin -> first grid weapon wins")

            -- A pin at an ability cell overrides row-major grid order.
            knight.defaultActionSlot = 3
            assert(Combat.defaultAction(knight) == bow, "a pinned slot beats grid order")

            -- A pin at an empty cell is stale -> fall back to the first-weapon scan.
            knight.defaultActionSlot = 5
            assert(Combat.defaultAction(knight).name == "Iron Sword", "a pin on an empty cell falls back")

            -- Unlike the default weapon, ANY ability can be the default action: pin a non-weapon
            -- ability and it wins (a mage making its attack spell the go-to action).
            local fireball = Item.instantiate("ability_fireball")
            knight.inventory[5] = fireball
            knight.defaultActionSlot = 5
            assert(Combat.defaultAction(knight) == fireball, "a pinned non-weapon ability is the default action")

            -- defaultWeapon stays offensive-only and never reads the action pin.
            assert(Combat.defaultWeapon(knight).name == "Iron Sword", "defaultWeapon ignores the action pin")
        end,
    },
    {
        name = "a blueprint's authored defaultAction pins that ability on a fresh instance",
        fn = function()
            -- The mage blueprint authors ability_fireball as its default action, so a freshly
            -- instantiated (recruited) mage already has it pinned rather than the bare auto-pick
            -- (which, first-weapon-first, would land on its staff).
            local mage = Character.instantiate("mage")
            local action = Combat.defaultAction(mage)
            assert(action and action.id == "ability_fireball", "authored default action is pinned on recruit")
            assert(mage.defaultActionSlot ~= nil, "the pin resolves to the grid cell holding it")
            -- The staff is still the plain default WEAPON (offensive fallback); the pin only moves the
            -- default ACTION.
            assert(Combat.defaultWeapon(mage).id == "parasitic_staff", "the default weapon is unaffected")
        end,
    },
    {
        name = "attackReach folds movement in (walk-and-strike reach beyond the caster's own range)",
        fn = function()
            -- A melee (range 1) fighter with room to move: its reach should extend past its own
            -- one-tile ring to everywhere it could walk-then-strike this turn.
            local c = Combat.new(arena(10, 10), { unit("knight", 2, 2) }, { unit("bandit", 9, 9) })
            local knight = c.units[1]
            local reachable = Combat.reachable(c, knight)
            local reach = Combat.attackReach(c, knight, 1, reachable, false, 0)
            -- A cell two or more tiles away (unreachable from the origin at range 1) is in reach once
            -- movement is folded in -- and it records the stand tile the strike launches from.
            local far = reach[(knight.x + 2) .. "," .. knight.y]
            assert(far ~= nil, "a tile past the caster's own range is reachable after moving")
            assert(far.fromX ~= knight.x or far.fromY ~= knight.y, "it records a stand tile to move to first")
        end,
    },
    {
        name = "a weaponless unit can still strike with its unarmed weapon (low power, free)",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("warlord", 3, 3) }, { unit("bandit", 3, 4) })
            local warlord, bandit = c.units[1], c.units[2]
            warlord.char.inventory = {} -- strip its sword: unarmed is the only attack left
            warlord.initiative, bandit.initiative = 0, 100 -- bandit far so the cost shows elapsed
            local fist = Combat.defaultWeapon(warlord.char)
            assert(fist == warlord.char.unarmed, "no weapon -> unarmed is the default attack")

            local stam0 = warlord.char.stats.stamina.current
            local clock0 = c.clock
            local ok, res = Combat.useItem(c, warlord, fist, 3, 4)
            assert(ok, "adjacent unarmed strike lands")
            -- unarmed power 2 + 28 damage - 6 defense = 24 (a sword, power 6, would do 28).
            assert(res.damageDealt == 24, "low-power hit: 2 + 28 - 6 = 24, got " .. res.damageDealt)
            assert(warlord.char.stats.stamina.current == stam0, "unarmed costs no stamina")
            assert(c.clock == clock0 + 5, "the turn costs the unarmed speed (5)")
        end,
    },
    {
        name = "attackReach covers the band one step beyond movement (drives the threat overlay)",
        fn = function()
            -- Knight (chainmail drops movement to 2) alone: it can walk to (4,6) (cost 2) and,
            -- with a range-1 weapon, threaten (4,7) -- a tile it cannot itself stand on this turn.
            local c = Combat.new(arena(8, 8), { unit("knight", 4, 4) }, {})
            local knight = c.units[1]
            local reach = Combat.reachable(c, knight)
            local ar = Combat.attackReach(c, knight, 1, reach)

            assert(reach["4,7"] == nil, "the far tile is beyond a movement-2 reach")
            local cell = ar["4,7"]
            assert(cell, "but it IS within attack reach (threat band)")
            local d = math.abs(cell.fromX - 4) + math.abs(cell.fromY - 7)
            assert(d <= 1, "the recorded stand tile is within weapon range of the target")
            assert(cell.fromX == knight.x and cell.fromY == knight.y
                or reach[cell.fromX .. "," .. cell.fromY], "stand tile is the origin or reachable")

            -- The unit's own tile is reachable-adjacent, so it is in reach at cost 0.
            assert(ar["4,4"] and ar["4,4"].moveCost == 0, "origin is in reach at no move cost")
        end,
    },
    {
        name = "a minRange weapon (bow) can't target adjacent tiles but can hit within its band",
        fn = function()
            -- Archer with a bow (range 3, minRange 2) at (4,4); enemies at distance 1, 2, and 3.
            local c = Combat.new(arena(8, 8),
                { unit("archer", 4, 4) },
                { unit("bandit", 5, 4), unit("bandit", 6, 4), unit("bandit", 7, 4) })
            local archer = c.units[1]
            local adj, mid, far = c.units[2], c.units[3], c.units[4]
            local bow = Item.instantiate("bow")

            -- The confirm gate rejects a point-blank shot before spending any cost.
            local stam0 = archer.char.stats.stamina.current
            local ok, reason = Combat.useItem(c, archer, bow, adj.x, adj.y)
            assert(not ok and reason == "too close", "adjacent target is inside the dead zone")
            assert(archer.char.stats.stamina.current == stam0, "a rejected shot costs nothing")

            -- The valid-target set excludes the adjacent foe but includes the 2- and 3-tile foes.
            local targets = Combat.abilityTargets(c, archer, bow)
            local hit = {}
            for _, t in ipairs(targets) do hit[t] = true end
            assert(not hit[adj], "the adjacent enemy is not targetable")
            assert(hit[mid] and hit[far], "the 2- and 3-tile enemies are targetable")

            -- A shot at the 2-tile foe lands.
            openTurn(c, archer)
            local ok2 = Combat.useItem(c, archer, bow, mid.x, mid.y)
            assert(ok2, "a shot at range 2 (inside the band) lands")
        end,
    },
    {
        name = "a melee weapon still strikes adjacent (no minRange regression)",
        fn = function()
            local c = Combat.new(arena(8, 8),
                { unit("knight", 4, 4) }, { unit("bandit", 5, 4) })
            local knight, bandit = c.units[1], c.units[2]
            local sword = Item.instantiate("iron_sword") -- range 1, no minRange
            openTurn(c, knight)
            local ok = Combat.useItem(c, knight, sword, bandit.x, bandit.y)
            assert(ok, "a range-1 weapon with no minRange still hits an adjacent foe")
        end,
    },
    {
        name = "attackReach with a minRange excludes the adjacent ring",
        fn = function()
            -- From the origin only (empty reachable set), a range-3 / minRange-2 weapon threatens
            -- the 2- and 3-tile band but not the adjacent ring.
            local c = Combat.new(arena(8, 8), { unit("archer", 4, 4) }, {})
            local archer = c.units[1]
            local ar = Combat.attackReach(c, archer, 3, {}, false, 2)
            assert(ar["5,4"] == nil, "the adjacent tile is inside the dead zone")
            assert(ar["4,4"] == nil, "the origin (distance 0) is inside the dead zone")
            assert(ar["6,4"], "a 2-tile target is threatened")
            assert(ar["7,4"], "a 3-tile target is threatened")
        end,
    },
    {
        name = "Shadow Strike hits an adjacent foe, then blinks the caster back to its turn origin",
        fn = function()
            -- Rogue opens its turn at (1,1), moves up beside a bandit at (3,1), strikes, and snaps
            -- back to (1,1) -- the tile Combat.startTurn pinned as the turn's origin.
            local c = Combat.new(arena(8, 8), { unit("knight", 1, 1) }, { unit("bandit", 3, 1) })
            local rogue, bandit = c.units[1], c.units[2]
            rogue.char.inventory = { Item.instantiate("ability_shadow_strike") }
            local strike = rogue.char.inventory[1]

            -- Mirror startTurn's origin record, then "move" adjacent to the bandit.
            c.turn = { unit = rogue, moved = true, moveCost = 0, startX = 1, startY = 1 }
            rogue.x, rogue.y = 2, 1

            local hp0 = bandit.char.stats.health.current
            local ok = Combat.useItem(c, rogue, strike, bandit.x, bandit.y)
            assert(ok, "the adjacent strike lands")
            assert(bandit.char.stats.health.current < hp0, "the bandit takes damage")
            assert(rogue.x == 1 and rogue.y == 1, "the rogue blinks back to where its turn began")
        end,
    },
    {
        name = "Shadow Strike stays put when the caster never left its origin tile",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("knight", 2, 1) }, { unit("bandit", 3, 1) })
            local rogue, bandit = c.units[1], c.units[2]
            rogue.char.inventory = { Item.instantiate("ability_shadow_strike") }
            local strike = rogue.char.inventory[1]

            -- Origin equals the current tile (no move this turn): the blink-back is a no-op.
            c.turn = { unit = rogue, moved = false, moveCost = 0, startX = 2, startY = 1 }
            assert(Combat.useItem(c, rogue, strike, bandit.x, bandit.y), "the strike lands")
            assert(rogue.x == 2 and rogue.y == 1, "no move -> the caster holds its ground")
        end,
    },
    {
        name = "Tangling Roots and the Net both leave their target Rooted",
        fn = function()
            local Status = require("models.status")
            local c = Combat.new(arena(8, 8),
                { unit("mage", 1, 1), unit("knight", 5, 5) }, { unit("bandit", 1, 3), unit("bandit", 5, 6) })
            local mage, rogue, bandit1, bandit2 = c.units[1], c.units[2], c.units[3], c.units[4]

            mage.char.inventory = { Item.instantiate("ability_tangling_roots") }
            openTurn(c, mage)
            assert(Combat.useItem(c, mage, mage.char.inventory[1], bandit1.x, bandit1.y), "roots cast lands")
            assert(Status.has(bandit1, "root"), "Tangling Roots applies Root")

            rogue.char.inventory = { Item.instantiate("net") }
            openTurn(c, rogue)
            assert(Combat.useItem(c, rogue, rogue.char.inventory[1], bandit2.x, bandit2.y), "net throw lands")
            assert(Status.has(bandit2, "root"), "the Net applies Root")
        end,
    },

    -- ---------------------------------------------------------------------------
    -- Channeled abilities: a large AOE spell winds up for `ab.channel` ticks (during which other
    -- units act and may flee the blast) before resolving, and only THEN pays ab.speed. Hard control
    -- and forced movement interrupt it; the committed cost is not refunded. See models/combat.lua
    -- (useItem's channel branch, resolveCast, resolveChannel, interruptChannel).
    -- ---------------------------------------------------------------------------
    {
        name = "a channeled ability winds up instead of firing, committing its cost up front",
        fn = function()
            local Status = require("models.status")
            local c = Combat.new(arena(8, 8),
                { unit("mage", 2, 2) }, { unit("bandit", 2, 4), unit("bandit", 3, 4) })
            local mage, b1, b2 = c.units[1], c.units[2], c.units[3]
            mage.char.inventory = { Item.instantiate("ability_fireball") }
            local fireball = mage.char.inventory[1]
            assert(fireball.activeAbility.channel == 2, "fireball carries a channel wind-up (deep-copied from data)")
            mage.initiative, b1.initiative, b2.initiative = 0, 1, 2
            local mana0 = poolOf(mage, "mana")
            local hp1, hp2 = b1.char.stats.health.current, b2.char.stats.health.current

            openTurn(c, mage)
            local ok, res = Combat.useItem(c, mage, fireball, b1.x, b1.y)
            assert(ok and res.channeling, "the cast reports it began a channel")
            assert(b1.char.stats.health.current == hp1 and b2.char.stats.health.current == hp2,
                "nothing is damaged during the wind-up")
            assert(mage.channel and mage.channel.ab == fireball.activeAbility,
                "the pending spell is held on the caster")
            assert(Status.has(mage, "channeling"), "the caster shows the Channeling badge")
            assert(poolOf(mage, "mana") == mana0 - 12, "mana is spent at cast-start, not at resolution")
            assert(Combat.currentUnit(c) == b1, "the caster's turn ended -- another unit acts during the wind-up")
        end,
    },
    {
        name = "a wound-up channel resolves its effect and charges speed (not the channel)",
        fn = function()
            local Status = require("models.status")
            local c = Combat.new(arena(8, 8),
                { unit("mage", 2, 2) }, { unit("bandit", 6, 6), unit("bandit", 1, 1) })
            local mage, tank, other = c.units[1], c.units[2], c.units[3]
            mage.char.inventory = { Item.instantiate("ability_fireball") }
            local fireball = mage.char.inventory[1]
            tank.char.stats.health.current = 999 -- survive the blast so it stays in the rebase
            -- A clean initiative ladder (all speeds 0) so the number resolution leaves is unambiguous.
            mage.initiative, other.initiative, tank.initiative = 0, 1, 9
            mage.speed, other.speed, tank.speed = 0, 0, 0
            mage.channel = { item = fireball, ab = fireball.activeAbility, tx = tank.x, ty = tank.y }
            Status.apply(c, mage, "channeling")
            openTurn(c, mage)

            local hp0 = tank.char.stats.health.current
            assert(Combat.resolveChannel(c, mage), "the channel resolves")
            assert(tank.char.stats.health.current < hp0, "the blast finally lands its damage")
            assert(mage.channel == nil, "the pending spell is cleared")
            assert(not Status.has(mage, "channeling"), "the Channeling badge is gone")
            -- endTurn charged ab.speed (4): mage 0->4, rebase by min(4,1,9)=1 -> 3. Had it (wrongly)
            -- charged the channel (2), mage would sit at 1. So 3 proves the recovery cost is speed.
            assert(mage.initiative == 3, "resolution charges ab.speed (mage at 3), not the channel wind-up")
            assert(Combat.currentUnit(c) == other, "the once-1 unit rebased to 0 and now acts")
        end,
    },
    {
        name = "a stun interrupts a channel and does not refund the committed mana",
        fn = function()
            local Status = require("models.status")
            local c = Combat.new(arena(8, 8), { unit("mage", 2, 2) }, { unit("bandit", 2, 4) })
            local mage, b1 = c.units[1], c.units[2]
            mage.char.inventory = { Item.instantiate("ability_fireball") }
            mage.initiative, b1.initiative = 0, 1
            openTurn(c, mage)

            local mana0 = poolOf(mage, "mana")
            local hp0 = b1.char.stats.health.current
            assert(Combat.useItem(c, mage, mage.char.inventory[1], b1.x, b1.y), "the channel begins")
            assert(mage.channel, "the channel is pending")
            Status.apply(c, mage, "stun")
            assert(mage.channel == nil, "the stun shatters the channel")
            assert(not Status.has(mage, "channeling"), "the Channeling badge is cleared")
            assert(poolOf(mage, "mana") == mana0 - 12, "the committed mana is NOT refunded")
            assert(not Combat.resolveChannel(c, mage), "there is nothing left to resolve")
            assert(b1.char.stats.health.current == hp0, "the spell never went off")
        end,
    },
    {
        name = "knockback interrupts a channel",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("mage", 4, 4) }, { unit("bandit", 4, 6) })
            local mage, b1 = c.units[1], c.units[2]
            mage.char.inventory = { Item.instantiate("ability_fireball") }
            mage.initiative, b1.initiative = 0, 1
            openTurn(c, mage)

            local hp0 = b1.char.stats.health.current
            assert(Combat.useItem(c, mage, mage.char.inventory[1], b1.x, b1.y), "the channel begins")
            assert(mage.channel, "the channel is pending")
            local moved = Combat.knockback(c, b1, mage, 1) -- shove the caster away from the bandit
            assert(moved >= 1, "the caster is actually shoved")
            assert(mage.channel == nil, "being knocked off balance breaks the channel")
            assert(b1.char.stats.health.current == hp0, "the spell never detonates")
        end,
    },
    {
        name = "silence interrupts a mana channel, but disarm leaves it intact",
        fn = function()
            local Status = require("models.status")
            local c = Combat.new(arena(8, 8), { unit("mage", 2, 2) }, { unit("bandit", 2, 4) })
            local mage, b1 = c.units[1], c.units[2]
            mage.char.inventory = { Item.instantiate("ability_fireball") }
            mage.initiative, b1.initiative = 0, 1
            openTurn(c, mage)
            assert(Combat.useItem(c, mage, mage.char.inventory[1], b1.x, b1.y), "the channel begins")

            -- Disarm strikes weapons from the hand; a spell is a mana ability, so the channel survives.
            Status.apply(c, mage, "disarmed")
            assert(mage.channel, "disarm leaves the spell channel intact")
            -- Silence gags the incantation: the mana channel breaks.
            Status.apply(c, mage, "silenced")
            assert(mage.channel == nil, "silence shatters the mana channel")
        end,
    },
    {
        name = "a caster cut down mid-channel drops the spell",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("mage", 2, 2) }, { unit("bandit", 2, 4) })
            local mage, b1 = c.units[1], c.units[2]
            mage.char.inventory = { Item.instantiate("ability_fireball") }
            mage.initiative, b1.initiative = 0, 1
            openTurn(c, mage)

            local hp0 = b1.char.stats.health.current
            assert(Combat.useItem(c, mage, mage.char.inventory[1], b1.x, b1.y), "the channel begins")
            assert(mage.channel, "the channel is pending")
            Combat.dealFlatDamage(c, mage, 9999, { "physical" }, "a test blow")
            assert(not mage.alive, "the caster dies")
            assert(mage.channel == nil, "the pending spell is cleared on death")
            assert(b1.char.stats.health.current == hp0, "nothing detonates from a corpse")
        end,
    },
    {
        name = "a channel whose target has left the blast resolves harmlessly",
        fn = function()
            local c = Combat.new(arena(10, 10), { unit("mage", 2, 2) }, { unit("bandit", 2, 4) })
            local mage, b1 = c.units[1], c.units[2]
            mage.char.inventory = { Item.instantiate("ability_fireball") }
            mage.initiative, b1.initiative = 0, 1
            openTurn(c, mage)
            assert(Combat.useItem(c, mage, mage.char.inventory[1], b1.x, b1.y), "the channel begins at the bandit")

            b1.x, b1.y = 9, 9 -- the bandit steps well clear of the 3x3 blast before it resolves
            local hp0 = b1.char.stats.health.current
            assert(Combat.resolveChannel(c, mage), "the channel still resolves on its stored tile")
            assert(b1.char.stats.health.current == hp0, "the foe that fled the blast takes no damage")
            assert(mage.channel == nil, "the channel is cleared")
        end,
    },
    {
        name = "an interrupted channeled consumable is still spent (committed at cast-start)",
        fn = function()
            local Status = require("models.status")
            local c = Combat.new(arena(8, 8), { unit("mage", 2, 2) }, { unit("bandit", 2, 4) })
            local mage, b1 = c.units[1], c.units[2]
            -- A hand-rolled channeled consumable (none ship in data) to exercise the consume-at-start path.
            local bomb = {
                name = "Slow Bomb", type = "consumable", quantity = 2,
                activeAbility = {
                    name = "Wind-up Bomb", target = "enemy", range = 3, channel = 2, speed = 3,
                    consumesItem = true, aoe = { radius = 1, shape = "square" },
                    effect = function(fx) for _, u in ipairs(fx.aoeUnits()) do fx.damage(u, { amount = 5 }) end end,
                },
            }
            mage.char.inventory = { bomb }
            mage.initiative, b1.initiative = 0, 1
            openTurn(c, mage)

            assert(Combat.useItem(c, mage, bomb, b1.x, b1.y), "the channel begins")
            assert(bomb.quantity == 1, "the consumable is spent at cast-start, not at resolution")
            Status.apply(c, mage, "stun")
            assert(mage.channel == nil, "the stun interrupts the channel")
            assert(bomb.quantity == 1, "the spent charge is NOT returned on interrupt")
        end,
    },
    {
        name = "Dual Wield swings two adjacent 1h weapons: both hits land, and the turn bills their summed speed",
        fn = function()
            -- Rogue at (1,1), foe adjacent at (2,1), far foe pins the rebase so the clock reads the cost.
            local c = Combat.new(arena(8, 8),
                { unit("knight", 1, 1) }, { unit("bandit", 2, 1), unit("bandit", 8, 8) })
            local rogue, bandit, far = c.units[1], c.units[2], c.units[3]

            -- Dual Wield at grid centre (5), two 1h melee weapons in the adjacent middle row (4, 6):
            -- an iron sword (speed 3) and toxic fists (speed?) that poison on hit.
            local dual = Item.instantiate("ability_dual_wield")
            rogue.char.inventory = {}
            rogue.char.inventory[5] = dual
            rogue.char.inventory[4] = Item.instantiate("iron_sword")       -- speed 3
            rogue.char.inventory[6] = Item.instantiate("homunculus_fists") -- 1h melee, poisons on hit
            local sumSpeed = rogue.char.inventory[4].activeAbility.speed
                + rogue.char.inventory[6].activeAbility.speed

            -- Pin every other unit above the billed cost so the rebase subtracts exactly rogue's
            -- action cost -- then c.clock advances by precisely the summed weapon speeds.
            rogue.initiative, bandit.initiative, far.initiative = 0, 100, 100
            rogue.char.stats.staminaRegen = 0
            -- Give the foe plenty of health so it survives the first swing -- otherwise the second
            -- weapon's on-hit (the poison) would land on a corpse and never register.
            bandit.char.stats.health.max = 999
            bandit.char.stats.health.current = 999
            local clock0 = c.clock
            local hp0 = bandit.char.stats.health.current
            openTurn(c, rogue)
            local ok, res = Combat.useItem(c, rogue, dual, bandit.x, bandit.y)
            assert(ok, "Dual Wield fires with two qualifying weapons beside it")
            assert(res.damageDealt > 0, "the flurry reports the damage it dealt")
            assert(bandit.char.stats.health.current < hp0, "the strikes land on the foe")
            -- The fists' on-hit Poison is applied through the sub-strike -- verified via the log line
            -- (the summed-speed time jump ticks the short poison off during the end-of-turn rebase, but
            -- the affliction was really applied, and the log records it).
            local poisoned = false
            for _, e in ipairs(c.log) do
                if e.kind == "status" and e.text:find("Poison") then poisoned = true break end
            end
            assert(poisoned, "the fists' on-hit effect lands through the sub-strike")
            assert(c.clock - clock0 == sumSpeed, "the turn bills the summed weapon speeds, got " .. (c.clock - clock0))
        end,
    },
    {
        name = "Dual Wield is gated: it needs two qualifying weapons, and 2h ones only count once forged to +5",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("knight", 1, 1) }, { unit("bandit", 2, 1) })
            local rogue, bandit = c.units[1], c.units[2]
            local dual = Item.instantiate("ability_dual_wield")
            rogue.char.inventory = {}
            rogue.char.inventory[5] = dual
            rogue.char.inventory[4] = Item.instantiate("iron_sword") -- one 1h weapon: not enough alone

            -- One weapon: blocked, and useItem refuses without spending anything.
            local blocked = Combat.itemBlockReason(rogue, dual)
            assert(blocked and blocked.kind == "requirement", "one weapon isn't enough to arm Dual Wield")
            openTurn(c, rogue)
            assert(Combat.useItem(c, rogue, dual, bandit.x, bandit.y) == false, "the cast is refused while under-armed")

            -- Add a 2h greataxe beside it: still blocked at +0 (2h needs +5), then allowed once forged.
            rogue.char.inventory[6] = Item.instantiate("crimson_greataxe") -- hands = 2
            assert(Combat.itemBlockReason(rogue, dual), "a 2h weapon doesn't qualify below +5")
            rogue.char.inventory[5] = Item.instantiate("ability_dual_wield", 1, 5) -- forge to +5
            assert(Combat.itemBlockReason(rogue, rogue.char.inventory[5]) == nil,
                "at +5 the 2h weapon counts, so the pair arms it")
        end,
    },
    {
        name = "Dual Wield swings a third weapon only once forged to +10",
        fn = function()
            local function armedCount(level)
                local c = Combat.new(arena(8, 8), { unit("knight", 1, 1) }, { unit("bandit", 2, 1) })
                local rogue, bandit = c.units[1], c.units[2]
                local dual = Item.instantiate("ability_dual_wield", 1, level)
                rogue.char.inventory = {}
                rogue.char.inventory[5] = dual
                -- Three 1h weapons around the centre (2, 4, 6 are all adjacent to 5).
                rogue.char.inventory[2] = Item.instantiate("iron_sword")
                rogue.char.inventory[4] = Item.instantiate("iron_sword")
                rogue.char.inventory[6] = Item.instantiate("iron_sword")
                rogue.initiative, bandit.initiative = 0, 100 -- pin the foe above the billed cost
                rogue.char.stats.staminaRegen = 0
                local clock0 = c.clock
                openTurn(c, rogue)
                assert(Combat.useItem(c, rogue, dual, bandit.x, bandit.y), "the flurry fires")
                return (c.clock - clock0) / rogue.char.inventory[2].activeAbility.speed -- swings = billed / per-sword speed
            end
            assert(armedCount(0) == 2, "at +0 the cap is two weapons")
            assert(armedCount(10) == 3, "at +10 it swings three")
        end,
    },
    {
        name = "the timeline preview reads Dual Wield's summed weapon speed, not its nominal speed",
        fn = function()
            local knight = Character.instantiate("knight")
            knight.inventory = {}
            local dual = Item.instantiate("ability_dual_wield") -- nominal speed 4
            knight.inventory[5] = dual
            knight.inventory[4] = Item.instantiate("iron_sword") -- speed 3, adjacent
            knight.inventory[6] = Item.instantiate("war_hammer") -- speed 7 but 2h: excluded at +0
            local u = { char = knight, x = 1, y = 1 }

            -- One qualifying weapon (the hammer is 2h, out at +0): not armed -> falls back to nominal.
            assert(Combat.actionSpeed(u, dual.activeAbility, dual) == dual.activeAbility.speed,
                "under-armed Dual Wield previews its nominal speed")
            -- Add a second 1h weapon: armed -> the preview is the summed weapon speeds (3 + 3), not 4.
            knight.inventory[2] = Item.instantiate("iron_sword") -- speed 3, adjacent to 5
            assert(Combat.actionSpeed(u, dual.activeAbility, dual) == 6,
                "armed Dual Wield previews the summed weapon speeds")

            -- A plain ability with no speedPreview reads its own speed.
            local sword = Item.instantiate("iron_sword")
            assert(Combat.actionSpeed(u, sword.activeAbility, sword) == sword.activeAbility.speed,
                "an ordinary ability previews its own speed")
        end,
    },
    {
        name = "Dual Wield's connector lines point only to the weapons it will swing (capped, level-gated)",
        fn = function()
            local function boostTargets(level)
                local knight = Character.instantiate("knight")
                knight.inventory = {}
                knight.inventory[5] = Item.instantiate("ability_dual_wield", 1, level)
                knight.inventory[2] = Item.instantiate("iron_sword")
                knight.inventory[4] = Item.instantiate("iron_sword")
                knight.inventory[6] = Item.instantiate("iron_sword")
                knight.inventory[8] = Item.instantiate("bow") -- ranged: never qualifies
                local to = {}
                for _, l in ipairs(Combat.adjacencyLinks(knight)) do
                    if l.from == 5 and l.kind == "boost" then to[l.to] = true end
                end
                local n = 0
                for _ in pairs(to) do n = n + 1 end
                return n, to
            end

            local n0, to0 = boostTargets(0)
            assert(n0 == 2, "at +0 exactly two weapons are linked (the cap), got " .. n0)
            assert(not to0[8], "the bow (ranged) is never linked")

            local n10, to10 = boostTargets(10)
            assert(n10 == 3, "at +10 all three swords are linked, got " .. n10)
            assert(not to10[8], "the bow is still excluded")
        end,
    },
}
