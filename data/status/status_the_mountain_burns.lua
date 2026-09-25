-- THE MOUNTAIN BURNS: Avaritia's last third (reviewed 2026-09-25, "Avaritia, the Unspent"). Laid by her
-- phase relic at 30% of her health, in the same beat as every heap left melts.
--
--   * +25% DAMAGE, worked out once from her own damage when it lands (a per-instance statBonus), so it
--     scales with whatever floor-level body she was fielded as.
--   * THE LAVA SPREADS. At the start of each of her turns every empty tile orthogonally beside a lava pit
--     or a pool of Molten Gold turns to lava -- impassable, the cave's own rise (models/arena.lua). A tile
--     with a body, an object or a zone on it is passed over, as Cave-In passes one over, so nobody is sealed
--     in by the ground growing under them; the board simply runs out of floor. The race of her last third.
--
-- The rewrite runs in a status hook, which only ever runs live, so no forecast rewrites the board.
local RAGE = 0.25

local function spread(combat)
    local tiles = combat.arena and combat.arena.tiles
    if not tiles then return 0 end
    local Combat = require("models.combat")
    local Hazard = require("models.hazard")
    local lava = require("models.terrain").get("lava")
    local sources = {}
    for y, row in pairs(tiles) do
        for x, cell in pairs(row) do
            if cell.type == "lava" then sources[#sources + 1] = { x = x, y = y } end
        end
    end
    for _, h in ipairs(combat.hazards or {}) do
        if h.alive ~= false and h.id == "hazard_molten_gold" then sources[#sources + 1] = { x = h.x, y = h.y } end
    end
    -- Gathered first and rewritten after, so a tile turned this beat does not spread again in the same beat.
    local turn, order = {}, {}
    for _, s in ipairs(sources) do
        for _, d in ipairs({ { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 } }) do
            local x, y = s.x + d[1], s.y + d[2]
            local key = x .. "," .. y
            local cell = tiles[y] and tiles[y][x]
            if not turn[key] and cell and cell.walkable and not Combat.unitAt(combat, x, y)
                and not Combat.objectAt(combat, x, y) and #Hazard.allAt(combat, x, y) == 0 then
                turn[key] = cell
                order[#order + 1] = cell
            end
        end
    end
    for _, cell in ipairs(order) do
        cell.type = "lava"
        cell.moveCost = lava.moveCost
        cell.walkable = lava.walkable
        cell.sightCost = lava.sightCost or 0
        cell.bonus = lava.bonus
        cell.tags = lava.tags
        cell.swim, cell.drowns = nil, nil
    end
    return #order
end

return {
    name = "The Mountain Burns",
    abbr = "Lava",
    description = "Increase damage. At the start of its turn, the lava spreads a tile.",
    color = { 0.820, 0.220, 0.080 }, -- badge tint (lava)
    duration = math.huge,
    hideDuration = true,
    onApply = function(ctx)
        local base = ctx.unit and ctx.unit.char and ctx.unit.char.stats and ctx.unit.char.stats.damage
        if type(base) == "table" then base = base.max or base.current end
        ctx.status.statBonus = { damage = math.max(1, math.floor((tonumber(base) or 0) * RAGE + 0.5)) }
    end,
    onTurnStart = function(ctx)
        if not ctx.combat then return end
        if spread(ctx.combat) > 0 then ctx.log("action", "The lava spreads.", ctx.unit) end
    end,
}
