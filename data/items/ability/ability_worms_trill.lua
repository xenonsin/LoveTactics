-- WORM'S TRILL: the Frost Worm's trophy, on the Shaman's shelf ("Sloth's Bestiary", 2026-10-04, slice C). The
-- worm's note carried out of the cold: channel for a turn, and every foe within 3 when it lands falls Asleep.
--
-- The player's version spares its own side, where the worm's does not -- the shaman has learned the pitch, not
-- just the volume. Sleep breaks on any hit, so it is a turn bought for the rest of the company, never a setup for
-- focused fire (ability_drowsing_air argues the shape in full). The tell is the worm's: a shove or hard control
-- breaks it, and a foe that walks out of the ring is not caught.
--
-- `unstocked`: the body's own piece, visible on its house's rack and never sold (docs/drops.md).
return {
    name = "Worm's Trill",
    description = "Channeled: every foe in area falls Asleep.",
    flavor = "Pitched just under hearing. The shaman hums it with their mouth closed, and never in the house.",
    sprite = "assets/items/ability_worms_trill.png",
    type = "ability",
    tags = { "ice", "magical" },
    class = "shaman",
    unlockLevel = 9,
    unstocked = true,
    activeAbility = {
        target = "self",
        support = false,
        range = 0,
        windup = 5,
        speed = 5,
        cost = { stat = "mana", amount = 14 },
        aoe = { shape = "diamond", radius = 3 },
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                if u ~= fx.user and u.alive and u.side ~= fx.user.side then fx.applyStatus(u, "status_sleep") end
            end
        end,
    },
}
