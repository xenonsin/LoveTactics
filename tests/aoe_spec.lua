-- Tests for area-of-effect abilities (models/combat.lua: Combat.aoeCells / Combat.aoeUnits and the
-- fx.aoeUnits helper an AoE effect sweeps with). Fireball is the worked example: a radius-1 square
-- burst (corners included) that damages every unit caught in the footprint. Pure logic, so headless.

local Character = require("models.character")
local Combat = require("models.combat")

local function arena(cols, rows)
    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do
            tiles[y][x] = { type = "ground", moveCost = 1, walkable = true, sightCost = 0 }
        end
    end
    return { cols = cols, rows = rows, tiles = tiles, objective = { type = "killAll" } }
end

local function unit(id, x, y) return { char = Character.instantiate(id), x = x, y = y } end

-- The fireball item on a freshly built mage (its inventory carries it by blueprint).
local function fireballOf(mage)
    for _, it in ipairs(mage.char.inventory) do
        if it.activeAbility and it.activeAbility.name == "Fireball" then return it end
    end
end

return {
    {
        name = "aoeCells is a 3x3 square (corners included) and clamps to the arena bounds",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("mage", 2, 2) }, { unit("bandit", 5, 5) })
            local ab = fireballOf(c.units[1]).activeAbility

            local cells = Combat.aoeCells(c, ab, 5, 5)
            assert(#cells == 9, "radius-1 square is 9 cells, got " .. #cells)
            local corner = false
            for _, cc in ipairs(cells) do if cc.x == 6 and cc.y == 6 then corner = true end end
            assert(corner, "the (6,6) corner is part of the square burst")

            -- A burst centred at the corner (1,1) keeps only its 4 in-bounds cells.
            assert(#Combat.aoeCells(c, ab, 1, 1) == 4, "footprint clamps to the arena edge")
        end,
    },
    {
        name = "a single-target ability (no aoe) covers only the target cell",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("mage", 2, 2) }, { unit("bandit", 5, 5) })
            local jolt
            for _, it in ipairs(c.units[1].char.inventory) do
                if it.activeAbility and it.activeAbility.name == "Jolt" then jolt = it end
            end
            local cells = Combat.aoeCells(c, jolt.activeAbility, 3, 3)
            assert(#cells == 1 and cells[1].x == 3 and cells[1].y == 3, "no aoe -> just the cell")
        end,
    },
    {
        name = "fireball sweeps every unit in the blast (friendly fire included)",
        fn = function()
            -- Three foes clustered so a burst at (5,5) catches an edge and a corner too, plus an
            -- ally standing in the blast to prove friendly fire.
            local c = Combat.new(arena(8, 8),
                { unit("mage", 5, 3), unit("knight", 4, 4) },
                { unit("bandit", 5, 5), unit("bandit", 6, 6), unit("bandit", 4, 5) })
            local mage = c.units[1]
            local fireball = fireballOf(mage)

            local swept = Combat.aoeUnits(c, fireball.activeAbility, 5, 5)
            assert(#swept == 4, "3 bandits + the knight ally in range, got " .. #swept)

            -- previewAbility replays the effect, so it reports the same four.
            local prev = Combat.previewAbility(c, mage, fireball, 5, 5)
            assert(#prev.order == 4, "preview reports every swept unit, got " .. #prev.order)

            -- Live cast damages all four.
            mage.char.stats.mana.current = 99
            local victims = { c.units[2], c.units[3], c.units[4], c.units[5] }
            local before = {}
            for _, v in ipairs(victims) do before[v] = v.char.stats.health.current end
            assert(Combat.useItem(c, mage, fireball, 5, 5), "fireball lands")
            for _, v in ipairs(victims) do
                assert(v.char.stats.health.current < before[v],
                    "unit at (" .. v.x .. "," .. v.y .. ") took blast damage")
            end
        end,
    },
}
