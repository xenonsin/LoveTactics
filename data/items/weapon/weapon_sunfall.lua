-- A longbow, so it is drawn before it looses and reaches five tiles (docs/weapons.md). Its extra is that
-- the shaft comes down burning: it lands `fire`-tagged and leaves hazard_burning_halo where it falls --
-- a ring of white fire in which enemies burn and cannot see far enough to shoot.
--
-- Quest-only: `class` with no `price`.
--
-- The only zone in the game that does two jobs at once, and the second one is the reason to carry this
-- over any other fire effect: the halo blinds as well as burns, so a rank standing in it cannot answer at
-- range. An archer looses this into the enemy's shooting line and that line stops being a shooting line
-- -- which is a thing no amount of damage would have achieved, because a dying archer still shoots.
--
-- It pairs with the draw rather than fighting it. The turn the wind-up costs is the turn the enemy spends
-- moving into the square the halo is about to occupy, so the shot rewards reading their approach instead
-- of their position. That is the longbow's own lesson and this is the clearest statement of it.
--
-- Unsided, as fire always is (data/items/weapon/weapon_emberwand.lua argues the case): it burns your line
-- exactly as happily and blinds your own archers standing in it. A wall you have to be willing to stand
-- behind rather than inside.
return {
    name = "Sunfall",
    description = "A drawn shaft that lands burning, leaving a ring of white fire that scorches and blinds.",
    flavor = "It is not the sun. The Lodge is quite firm on this and has stopped being asked.",
    sprite = "assets/items/sunfall.png",
    type = "weapon",
    tags = { "longbow", "pierce", "physical", "fire", "ranged" },
    hands = 2,
    class = "hunter",
    activeAbility = {
        target = "enemy",
        range = 5,
        minRange = 2,
        requiresSight = true,
        speed = 4,
        channel = 2,
        cost = { stat = "stamina", amount = 11 },
        -- Under the iron longbow's: the halo is the weapon, and the arrow is the delivery.
        damage = { 6, 7, 8, 8, 9, 10, 11, 12, 13, 14, 15 },
        effect = function(fx)
            if fx.target then fx.damage(fx.target) end
            -- On the aimed cell and the ring around it: a halo is a ring, and one tile of white fire
            -- would be an ember. Tiles that cannot hold a zone are skipped by Hazard.place returning nil.
            for dy = -1, 1 do
                for dx = -1, 1 do
                    fx.placeHazard(fx.tx + dx, fx.ty + dy, "hazard_burning_halo",
                        { amount = 3 + fx.level, duration = 8 + fx.level })
                end
            end
        end,
    },
}
