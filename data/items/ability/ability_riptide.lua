-- Riptide: the water takes a whole rank a step toward you.
--
-- A lane cast (aimed at the adjacent tile, as every lane cast in this engine is -- the ability targets
-- a DIRECTION, and the first tile of the line is what names it). Every body in the lane is dragged one
-- tile toward the caster.
--
-- ITS TWIN IS ability_surge, and the pair is the point. The geometry is what makes them two weapons
-- rather than one with a switch: PULL takes you into the channel the naga is standing in, PUSH takes
-- you into the channel behind you. So Surge is the one that works when the Mere is on dry land, and
-- this is the one that works when it is not -- and a player holding both is choosing, every turn,
-- which side of the water the fight is on.
--
-- FARTHEST FIRST, which is not decoration. Dragging a rank toward yourself with the near body
-- unresolved means the near body is still standing in the tile the next one is being pulled into, and
-- half the lane simply fails to move for reasons no player could see. Sorted here rather than trusted
-- to fx.aoeUnits' order, because that order is a fact about how the board is walked and not a promise.
--
-- AGAINST A COMPANY NOWHERE NEAR WATER it is still a formation break: a rank pulled a step out of its
-- own line is a rank that has lost its shape. That is deliberate -- an ability whose whole value is one
-- terrain type is an ability that is dead on most boards.
local Curve = require("models.curve")

return {
    name = "Riptide",
    description = "Drags every body in a 3-tile line one step toward you.",
    flavor = "It is not the wave that takes you. It is the water going back out.",
    sprite = "assets/items/riptide.png",
    type = "ability",
    tags = { "water", "magical" },
    class = "mage",
    dropOnly = true,
    unlockLevel = 14,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 1,
        minRange = 1,
        speed = 5,
        cost = { stat = "mana", amount = 9 },
        damage = Curve.ramp(15, 25),
        aoe = { shape = "line", length = 3 },
        effect = function(fx)
            local dx, dy = fx.tx - fx.user.x, fx.ty - fx.user.y
            local hit = {}
            for _, u in ipairs(fx.aoeUnits()) do hit[#hit + 1] = u end
            -- Farthest from the caster first, so each body is dragged into ground the one ahead of it
            -- has already left. Chebyshev, to match how the engine measures a gap everywhere else.
            table.sort(hit, function(a, b)
                local da = math.max(math.abs(a.x - fx.user.x), math.abs(a.y - fx.user.y))
                local db = math.max(math.abs(b.x - fx.user.x), math.abs(b.y - fx.user.y))
                if da ~= db then return da > db end
                return (a.x * 1000 + a.y) > (b.x * 1000 + b.y) -- a stable tiebreak: seeds must replay
            end)
            for _, u in ipairs(hit) do
                fx.damage(u)
                -- One step along the lane, toward the caster. Routed through the shove primitive, so a
                -- body dragged into a channel drowns with nothing about drowning written here.
                if u.alive then
                    fx.knockback(u, 1, { dest = { x = u.x - dx, y = u.y - dy } })
                end
            end
        end,
    },
}
