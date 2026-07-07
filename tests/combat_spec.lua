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
    return { char = char, x = x, y = y }
end

-- Open a turn for a specific unit, independent of initiative order, so a test can exercise
-- moveUnit/endTurn on the unit it cares about (mirrors what Combat.startTurn sets up).
local function openTurn(c, u)
    c.turn = { unit = u, moved = false, moveCost = 0 }
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
        name = "useItem attacks: range, resource cost, speed, and damage all apply",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("knight", 3, 3) }, { unit("bandit", 3, 4) })
            local knight, bandit = c.units[1], c.units[2]
            knight.initiative, bandit.initiative = 0, 100 -- keep bandit far so the cost shows as elapsed
            local sword = knight.char.inventory[1]
            assert(sword.name == "Iron Sword", "knight's first item is the sword")

            local stam0 = knight.char.stats.stamina.current
            local clock0 = c.clock
            local hp0 = bandit.char.stats.health.current

            local ok, res = Combat.useItem(c, knight, sword, 3, 4)
            assert(ok, "adjacent attack should succeed")
            assert(res.damageDealt == 8, "14 dmg - 6 def = 8, got " .. res.damageDealt)
            assert(bandit.char.stats.health.current == hp0 - 8, "target lost 8 HP")
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
        name = "a consumable is removed from inventory after use, and heals its target",
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
            assert(#mage.char.inventory == invBefore - 1, "consumable removed from inventory")
        end,
    },
    {
        name = "dealDamage floors at 1 and applyHeal caps at max",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("mage", 1, 1) }, { unit("warlord", 1, 2) })
            local sword = Item.instantiate("iron_sword")
            -- Mage damage 5 (physical) vs warlord defense 16 -> would be negative, floored to 1.
            local d = Combat.dealDamage(c, c.units[1], c.units[2], sword, { power = 1.0 })
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
            local gem = Item.instantiate("flame_gem") -- tags { fire, magical }
            local dm = Combat.dealDamage(mc, mc.units[1], mc.units[2], gem, {})
            assert(dm == 15, "18 magicDmg - 3 magicDef = 15, got " .. dm)

            -- Leather armor: +4 defense and tag resist { slash = 3, physical = 2 }. A slash
            -- weapon is mitigated more than a same-power pierce weapon, isolating the tag match.
            local armored = Character.instantiate("bandit") -- base defense 6, health 60
            assert(Character.addItem(armored, Item.instantiate("leather_armor")), "equip armor")
            local ac = Combat.new(arena(8, 8), { unit("warlord", 1, 1) }, { unit(armored, 1, 2) })
            local attacker, defender = ac.units[1], ac.units[2] -- warlord damage 28
            local sword = Item.instantiate("iron_sword") -- tags { sword, slash, physical }
            local bow = Item.instantiate("bow")          -- tags { bow, pierce, physical }

            local dSlash = Combat.dealDamage(ac, attacker, defender, sword, {})
            defender.char.stats.health.current = defender.char.stats.health.max -- reset for a clean 2nd hit
            local dPierce = Combat.dealDamage(ac, attacker, defender, bow, {})
            assert(dSlash == 13, "28 - (6+4) def - (3 slash + 2 physical) = 13, got " .. dSlash)
            assert(dPierce == 16, "28 - (6+4) def - (2 physical only) = 16, got " .. dPierce)
            assert(dSlash < dPierce, "slash-resisting armor mitigates the sword more than the bow")

            -- No armor: full stat-vs-defense with no mitigation.
            local uc = Combat.new(arena(8, 8), { unit("knight", 1, 1) }, { unit("bandit", 1, 2) })
            local du = Combat.dealDamage(uc, uc.units[1], uc.units[2], uc.units[1].char.inventory[1], {})
            assert(du == 8, "un-resisted attack does full 14 - 6 = 8, got " .. du)
        end,
    },
    {
        name = "an effect function composes helpers (damage + lifesteal heal)",
        fn = function()
            local wand = {
                name = "Draining Wand", tags = { "arcane", "magical" },
                activeAbility = {
                    name = "Drain", target = "enemy", range = 3, speed = 3,
                    effect = function(fx)
                        local dealt = fx.damage(fx.target, { power = 1.0 })
                        fx.heal(fx.user, dealt) -- lifesteal the amount dealt
                    end,
                },
            }
            local c = Combat.new(arena(8, 8), { unit("mage", 2, 2) }, { unit("bandit", 2, 3) })
            local mage = c.units[1]
            mage.char.stats.health.current = 40
            local ok, res = Combat.useItem(c, mage, wand, 2, 3)
            assert(ok, "ranged drain should succeed")
            assert(res.damageDealt == 15, "18 magicDmg - 3 magicDef = 15")
            assert(res.healed == 15, "lifesteal heals the amount dealt")
            assert(mage.char.stats.health.current == 55, "40 + 15 = 55")
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
            -- 5x1 corridor: ground, forest(2), ground, ground, ground; archer has movement 4.
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
            assert(r["4,1"] and r["4,1"].cost == 4, "path through the forest costs 4 of the budget")
            assert(r["5,1"] == nil, "the forest cost puts the far end out of a movement-4 reach")

            assert(Combat.moveUnit(c, u, 4, 1), "move across the forest to x=4")
            Combat.pass(c, u) -- sole unit rebases back to 0; the cost 4 shows on the clock
            assert(c.clock == 4, "move time is the terrain-weighted cost 4, not the 3 tiles")
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
}
