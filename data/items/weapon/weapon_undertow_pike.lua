-- The Undertow's pike, and the exact inverse of a spear already on the shelf.
--
-- A spear, so the effect lands on the FAR tile (docs/weapons.md). Here that tile is DRAGGED ONE TILE
-- TOWARD THE BEARER -- the point goes past the front rank, hooks the man behind it, and brings him
-- forward into the water the bearer is standing in.
--
-- READ IT AGAINST weapon_tidesbreak. That one soaks the far tile, drives the line BACK a pace, and
-- steps its wielder into the gap: a shield wall taking ground. This reaches past the front rank and
-- takes the body behind it. Push and pull, one shelf apart, and neither makes the other redundant --
-- which is the difference between a pair and a tier.
--
-- WHY THE FAR TILE AND NOT THE NEAR ONE, which is the whole of why this weapon is frightening. The near
-- body is the one you can see coming and the one that chose to be there. The far body is the archer,
-- the caster, the man who arranged his turn around never being in reach -- and a pike that takes HIM
-- one tile closer to a channel is a pike that makes the back rank a bad place to stand.
--
-- ONE TILE, and the implementation is a knockback aimed at a destination one step toward the bearer
-- rather than fx.pull, which hauls a body all the way in. A single step is a threat you can answer by
-- standing somewhere else; a full haul is one the board cannot argue with.
--
-- IT CANNOT DROWN ANYBODY BY ITSELF, and that is worth writing down because the first draft of this
-- file claimed the opposite. The far body is dragged onto the AIMED tile, and a tile-targeted cast is
-- refused outright when the tile is not walkable (Combat.itemBlockReason: "blocked tile") -- so the
-- one destination that would put somebody in the water is the one destination this weapon may never
-- name. What it does instead is bring the back rank a step nearer the bank; the lane casts
-- (ability_riptide, ability_breaker) are what push somebody over it, because a knockback along a lane
-- never has to name the tile it ends on.
--
-- That is the better arrangement anyway, and it is the faction's own shape one rung up: the pike sets
-- up, the cast finishes. A weapon that both positioned and killed would make the Undertow's other two
-- items decorations.
local Curve = require("models.curve")

return {
    name = "Undertow Pike",
    description = "Skewers a 2-tile line and drags the far tile one step toward you.",
    flavor = "The water does not take you all at once. It takes you a foot at a time, and you help.",
    sprite = "assets/items/undertow_pike.png",
    type = "weapon",
    tags = { "spear", "pierce", "physical", "water", "melee" },
    hands = 2,
    class = "knight",
    dropOnly = true,
    unlockLevel = 13,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 1,
        minRange = 1,
        speed = 5,
        cost = { stat = "stamina", amount = 11 },
        damage = Curve.ramp(14, 24),
        aoe = { shape = "line", length = 2 },
        effect = function(fx)
            local dx, dy = fx.tx - fx.user.x, fx.ty - fx.user.y
            local farX, farY = fx.tx + dx, fx.ty + dy
            -- The far body has to be found BEFORE anything moves, exactly as Tidesbreak captures its
            -- own: a displacement that reads the tile afterwards reads the tile the body already left.
            local far
            for _, u in ipairs(fx.aoeUnits()) do
                if u.x == farX and u.y == farY then far = u end
            end
            for _, u in ipairs(fx.aoeUnits()) do fx.damage(u) end
            if far and far.alive then
                -- One step toward the bearer: a destination one tile along the line from the far body
                -- to the wielder, so the shove travels exactly 1 and points the right way.
                fx.knockback(far, 1, { dest = { x = far.x - dx, y = far.y - dy } })
            end
        end,
    },
}
