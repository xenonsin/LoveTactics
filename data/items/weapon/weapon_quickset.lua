-- Quickset: the Dryad grows a hedge across the lane behind a foe -- three tiles of it, square to the line
-- between them -- so the next shove that finds that foe has something to land on.
--
-- WHY THE HEDGE GOES BEHIND. Combat.knockback bills the impact of every tile a shove could not spend, and
-- on an open eight-by-eight board most shoves spend all of theirs. She is the one who puts the wall there
-- (data/walls/hedge.lua). With a harpy on the floor this is a two-body combo; without one it is still a
-- hedge in the company's line of retreat, which is worth something on its own.
--
-- The hedge is conjured and tagged `illusion`, so a Dispel clears it, and `nature`, so it is grove a
-- Nymph can step out of (models/grove.lua). A natural weapon: no class, no price, noSteal.
return {
    name = "Hedgerow", -- not the spell's name (ability_quickset): see weapon_mistlight on why
    description = "Grows a three-tile hedge across the lane behind a foe.",
    flavor = "Quickset: a hedge planted live, meant to take. This one took before it touched the ground.",
    sprite = "assets/items/quickset.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "nature", "magical", "ranged" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 4,
        requiresSight = true,
        speed = 4,
        cost = { stat = "mana", amount = 10 },
        ai = {
            { priority = "normal", act = "cast", targetPref = "nearest",
              when = { subject = "any_foe", test = "within", value = 4 } },
        },
        effect = function(fx)
            local t, u = fx.target, fx.user
            -- The dominant axis from caster to target, as a shove would read it: the hedge rises on the
            -- far side of the target along that axis, and spreads one tile either way across it.
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
