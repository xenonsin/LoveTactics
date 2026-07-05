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

return {
    {
        name = "initiative is the average speed of a character's ability items",
        fn = function()
            -- Knight: iron_sword (speed 3) + healing_potion (speed 2) -> (3+2)/2 = 2.5.
            local knight = Character.instantiate("knight")
            assert(Combat.initiative(knight) == 2.5, "knight initiative should be 2.5")

            -- No ability items -> DEFAULT_SPEED fallback.
            local bare = Character.instantiate("knight")
            bare.inventory = {}
            assert(Combat.initiative(bare) == Combat.DEFAULT_SPEED, "bare char -> DEFAULT_SPEED")
        end,
    },
    {
        name = "turn order is lowest-time-first, and acting re-orders the queue",
        fn = function()
            local c = Combat.new(arena(8, 8),
                { unit("knight", 4, 7) },      -- initiative 2.5
                { unit("wolf_grunt", 4, 2) })  -- fangs speed 2 -> initiative 2
            local knight, wolf = c.units[1], c.units[2]

            assert(Combat.currentUnit(c) == wolf, "faster wolf acts first")
            assert(Combat.moveUnit(c, wolf, 4, 3), "wolf steps one tile")
            assert(wolf.time == 3, "wolf pushed back to time 3")
            assert(Combat.currentUnit(c) == knight, "knight (2.5) now acts before wolf (3)")
        end,
    },
    {
        name = "moveUnit spends time equal to tiles stepped and validates reachability",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("archer", 2, 2) }, {}) -- movement 4
            local u = c.units[1]
            local t0 = u.time
            assert(Combat.moveUnit(c, u, 2, 4), "2-tile move should succeed")
            assert(u.x == 2 and u.y == 4, "position updated")
            assert(u.time == t0 + 2, "time advanced by 2 (steps)")

            -- Beyond the movement budget: unreachable.
            local far = Combat.new(arena(8, 8), { unit("archer", 1, 1) }, {})
            assert(Combat.moveUnit(far, far.units[1], 6, 6) == false, "10 tiles > movement 4")

            -- Occupied destination is rejected.
            local occ = Combat.new(arena(8, 8),
                { unit("archer", 2, 2), unit("knight", 2, 3) }, {})
            assert(Combat.moveUnit(occ, occ.units[1], 2, 3) == false, "cannot move onto a unit")
        end,
    },
    {
        name = "useItem attacks: range, resource cost, speed, and damage all apply",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("knight", 3, 3) }, { unit("bandit", 3, 4) })
            local knight, bandit = c.units[1], c.units[2]
            local sword = knight.char.inventory[1]
            assert(sword.name == "Iron Sword", "knight's first item is the sword")

            local stam0 = knight.char.stats.stamina.current
            local time0 = knight.time
            local hp0 = bandit.char.stats.health.current

            local ok, res = Combat.useItem(c, knight, sword, 3, 4)
            assert(ok, "adjacent attack should succeed")
            assert(res.damageDealt == 8, "14 dmg - 6 def = 8, got " .. res.damageDealt)
            assert(bandit.char.stats.health.current == hp0 - 8, "target lost 8 HP")
            assert(knight.char.stats.stamina.current == stam0 - 8, "stamina cost spent")
            assert(knight.time == time0 + 3, "actor pushed back by ability speed 3")

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
}
