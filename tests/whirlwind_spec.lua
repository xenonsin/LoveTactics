-- Tests for the WHIRLWIND (data/items/ability/ability_whirlwind.lua): the Whirl Elemental's rush to a
-- tile the wind picks. The header makes four claims a board can check -- the footprint is every tile
-- the draw could land on, the lane is cut friend and foe, a taken landing throws its occupant, and a
-- landing that will not clear drops the caster short -- and one about the item: it is the body's own
-- trophy, dealt by no counter, while the body itself casts a natural copy of it (weapon_gyre).
--
-- The pick and the throw are fx.random draws, so every board here pins Combat.random for the cast and
-- answers by the size of the draw: the footprint's count is the pick, four is the throw's direction,
-- and anything else (an accuracy roll) is 1.

local Character = require("models.character")
local Combat = require("models.combat")
local Item = require("models.item")
local Vendor = require("models.vendor")

local function arena(cols, rows, blocked)
    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do
            tiles[y][x] = { type = "ground", moveCost = 1, walkable = true, sightCost = 0 }
        end
    end
    for _, b in ipairs(blocked or {}) do
        tiles[b[2]][b[1]] = { type = "mountain", moveCost = 99, walkable = false, sightCost = 99 }
    end
    return { cols = cols, rows = rows, tiles = tiles, objective = { type = "killAll" } }
end

local function unit(id, x, y) return { char = Character.instantiate(id), x = x, y = y } end
local function hp(u) return u.char.stats.health.current end

local function gyreOf(u)
    for _, it in ipairs(Character.eachItem(u.char)) do
        if it.id == "weapon_gyre" then return it end
    end
end

-- Cast the elemental's own copy (weapon_gyre, the Whirlwind's effect borrowed whole) with the draw
-- pinned: `pick` indexes the footprint (in the order Combat.aoeCells hands it back -- east's ray first,
-- nearest tile first), `throw` indexes the four ways.
local function whirl(c, caster, pick, throw)
    local cells = Combat.aoeCells(c, gyreOf(caster).activeAbility, caster.x, caster.y, caster)
    local saved = Combat.random
    Combat.random = function(n)
        if n == #cells then return pick end
        if n == 4 then return throw or 1 end
        return 1
    end
    caster.char.stats.stamina.current = 99
    c.turn = { unit = caster, moved = false, moveCost = 0 }
    local ok, err = pcall(Combat.useItem, c, caster, gyreOf(caster), caster.x, caster.y)
    Combat.random = saved
    assert(ok, err)
end

return {
    {
        name = "the whirlwind's footprint is the eight rays out of the caster, cut at the first wall",
        fn = function()
            local c = Combat.new(arena(12, 12, { { 8, 6 } }), { unit("character_rowan", 1, 1) },
                { unit("character_whirl_elemental", 6, 6) })
            local w = c.units[2]
            local cells = Combat.aoeCells(c, gyreOf(w).activeAbility, w.x, w.y, w)
            -- Eight rays of four, less the east ray's last three: (8,6) is stone, so (7,6) is all of it.
            assert(#cells == 29, "29 tiles the wind could land on, got " .. #cells)
            for _, cell in ipairs(cells) do
                assert(not (cell.x == 6 and cell.y == 6), "never the caster's own tile")
                assert(cell.x < 8 or cell.y ~= 6, "nothing past the stone on the east ray")
                local dx, dy = cell.x - 6, cell.y - 6
                assert(dx == 0 or dy == 0 or math.abs(dx) == math.abs(dy), "every tile is on a straight line")
            end
        end,
    },
    {
        name = "it rushes to the picked tile, cutting everyone it passes over -- its own side too",
        fn = function()
            -- East ray: (7,6) (8,6) (9,6) (10,6). Pick 4 lands it on (10,6); a foe and an ally stand in the lane.
            local c = Combat.new(arena(12, 12), { unit("character_rowan", 8, 6) },
                { unit("character_whirl_elemental", 6, 6), unit("character_fire_elemental", 7, 6) })
            local foe, w, mate = c.units[1], c.units[2], c.units[3]
            local foeHp, mateHp = hp(foe), hp(mate)
            whirl(c, w, 4)
            assert(w.x == 10 and w.y == 6, "it lands on the picked tile, at (" .. w.x .. "," .. w.y .. ")")
            assert(hp(foe) < foeHp, "the foe in the lane is cut")
            assert(hp(mate) < mateHp, "and so is the ally: the wind does not choose")
            assert(foe.x == 8 and mate.x == 7, "bodies it passes over stay where they stood")
        end,
    },
    {
        name = "a taken landing throws its occupant a tile in the drawn direction, and the rush takes the tile",
        fn = function()
            local c = Combat.new(arena(12, 12), { unit("character_rowan", 10, 6) },
                { unit("character_whirl_elemental", 6, 6) })
            local foe, w = c.units[1], c.units[2]
            local before = hp(foe)
            whirl(c, w, 4, 3) -- the third way is south: (10,6) -> (10,7)
            assert(foe.x == 10 and foe.y == 7, "thrown south to (10,7), at (" .. foe.x .. "," .. foe.y .. ")")
            assert(w.x == 10 and w.y == 6, "and the whirlwind comes down where it stood")
            assert(hp(foe) < before, "the occupant is in the lane, so it is cut as well")
        end,
    },
    {
        name = "a landing that will not clear drops the caster on the last open tile short of it",
        fn = function()
            -- The occupant of (10,6) is thrown east into stone at (11,6): it stays, and the rush stops at (9,6).
            local c = Combat.new(arena(12, 12, { { 11, 6 } }), { unit("character_rowan", 10, 6) },
                { unit("character_whirl_elemental", 6, 6) })
            local foe, w = c.units[1], c.units[2]
            whirl(c, w, 4, 1)
            assert(foe.x == 10 and foe.y == 6, "the throw hits stone and goes nowhere")
            assert(w.x == 9 and w.y == 6, "the whirlwind comes down short, at (" .. w.x .. "," .. w.y .. ")")
        end,
    },
    {
        name = "the elemental casts the Gyre and drops the Whirlwind, and no counter deals either",
        fn = function()
            local def = Item.defs.ability_whirlwind
            assert(def and def.type == "ability", "the trophy exists and is an ability")
            assert(def.unstocked, "unstocked: a counter never deals it")
            assert(Vendor.foundPrice(def) == nil, "so no counter prices it in either direction")
            local gyre = Item.defs.weapon_gyre
            assert(gyre.class == "creature" and gyre.noSteal and not gyre.price,
                "the body's own copy is creature kit: unshelved, unpriced, unstealable")
            assert(gyre.activeAbility.effect == def.activeAbility.effect,
                "and it is the same cast, not a second one that can drift")
            local bp = Character.defs.character_whirl_elemental
            local carried, dropped = false, false
            for _, id in ipairs(bp.startingItems) do if id == "weapon_gyre" then carried = true end end
            for _, id in ipairs(bp.drops) do if id == "ability_whirlwind" then dropped = true end end
            assert(carried, "the elemental casts the Gyre")
            assert(dropped, "and drops the Whirlwind")
        end,
    },
}
