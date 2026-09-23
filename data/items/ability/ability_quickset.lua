-- Quickset: grow a three-tile hedge across the lane behind a foe (data/walls/hedge.lua).
--
-- The second half of every shove the company owns. Combat.knockback bills the impact of the tiles a
-- shove could not spend, and on an open board most shoves spend all of theirs -- a hedge behind the
-- target is the difference between moving it and hurting it. It is also a hedge, which is useful in its
-- own right: a lane shut, a line of sight broken. Conjured, so a Dispel clears it.
return {
    name = "Quickset",
    description = "Grows a three-tile hedge across the lane behind a foe.",
    flavor = "Quickset: a hedge planted live, meant to take.",
    sprite = "assets/items/ability_quickset.png",
    type = "ability",
    tags = { "nature", "earth" },
    class = "druid",
    price = 565,
    unlockLevel = 11,
    activeAbility = {
        target = "enemy",
        range = 4,
        requiresSight = true,
        speed = 3,
        cost = { stat = "mana", amount = 10 },
        effect = function(fx)
            local t, u = fx.target, fx.user
            local ddx, ddy = t.x - u.x, t.y - u.y
            local dx, dy = 0, 0
            if math.abs(ddx) >= math.abs(ddy) then dx = (ddx >= 0) and 1 or -1 else dy = (ddy >= 0) and 1 or -1 end
            local bx, by = t.x + dx, t.y + dy
            local px, py = dy, dx -- perpendicular to the lane
            for s = -1, 1 do
                fx.placeWall(bx + px * s, by + py * s, "hedge",
                    { health = 12 + fx.level, duration = 18 + fx.level })
            end
        end,
    },
}
