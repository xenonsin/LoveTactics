-- Summon Wall: raise a 3x1 line of conjured barrier, blocking movement and line of sight. The line
-- runs PERPENDICULAR to the caster's approach -- aim past a foe and the wall screens across the lane
-- between you, not along it. A tile-target cast: Combat.useItem hands the aimed cell as fx.tx/fx.ty,
-- and fx.placeWall drops one segment per tile (a tile that can't hold a wall is quietly skipped).
--
-- The wall is tagged `illusion`, so a Dispel Illusions clears the whole span at once -- but it can
-- also be struck down segment by segment, and fades on its own timer. See data/walls/illusory_wall.lua.
return {
    name = "Summon Wall",
    description = "Raise a 3-tile wall that blocks movement and sight. It fades, or can be broken.",
    sprite = "assets/items/ability_summon_wall.png",
    type = "ability",
    tags = { "holy", "illusion" },
    class = "priest",
    price = 260,
    repRank = 3,
    activeAbility = {
        target = "tile",
        range = 4,
        speed = 5,
        cost = { stat = "mana", amount = 16 },
        support = true, -- a friendly (zoning) cast, not an attack: reads green, the AI treats it so
        allowOccupied = true, -- the aimed cell may hold a unit; per-tile placement skips occupied ground
        effect = function(fx)
            -- The line runs perpendicular to the dominant caster->target axis, so it screens the lane.
            local dx, dy = fx.tx - fx.user.x, fx.ty - fx.user.y
            local ax, ay
            if math.abs(dx) >= math.abs(dy) then ax, ay = 0, 1 else ax, ay = 1, 0 end
            -- A more-forged casting raises a tougher, longer-lasting barrier: HP base 20 (+2 per level),
            -- lifespan base 18 ticks (+1 per level).
            for i = -1, 1 do
                fx.placeWall(fx.tx + ax * i, fx.ty + ay * i, "illusory_wall",
                    { health = 20 + 2 * fx.level, duration = 18 + fx.level })
            end
        end,
    },
}
