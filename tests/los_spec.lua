-- Tests for line of sight (models/combat.lua): the terrain-summed hasLineOfSight geometry, and
-- the gating it drives on sight-requiring (`ab.requiresSight`) abilities -- Combat.useItem,
-- Combat.abilityTargets, Combat.attackReach, and the enemy AI's ranged planning. Pure logic,
-- headless. Mirrors the arena tile shape ({ type, moveCost, walkable, sightCost }).

local Character = require("models.character")
local Item = require("models.item")
local Combat = require("models.combat")

-- Flat all-ground arena; `cover` is a list of { x, y, sightCost, walkable, moveCost } overrides
-- so a test can drop soft/hard cover onto individual tiles. sightCost defaults to 0 (transparent).
local function arena(cols, rows, cover)
    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do
            tiles[y][x] = { type = "ground", moveCost = 1, walkable = true, sightCost = 0 }
        end
    end
    for _, c in ipairs(cover or {}) do
        local t = tiles[c.y][c.x]
        t.sightCost = c.sightCost or 0
        if c.walkable ~= nil then t.walkable = c.walkable end
        if c.moveCost then t.moveCost = c.moveCost end
    end
    return { cols = cols, rows = rows, tiles = tiles, objective = { type = "killAll" } }
end

local function unit(charOrId, x, y)
    local char = type(charOrId) == "string" and Character.instantiate(charOrId) or charOrId
    -- Isolate from innate traits (see tests/innate_spec.lua): a lone archer would otherwise field a
    -- wolf and change what these line-of-sight fixtures put on the board.
    char.traits = {}
    return { char = char, x = x, y = y }
end

local function openTurn(c, u)
    c.turn = { unit = u, moved = false, moveCost = 0 }
end

-- The item in `char`'s inventory with the given id.
local function itemById(char, id)
    for _, it in ipairs(char.inventory) do
        if it.id == id then return it end
    end
end

local WALL = math.huge -- solid cover: sightCost that blocks a line on its own

return {
    {
        name = "line of sight is clear across open ground and blocked by solid cover (both ways)",
        fn = function()
            local open = Combat.new(arena(6, 1), {}, {})
            assert(Combat.hasLineOfSight(open, 1, 1, 6, 1), "open ground has a clear line")

            -- A single solid tile between the endpoints seals the line, in either direction.
            local walled = Combat.new(arena(6, 1, { { x = 3, y = 1, sightCost = WALL } }), {}, {})
            assert(not Combat.hasLineOfSight(walled, 1, 1, 6, 1), "solid cover blocks the line")
            assert(not Combat.hasLineOfSight(walled, 6, 1, 1, 1), "and it blocks the reverse too")
        end,
    },
    {
        name = "soft cover only lowers sight: one copse is see-through, two stacked block",
        fn = function()
            -- forest sightCost 1 < SIGHT_BLOCK (2): a lone copse still lets a line through.
            local one = Combat.new(arena(6, 1, { { x = 3, y = 1, sightCost = 1 } }), {}, {})
            assert(Combat.hasLineOfSight(one, 1, 1, 5, 1), "one forest tile does not block")

            -- Two forest tiles in the line sum to 2 -> blocked.
            local two = Combat.new(arena(6, 1,
                { { x = 3, y = 1, sightCost = 1 }, { x = 4, y = 1, sightCost = 1 } }), {}, {})
            assert(not Combat.hasLineOfSight(two, 1, 1, 6, 1), "two stacked forests block")

            -- A single mountain (sightCost 2) reaches the threshold on its own.
            local mtn = Combat.new(arena(6, 1, { { x = 3, y = 1, sightCost = 2 } }), {}, {})
            assert(not Combat.hasLineOfSight(mtn, 1, 1, 5, 1), "a lone mountain blocks the line")
        end,
    },
    {
        name = "endpoints never block: cover on the shooter's or target's own tile is ignored",
        fn = function()
            local c = Combat.new(arena(6, 1,
                { { x = 1, y = 1, sightCost = WALL }, { x = 6, y = 1, sightCost = WALL } }), {}, {})
            assert(Combat.hasLineOfSight(c, 1, 1, 6, 1),
                "solid terrain ON the endpoints does not obstruct their own line")
        end,
    },
    {
        name = "a diagonal line is blocked by cover sitting on it",
        fn = function()
            local open = Combat.new(arena(4, 4), {}, {})
            assert(Combat.hasLineOfSight(open, 1, 1, 3, 3), "open diagonal is clear")
            local blocked = Combat.new(arena(4, 4, { { x = 2, y = 2, sightCost = WALL } }), {}, {})
            assert(not Combat.hasLineOfSight(blocked, 1, 1, 3, 3), "a blocker on the diagonal blocks it")
        end,
    },
    {
        name = "a ranged attack is refused without line of sight and lands once the line is clear",
        fn = function()
            -- Archer's default weapon is the bow (range 3, requiresSight). Foe 3 tiles away with a
            -- wall between them: the shot is refused with a line-of-sight reason.
            local walled = Combat.new(arena(6, 1, { { x = 3, y = 1, sightCost = WALL, walkable = false } }),
                { unit("archer", 1, 1) }, { unit("bandit", 4, 1) })
            local archer = walled.units[1]
            local bow = itemById(archer.char, "bow")
            openTurn(walled, archer)
            local ok, reason = Combat.useItem(walled, archer, bow, 4, 1)
            assert(not ok and reason == "no line of sight", "blocked shot refused: " .. tostring(reason))

            -- Same geometry with the lane open: the arrow lands.
            local open = Combat.new(arena(6, 1), { unit("archer", 1, 1) }, { unit("bandit", 4, 1) })
            local a2 = open.units[1]
            openTurn(open, a2)
            local hp0 = open.units[2].char.stats.health.current
            local ok2, res = Combat.useItem(open, a2, itemById(a2.char, "bow"), 4, 1)
            assert(ok2, "a clear-line shot succeeds")
            assert(res.damageDealt > 0 and open.units[2].char.stats.health.current < hp0,
                "the target took damage")
        end,
    },
    {
        name = "abilityTargets drops a foe hidden behind cover, and lists it once the line clears",
        fn = function()
            -- Mage's Fireball (range 3, requiresSight). Foe within range but behind a wall.
            local walled = Combat.new(arena(6, 1, { { x = 3, y = 1, sightCost = WALL } }),
                { unit("mage", 1, 1) }, { unit("bandit", 4, 1) })
            local mage, foe = walled.units[1], walled.units[2]
            local fireball = itemById(mage.char, "ability_fireball")
            local targets = Combat.abilityTargets(walled, mage, fireball)
            assert(#targets == 0, "a foe with no clear line is not a valid target")

            local open = Combat.new(arena(6, 1), { unit("mage", 1, 1) }, { unit("bandit", 4, 1) })
            local m2 = open.units[1]
            local seen = Combat.abilityTargets(open, m2, itemById(m2.char, "ability_fireball"))
            assert(#seen == 1 and seen[1] == open.units[2], "with a clear line the foe is targetable")
        end,
    },
    {
        name = "attackReach with requiresSight stops at cover; without it the reach ignores sight",
        fn = function()
            -- Archer at (1,1), bow range 3, wall at (3,1). Pass an empty reachable set so the reach
            -- is measured only from the origin tile (isolating sight from movement).
            local c = Combat.new(arena(6, 1, { { x = 3, y = 1, sightCost = WALL, walkable = false } }),
                { unit("archer", 1, 1) }, {})
            local archer = c.units[1]

            local sighted = Combat.attackReach(c, archer, 3, {}, true)
            assert(sighted["2,1"], "an open cell in front of the wall is reachable")
            assert(sighted["4,1"] == nil, "a cell behind the wall is dropped from the sighted reach")

            -- Same call without the sight flag: the geometric reach ignores cover.
            local blind = Combat.attackReach(c, archer, 3, {}, false)
            assert(blind["4,1"], "a plain reach still lists the cell behind the wall")
        end,
    },
    {
        name = "attackReach never lists an impassable tile (no target can stand on a wall)",
        fn = function()
            -- A solid obstacle beside the unit: within range and adjacent (clear line), but nothing
            -- can ever stand there, so it must be absent from the reach -- no red highlight, and
            -- click-to-attack can't target it. The open tile past it (in range) still lists.
            local c = Combat.new(arena(4, 1, { { x = 2, y = 1, sightCost = WALL, walkable = false } }),
                { unit("knight", 1, 1) }, {})
            local ar = Combat.attackReach(c, c.units[1], 2, {}, false)
            assert(ar["1,1"], "the unit's own (walkable) tile stays in reach")
            assert(ar["2,1"] == nil, "the adjacent impassable obstacle is excluded from reach")
            assert(ar["3,1"], "a walkable tile within range beyond the obstacle still lists")
        end,
    },
    {
        name = "the enemy AI won't fire through a wall: it repositions instead of shooting blind",
        fn = function()
            -- A bow-only enemy (strip the archer's trap kit so the plan hinges on the ranged shot).
            local function bowman(x, y)
                local c = Character.instantiate("archer")
                c.inventory = { itemById(c, "bow") }
                return unit(c, x, y)
            end

            -- Enemy at (1,1), party at (4,1), a wall between them on a single-row arena so it can't
            -- flank. It must NOT plan a blocked shot; it steps closer to open a line instead.
            local walled = Combat.new(arena(6, 1, { { x = 3, y = 1, sightCost = WALL, walkable = false } }),
                { unit("knight", 4, 1) }, { bowman(1, 1) })
            local plan = Combat.planEnemyAction(walled, walled.units[2])
            assert(not plan.item, "the archer does not fire through the wall")
            assert(plan.move and plan.move.x == 2, "it advances toward the target to seek a line")

            -- Clear the lane: now the very same archer opens with a shot from range.
            local open = Combat.new(arena(6, 1), { unit("knight", 4, 1) }, { bowman(1, 1) })
            local shot = Combat.planEnemyAction(open, open.units[2])
            assert(shot.item and shot.tx == 4 and shot.ty == 1, "with a clear line it shoots in place")
        end,
    },
}
