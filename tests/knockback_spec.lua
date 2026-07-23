-- Tests for forced movement (models/combat.lua): knockback shoves a unit in a straight line away
-- from its attacker and hurts everything in a collision; pull drags one adjacent along a line it
-- can see. Neither is a walk -- no move cost, no turn spent -- but both trigger whatever they are
-- dragged over. Pure logic, runs headless.

local Character = require("models.character")
local Item = require("models.item")
local Combat = require("models.combat")
local Trap = require("models.trap")
local Wall = require("models.wall")

-- A flat, all-walkable arena (mirrors tests/combat_spec.lua). `blocked` lists {x, y} cells made
-- impassable, standing in for a wall the shove can slam a unit into.
local function arena(cols, rows, blocked)
    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do
            tiles[y][x] = { type = "ground", moveCost = 1, walkable = true, sightCost = 0 }
        end
    end
    for _, b in ipairs(blocked or {}) do
        tiles[b.y][b.x] = { type = "obstacle", moveCost = 99, walkable = false, sightCost = 99 }
    end
    return { cols = cols, rows = rows, tiles = tiles, objective = { type = "killAll" } }
end

local function unit(charOrId, x, y)
    local char = type(charOrId) == "string" and Character.instantiate(charOrId) or charOrId
    return { char = char, x = x, y = y }
end

local function hp(u) return u.char.stats.health.current end

return {
    {
        name = "knockback shoves a unit straight away from its attacker",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_knight", 3, 4) }, { unit("character_bandit", 4, 4) })
            local knight, bandit = c.units[1], c.units[2]

            local moved, collided = Combat.knockback(c, knight, bandit, 2)
            assert(moved == 2, "it travels the full distance over open ground")
            assert(not collided, "nothing was in the way")
            assert(bandit.x == 6 and bandit.y == 4, "pushed two tiles along the line from the attacker")
        end,
    },
    {
        name = "a shove raises a held slide cue from the tile the target was struck on",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_knight", 3, 4) }, { unit("character_bandit", 4, 4) })
            local knight, bandit = c.units[1], c.units[2]
            Combat.knockback(c, knight, bandit, 2)

            local slide
            for _, e in ipairs(Combat.drainFx(c) or {}) do
                if e.type == "slide" and e.unit == bandit then slide = e end
            end
            assert(slide, "the view is told to glide the body, not to snap it across the lane")
            assert(slide.fromX == 4 and slide.fromY == 4, "it departs the tile the blow landed on")
            assert(slide.hold, "and waits there long enough for the damage number to read")

            -- A shove that never got going has nothing to glide.
            local c2 = Combat.new(arena(8, 8, { { x = 5, y = 4 } }),
                { unit("character_knight", 3, 4) }, { unit("character_bandit", 4, 4) })
            Combat.knockback(c2, c2.units[1], c2.units[2], 2)
            for _, e in ipairs(Combat.drainFx(c2) or {}) do
                assert(e.type ~= "slide", "blocked at the outset: the body never left its tile")
            end
        end,
    },
    {
        name = "a diagonal shove resolves onto the dominant axis (ties break toward x)",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_knight", 2, 2) }, { unit("character_bandit", 4, 3) })
            local knight, bandit = c.units[1], c.units[2]
            Combat.knockback(c, knight, bandit, 1)
            assert(bandit.x == 5 and bandit.y == 3, "dx (2) beats dy (1), so it slides along x")

            local c2 = Combat.new(arena(8, 8), { unit("character_knight", 2, 2) }, { unit("character_bandit", 3, 3) })
            Combat.knockback(c2, c2.units[1], c2.units[2], 1)
            assert(c2.units[2].x == 4 and c2.units[2].y == 3, "an exact diagonal breaks toward x")
        end,
    },
    {
        name = "a shove into a wall stops there and hurts the unit that hit it",
        fn = function()
            local c = Combat.new(arena(8, 8, { { x = 6, y = 4 } }),
                { unit("character_knight", 3, 4) }, { unit("character_bandit", 5, 4) })
            local knight, bandit = c.units[1], c.units[2]
            local before = hp(bandit)

            local moved, collided = Combat.knockback(c, knight, bandit, 3, { amount = 10 })
            assert(moved == 0 and collided, "the very first step is barred by the obstacle")
            assert(bandit.x == 5 and bandit.y == 4, "it does not move")
            assert(hp(bandit) < before, "but it takes the impact")
        end,
    },
    {
        name = "a shove off the map edge stops at the edge and deals impact damage",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_knight", 6, 4) }, { unit("character_bandit", 8, 4) })
            local knight, bandit = c.units[1], c.units[2]
            local before = hp(bandit)

            local moved, collided = Combat.knockback(c, knight, bandit, 2, { amount = 10 })
            assert(moved == 0 and collided, "the board edge bars the push")
            assert(bandit.x == 8, "it stays put")
            assert(hp(bandit) < before, "and takes the impact")
        end,
    },
    {
        name = "a shove into another unit damages BOTH of them",
        fn = function()
            local c = Combat.new(arena(8, 8),
                { unit("character_knight", 3, 4) }, { unit("character_bandit", 4, 4), unit("character_boar", 5, 4) })
            local knight, bandit, boar = c.units[1], c.units[2], c.units[3]
            local banditHP, boarHP = hp(bandit), hp(boar)

            local moved, collided = Combat.knockback(c, knight, bandit, 2, { amount = 12 })
            assert(moved == 0 and collided, "the boar blocks the first step")
            assert(bandit.x == 4, "neither unit is displaced by the collision")
            assert(boar.x == 5, "the blocker holds its ground")
            assert(hp(bandit) < banditHP, "the shoved unit takes the impact")
            assert(hp(boar) < boarHP, "and so does what it slammed into")
        end,
    },
    {
        name = "a shove denied more travel lands harder",
        fn = function()
            -- Measured on a wall rather than a body: a wall has no armor between the blow and the
            -- number, so what it loses IS the impact. One shove is stopped on its last tile of
            -- travel, the other has three tiles' worth of momentum with nowhere to put it.
            local function slam(distance)
                local c = Combat.new(arena(8, 8),
                    { unit("character_knight", 3, 4) }, { unit("character_bandit", 5, 4) })
                local wall = Wall.place(c, 6, 4, "illusory_wall", { health = 100 })
                Combat.knockback(c, c.units[1], c.units[2], distance, { amount = 10 })
                return 100 - wall.health
            end

            local spent, robbed = slam(1), slam(3)
            assert(spent == 10, "a shove with one tile left in it deals the plain amount, got " .. spent)
            assert(robbed == 20, "three tiles of denied travel double it, got " .. robbed)
        end,
    },
    {
        name = "a shove into a conjured wall tears the wall down too",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_knight", 3, 4) }, { unit("character_bandit", 5, 4) })
            local wall = Wall.place(c, 6, 4, "illusory_wall")
            assert(wall, "the wall stands in the shove's lane")
            local bandit = c.units[2]
            local before, wallHP = hp(bandit), wall.health

            local moved, collided = Combat.knockback(c, c.units[1], bandit, 2, { amount = 3 })
            assert(moved == 0 and collided, "the wall bars the very first step")
            assert(bandit.x == 5, "so the bandit does not budge")
            assert(hp(bandit) < before, "it takes the impact")
            assert(wall.health < wallHP or not wall.alive, "and the wall takes it right back")
        end,
    },
    {
        name = "a fragile unit dies to a single collision",
        fn = function()
            local c = Combat.new(arena(8, 8, { { x = 6, y = 4 } }),
                { unit("character_knight", 3, 4) }, { unit("character_bandit", 5, 4) })
            local knight, bandit = c.units[1], c.units[2]
            bandit.fragile = true

            Combat.knockback(c, knight, bandit, 1, { amount = 1 })
            assert(not bandit.alive, "any damage at all is lethal to a fragile unit")
        end,
    },
    {
        name = "a unit knocked across a trap sets it off, exactly as if it had walked",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_knight", 3, 4) }, { unit("character_bandit", 4, 4) })
            local knight, bandit = c.units[1], c.units[2]
            Trap.place(c, 5, 4, "spike_trap", "party")
            local before = hp(bandit)

            Combat.knockback(c, knight, bandit, 1)
            assert(bandit.x == 5, "it lands on the trapped tile")
            assert(hp(bandit) < before, "and the trap fires")
            assert(Trap.at(c, 5, 4) == nil, "a triggered spike trap is spent")
        end,
    },
    {
        name = "pull drags a unit to an adjacent tile, re-aiming each step",
        fn = function()
            -- A diagonal target: a fixed direction would march it past the puller along one axis.
            local c = Combat.new(arena(8, 8), { unit("character_knight", 2, 2) }, { unit("character_bandit", 5, 4) })
            local knight, bandit = c.units[1], c.units[2]

            local ok, moved = Combat.pull(c, knight, bandit)
            assert(ok, "a clear line means it can be hooked")
            local dist = math.abs(bandit.x - knight.x) + math.abs(bandit.y - knight.y)
            assert(dist == 1, "it ends up adjacent, not past the puller (got " .. dist .. ")")
            assert(moved == 4, "it crossed every tile between them but one")
        end,
    },
    {
        name = "pull needs a clear line of sight",
        fn = function()
            -- A mountain (sightCost 2) between the two blocks the line on its own.
            local a = arena(8, 8)
            a.tiles[4][4] = { type = "mountain", moveCost = 2, walkable = true, sightCost = 2 }
            local c = Combat.new(a, { unit("character_knight", 4, 3) }, { unit("character_bandit", 4, 6) })
            local knight, bandit = c.units[1], c.units[2]

            local ok, reason = Combat.pull(c, knight, bandit)
            assert(not ok and reason == "no line of sight", "you can't hook what you can't see")
            assert(bandit.y == 6, "and it hasn't budged")
        end,
    },
    {
        name = "pull stops short when a unit blocks the line",
        fn = function()
            local c = Combat.new(arena(8, 8),
                { unit("character_knight", 2, 4) }, { unit("character_boar", 4, 4), unit("character_bandit", 6, 4) })
            local knight, boar, bandit = c.units[1], c.units[2], c.units[3]

            local ok = Combat.pull(c, knight, bandit)
            assert(ok, "the line of sight is clear (units don't block sight)")
            assert(bandit.x == 5, "it is dragged up against the boar and no further")
            assert(boar.x == 4, "the blocker is unmoved")
        end,
    },
    {
        name = "the Mace hits and then drives its target back",
        fn = function()
            local knight = Character.instantiate("character_knight")
            knight.inventory = {}
            Character.addItem(knight, Item.instantiate("weapon_iron_mace"))
            local c = Combat.new(arena(8, 8), { unit(knight, 3, 4) }, { unit("character_bandit", 4, 4) })
            local ku, bandit = c.units[1], c.units[2]
            local before = hp(bandit)
            c.turn = { unit = ku, moved = false, moveCost = 0 }

            assert(Combat.useItem(c, ku, knight.inventory[1], 4, 4), "the blow lands")
            assert(hp(bandit) < before, "it hurts")
            assert(bandit.x == 6 and bandit.y == 4, "and drives the bandit two tiles back")
        end,
    },
    {
        name = "a killing Mace blow throws the body back before it drops",
        fn = function()
            local knight = Character.instantiate("character_knight")
            knight.inventory = {}
            Character.addItem(knight, Item.instantiate("weapon_iron_mace"))
            local c = Combat.new(arena(8, 8), { unit(knight, 3, 4) }, { unit("character_bandit", 4, 4) })
            local ku, bandit = c.units[1], c.units[2]
            bandit.char.stats.health.current = 1 -- the mace fells it outright
            c.turn = { unit = ku, moved = false, moveCost = 0 }

            assert(Combat.useItem(c, ku, knight.inventory[1], 4, 4), "the blow lands")
            assert(not bandit.alive, "the blow is lethal")
            assert(bandit.x == 6 and bandit.y == 4,
                "yet the shove still carried the body two tiles before it fell (x=" .. bandit.x .. ")")
        end,
    },
    {
        name = "a dying body flung into a wall slams it on the way down",
        fn = function()
            local knight = Character.instantiate("character_knight")
            knight.inventory = {}
            Character.addItem(knight, Item.instantiate("weapon_iron_mace"))
            local c = Combat.new(arena(8, 8), { unit(knight, 3, 4) }, { unit("character_bandit", 4, 4) })
            local ku, bandit = c.units[1], c.units[2]
            local wall = Wall.place(c, 5, 4, "illusory_wall", { health = 100 })
            bandit.char.stats.health.current = 1 -- the mace fells it outright
            c.turn = { unit = ku, moved = false, moveCost = 0 }

            assert(Combat.useItem(c, ku, knight.inventory[1], 4, 4), "the blow lands")
            assert(not bandit.alive, "the blow is lethal")
            assert(bandit.x == 4, "pinned against the wall, the dying body never moved")
            assert(wall.health < 100, "but the corpse-to-be slammed the wall on its way down")
        end,
    },
    {
        name = "the Pull ability refuses a target it cannot see, without spending the turn",
        fn = function()
            local knight = Character.instantiate("character_knight")
            knight.inventory = {}
            Character.addItem(knight, Item.instantiate("ability_pull"))
            local a = arena(8, 8)
            a.tiles[4][4] = { type = "mountain", moveCost = 2, walkable = true, sightCost = 2 }
            local c = Combat.new(a, { unit(knight, 4, 3) }, { unit("character_bandit", 4, 6) })
            local ku, bandit = c.units[1], c.units[2]
            c.turn = { unit = ku, moved = false, moveCost = 0 }

            local ok, reason = Combat.useItem(c, ku, knight.inventory[1], 4, 6)
            assert(not ok and reason == "no line of sight", "the cast is refused, got: " .. tostring(reason))
            assert(bandit.y == 6, "nothing moved")
            assert(c.turn ~= nil, "and the turn was never spent")
        end,
    },
}
