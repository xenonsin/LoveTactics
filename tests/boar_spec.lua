-- Tests for the WILD BOAR's identity: ability_gore (the telegraphed lane charge) and weapon_tusks
-- (what it has instead of the wolves' teeth). See data/items/ability/ability_gore.lua, whose header
-- argues the shape; this pins the three claims that header makes which nothing else would catch.
--
-- The load-bearing one is the LANE. Gore aims a foe at reach but its footprint is the ground the boar
-- runs THROUGH, not a ring around the tile it aimed at -- the built-in "line" shape would paint the
-- cells BEHIND the target, which is the wrong ground and would still look plausible on screen. That is
-- exactly the kind of geometry bug that ships green, so the footprint is asserted cell by cell.

local Character = require("models.character")
local Combat = require("models.combat")
local Item = require("models.item")
local Status = require("models.status")

local function arena(cols, rows, blocked)
    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do
            tiles[y][x] = { type = "ground", moveCost = 1, walkable = true, sightCost = 0 }
        end
    end
    for _, b in ipairs(blocked or {}) do
        tiles[b.y][b.x] = { type = "mountain", moveCost = 99, walkable = false, sightCost = 99 }
    end
    return { cols = cols, rows = rows, tiles = tiles, objective = { type = "killAll" } }
end

local function unit(charOrId, x, y)
    local char = type(charOrId) == "string" and Character.instantiate(charOrId) or charOrId
    return { char = char, x = x, y = y }
end

local function openTurn(c, u) c.turn = { unit = u, moved = false, moveCost = 0 } end
local function hp(u) return u.char.stats.health.current end

-- The boar's own Gore, out of its own kit -- never a fresh instantiate, so the test casts the item the
-- blueprint actually ships (a kit that stopped carrying it would fail here rather than pass on a copy).
local function goreOf(u)
    for _, it in ipairs(Character.eachItem(u.char)) do
        if it.id == "ability_gore" then return it end
    end
end

-- Cast Gore at (tx, ty) and see the wind-up through. Returns whether the cast was accepted.
local function gore(c, boar, tx, ty)
    boar.char.stats.stamina.current = 99 -- the charge costs the whole bar; this is not what is on trial
    openTurn(c, boar)
    local ok = Combat.useItem(c, boar, goreOf(boar), tx, ty)
    if ok then Combat.resolveChannel(c, boar) end
    return ok
end

return {
    {
        name = "the boar carries its own tusks and its own charge, and no wolf's teeth",
        fn = function()
            local boar = Character.instantiate("character_boar")
            local ids = {}
            for _, it in ipairs(Character.eachItem(boar)) do ids[it.id] = true end
            assert(ids.weapon_tusks, "it gores with tusks")
            assert(ids.ability_gore, "and the charge is in the kit, not just in the folder")
            assert(not ids.weapon_fangs,
                "weapon_fangs is the wolves' blueprint (its own flavor says so) -- a boar does not bite")
        end,
    },
    {
        name = "tusks and charge are creature kit: unstealable, unpriced, on nobody's shelf",
        fn = function()
            -- docs/bestiary.md's rule, and the one that is enforced structurally rather than by rolling:
            -- creature kit carries no axis at all, so neither the drop pool nor a counter can mint it.
            for _, id in ipairs({ "weapon_tusks", "ability_gore" }) do
                local def = Item.defs[id]
                assert(def, id .. " exists")
                assert(def.class == "creature", id .. " belongs to no job")
                assert(def.noSteal, id .. " cannot be lifted off the animal")
                assert(def.price == nil, id .. " is on no shelf")
                assert(def.unlockLevel == nil, id .. " is at no depth")
            end
            -- And the retag that made the ordinary blow answerable by armour at all: nothing in the
            -- game carries a `bite` resist, so for as long as the boar bit you no coat could blunt it.
            local tags = {}
            for _, t in ipairs(Item.defs.weapon_tusks.tags or {}) do tags[t] = true end
            assert(tags.pierce, "a tusk is a point, and `pierce` is the tag a coat can answer")
            assert(not tags.bite, "it is not a bite")
        end,
    },
    {
        name = "the gore's footprint is the lane AHEAD of the boar, not a ring around what it aimed at",
        fn = function()
            -- Boar at (3,5), foe three tiles east at (6,5). The lane is (4,5) (5,5) (6,5) -- the ground
            -- the boar crosses. A `shape = "line"` AoE would have painted (6,5) (7,5) (8,5) instead:
            -- the target and the ground BEHIND it, which is not what a charge touches.
            local c = Combat.new(arena(10, 10), { unit("character_rowan", 6, 5) },
                { unit("character_boar", 3, 5) })
            local boar = c.units[2]
            local ab = goreOf(boar).activeAbility
            local cells = Combat.aoeCells(c, ab, 6, 5, boar)
            assert(#cells == 3, "three tiles of run, got " .. #cells)
            local want = { { 4, 5 }, { 5, 5 }, { 6, 5 } }
            for _, w in ipairs(want) do
                local found = false
                for _, cell in ipairs(cells) do
                    if cell.x == w[1] and cell.y == w[2] then found = true end
                end
                assert(found, "the lane covers (" .. w[1] .. "," .. w[2] .. ")")
            end
        end,
    },
    {
        name = "a foe off the line is caught by nothing, so the planner has no charge to take",
        fn = function()
            -- THE MECHANIC, stated as arithmetic. The boar charges when you are on its line and only
            -- then -- and nothing anywhere says so in words: it falls out of the footprint catching
            -- nobody, which prices the cast at zero (AI.scoreCandidate's `outcome` gate).
            local c = Combat.new(arena(10, 10), { unit("character_rowan", 6, 6) },
                { unit("character_boar", 3, 5) })
            local boar, knight = c.units[2], c.units[1]
            local ab = goreOf(boar).activeAbility
            -- Aimed at the knight, the run still goes east (the dominant axis), and he is not on it.
            local caught = Combat.aoeUnits(c, ab, knight.x, knight.y, boar)
            assert(#caught == 0, "a body one tile off the lane is caught by nothing, got " .. #caught)
        end,
    },
    {
        name = "the charge gores everything on its lane and carries the boar down it",
        fn = function()
            local c = Combat.new(arena(10, 10),
                { unit("character_rowan", 5, 5), unit("character_rowan", 6, 5) },
                { unit("character_boar", 3, 5) })
            local near, far, boar = c.units[1], c.units[2], c.units[3]
            local nb, fb = hp(near), hp(far)

            assert(gore(c, boar, 6, 5), "the charge is cast down the row")
            assert(hp(near) < nb, "the body at the near end of the lane is gored")
            assert(hp(far) < fb, "and so is the one behind it -- the lane is the whole footprint")
            assert(boar.x > 3, "and the boar is carried down the lane it ran, not left standing")
        end,
    },
    {
        name = "a run stopped by stone puts the boar on the floor; a clear run does not",
        fn = function()
            -- Nothing on the board does this. The player chose where to be standing, which is the
            -- whole counterplay the ability is built around (see its header).
            local walled = Combat.new(arena(10, 10, { { x = 4, y = 5 } }),
                { unit("character_rowan", 6, 5) }, { unit("character_boar", 3, 5) })
            local boar = walled.units[2]
            assert(gore(walled, boar, 6, 5), "it commits to the lane")
            assert(Status.has(boar, "status_stun"),
                "the run met stone at a dead run and the animal is stunned")

            local clear = Combat.new(arena(10, 10),
                { unit("character_rowan", 6, 5) }, { unit("character_boar", 3, 5) })
            local boar2 = clear.units[2]
            assert(gore(clear, boar2, 6, 5), "it commits to the same lane over open ground")
            assert(not Status.has(boar2, "status_stun"),
                "a charge that ran its full lane keeps its feet")
        end,
    },
    {
        name = "the forecast agrees with the fight about the stumble, in both directions",
        fn = function()
            -- fx.chargeTile exists for exactly this. Every dry-run context reports 0 tiles advanced, so
            -- an effect that read the collision off the rush's own return value would telegraph a
            -- stumble on every single cast -- a preview that lies on the common case. The preview and
            -- the live cast are asked the same question here and have to answer it the same way.
            local function previewStuns(blocked)
                local c = Combat.new(arena(10, 10, blocked),
                    { unit("character_rowan", 6, 5) }, { unit("character_boar", 3, 5) })
                local boar = c.units[2]
                boar.char.stats.stamina.current = 99
                local p = Combat.previewAbility(c, boar, goreOf(boar), 6, 5)
                for _, e in ipairs(p and p.order or {}) do
                    if e.unit == boar then
                        for _, s in ipairs(e.statuses or {}) do
                            if s.id == "status_stun" then return true end
                        end
                    end
                end
                return false
            end
            assert(previewStuns({ { x = 4, y = 5 } }),
                "with stone in the lane the forecast says the boar will stumble")
            assert(not previewStuns(nil),
                "over open ground it does not -- which is the case that would have lied")
        end,
    },
}
