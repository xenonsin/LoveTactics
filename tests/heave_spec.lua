-- Tests for Heave, the two-stage throw (data/items/ability/ability_heave.lua): grab an adjacent
-- target, THEN choose where it lands. The chosen landing rides in as `opts.dest` on the lane helpers
-- (Combat.knockback / Combat.hurlObject / Combat.knockbackTile) and as the trailing `dest` arg on
-- Combat.useItem -- aiming the throw toward that tile and capping its travel there, instead of the old
-- fixed straight-away-from-the-thrower push. With no dest it falls back to exactly that old push, which
-- is the path an AI cast (the Demon Champion's Bomblet lob) still takes. Pure logic, runs headless.

local Character = require("models.character")
local Item = require("models.item")
local Combat = require("models.combat")
local Command = require("models.command")
local Trap = require("models.trap")
local Wall = require("models.wall")
local Prop = require("models.prop")

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

-- A caster carrying only Heave, its turn open. Returns (combat, caster).
local function heaver(a, cx, cy, enemies)
    local knight = Character.instantiate("character_rowan")
    knight.inventory = {}
    Character.addItem(knight, Item.instantiate("ability_heave"))
    local c = Combat.new(a, { unit(knight, cx, cy) }, enemies or { unit("character_bandit", 1, 1) })
    local ku = c.units[1]
    c.turn = { unit = ku, moved = false, moveCost = 0 }
    return c, ku, ku.char.inventory[1]
end

return {
    {
        name = "Item.isThrow tags a two-stage throw, and only that",
        fn = function()
            local heave = Item.instantiate("ability_heave")
            local push = Item.instantiate("ability_push")
            assert(Item.isThrow(heave.activeAbility), "Heave is a two-stage throw")
            assert(not Item.isThrow(push.activeAbility), "the single-click Push is not")
            assert(not Item.isThrow(nil), "a nil ability is not a throw")
        end,
    },
    {
        name = "opts.dest aims a knockback toward the chosen tile, not away from the source",
        fn = function()
            -- Thrower WEST of the body; a plain shove would drive it further east. Aimed NORTH instead,
            -- the body travels north -- proof the landing is chosen, not dictated by the thrower.
            local c = Combat.new(arena(10, 10), { unit("character_rowan", 3, 5) }, { unit("character_bandit", 4, 5) })
            local knight, bandit = c.units[1], c.units[2]
            local moved, collided = Combat.knockback(c, knight, bandit, 3, { dest = { x = 4, y = 2 } })
            assert(not collided, "the lane to the aimed tile is clear")
            assert(bandit.x == 4 and bandit.y == 2, "it lands on the aimed tile, north of where it stood")
            assert(moved == 3, "it travelled the Chebyshev distance to the landing")
        end,
    },
    {
        name = "an aimed throw stopped short of its landing slams at the blocker",
        fn = function()
            -- Aim past a wall: the throw walks the lane toward the far tile and slams into the wall it
            -- meets first, hurting both ends -- the same collision rule the fixed push obeys.
            local c = Combat.new(arena(10, 10, { { x = 6, y = 5 } }),
                { unit("character_rowan", 3, 5) }, { unit("character_bandit", 4, 5) })
            local knight, bandit = c.units[1], c.units[2]
            local before = hp(bandit)
            local moved, collided = Combat.knockback(c, knight, bandit, 3, { dest = { x = 7, y = 5 }, amount = 10 })
            assert(collided, "the wall bars the lane short of the aimed tile")
            assert(bandit.x == 5 and bandit.y == 5, "it comes to rest against the wall")
            assert(moved == 1, "one tile of travel before the slam")
            assert(hp(bandit) < before, "and it takes the impact")
        end,
    },
    {
        name = "Combat.knockbackTile previews the aimed landing (opts.dest)",
        fn = function()
            local c = Combat.new(arena(10, 10), { unit("character_rowan", 3, 5) }, { unit("character_bandit", 4, 5) })
            local knight, bandit = c.units[1], c.units[2]
            local rx, ry = Combat.knockbackTile(c, knight, bandit, 3, { dest = { x = 4, y = 2 } })
            assert(rx == 4 and ry == 2, "the ghost rests where the live aimed throw will")
            assert(bandit.x == 4 and bandit.y == 5, "and it is pure -- nothing actually moved")
        end,
    },
    {
        name = "hurlObject honours opts.dest, throwing a prop to the aimed landing",
        fn = function()
            -- The lane is a straight cardinal line (signDominant collapses any aim onto its dominant
            -- axis), so a landing off to the south is reached down the y-axis.
            local c = Combat.new(arena(10, 10), { unit("character_rowan", 5, 4) }, { unit("character_bandit", 1, 1) })
            local knight = c.units[1]
            local crate = Prop.place(c, 5, 5, "prop_crate") -- adjacent, south of the thrower
            local moved, collided = Combat.hurlObject(c, knight, crate, "prop", 3, { dest = { x = 5, y = 7 } })
            assert(not collided, "the lane to the aimed tile is clear")
            assert(crate.alive and crate.x == 5 and crate.y == 7, "the crate lands on the aimed tile")
            assert(moved == 2, "two tiles down the lane to the landing")
        end,
    },
    {
        name = "Heave throws a grabbed body to the aimed landing (not a push away)",
        fn = function()
            local c, ku, heave = heaver(arena(10, 10), 3, 5,
                { unit("character_bandit", 4, 5) }) -- adjacent, east
            local bandit = c.units[2]
            -- Grab the adjacent body (4,5), aim the landing NORTH at (4,2).
            assert(Combat.useItem(c, ku, heave, 4, 5, nil, { x = 4, y = 2 }), "grab east, throw north")
            assert(bandit.x == 4 and bandit.y == 2, "the body lands where aimed, not flung east away from the thrower")
        end,
    },
    {
        name = "Heave throws a grabbed prop to the aimed landing",
        fn = function()
            local c, ku, heave = heaver(arena(10, 10), 4, 5)
            local crate = Prop.place(c, 5, 5, "prop_crate") -- adjacent, east
            assert(Combat.useItem(c, ku, heave, 5, 5, nil, { x = 5, y = 8 }), "grab east, throw south")
            assert(crate.alive and crate.x == 5 and crate.y == 8, "the crate lands where aimed")
        end,
    },
    {
        name = "Heave with no landing falls back to the old push -- straight away, throwRange tiles",
        fn = function()
            -- The AI / legacy path: no dest supplied. The throw reverts to the fixed direction (away from
            -- the thrower) and the ability's throwRange -- exactly what the Demon Champion's Bomblet lob does.
            local c, ku, heave = heaver(arena(12, 12), 3, 5,
                { unit("character_bandit", 4, 5) }) -- adjacent, east
            local bandit = c.units[2]
            local reach = heave.activeAbility.throwRange
            assert(reach == 3, "the fallback distance is the ability's throwRange")
            assert(Combat.useItem(c, ku, heave, 4, 5), "no dest -> fling away")
            assert(bandit.x == 4 + reach and bandit.y == 5,
                "the body is flung straight east, throwRange tiles from where it stood")
        end,
    },
    {
        name = "a use command round-trips its throw landing as dx,dy",
        fn = function()
            -- The wire shape: tx,ty is the GRABBED tile; dx,dy the destination. Both validate as whole
            -- coords and apply to the same aimed throw the local path takes.
            local a = arena(10, 10)
            local knight = Character.instantiate("character_rowan")
            knight.inventory = {}
            Character.addItem(knight, Item.instantiate("ability_heave"))
            local c = Combat.new(a, { unit(knight, 3, 5) }, { unit("character_bandit", 4, 5) })
            local ku, bandit = c.units[1], c.units[2]
            c.turn = { unit = ku, moved = false, moveCost = 0 }

            local cmd = { kind = "use", cell = 1, tx = 4, ty = 5, dx = 4, dy = 2 }
            assert(Command.wellFormed(cmd), "a grab+landing use command is well-formed")
            assert(not Command.wellFormed({ kind = "use", cell = 1, tx = 4, ty = 5, dx = 4 }),
                "a lone dx without dy is rejected")

            local result = Command.apply(c, ku, cmd)
            assert(result and result.acted, "the command resolves the throw")
            assert(bandit.x == 4 and bandit.y == 2, "and lands the body on the aimed tile")
        end,
    },
    {
        name = "a thrown body still springs a trap it is aimed onto",
        fn = function()
            local c, ku, heave = heaver(arena(10, 10), 3, 5,
                { unit("character_bandit", 4, 5) })
            local bandit = c.units[2]
            Trap.place(c, 4, 3, "spike_trap", "party") -- two tiles north of the grabbed body
            local before = hp(bandit)
            assert(Combat.useItem(c, ku, heave, 4, 5, nil, { x = 4, y = 3 }), "throw the body onto the trap")
            assert(bandit.x == 4 and bandit.y == 3, "it lands on the trapped tile")
            assert(hp(bandit) < before, "and the trap fires on arrival")
            assert(Trap.at(c, 4, 3) == nil, "the spike trap is spent")
        end,
    },
}
