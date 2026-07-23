-- A greatsword, so it winds up (docs/weapons.md). Its extra is what happens AFTER the blow lands: the
-- impact roars, and every foe within two tiles is Taunted onto the wielder (status_taunt) -- they must
-- come at the greatswordsman with their default weapon.
--
-- Which is the family's own weakness turned into its plan. A greatsword's problem has always been the
-- telegraph: you spend a turn raising it and the target walks out of the aimed tile. This one answers
-- that by making the NEXT wind-up happen with the whole enemy line already standing adjacent and
-- obliged to keep swinging at you. The first blow buys the second one its targets.
--
-- What it costs is that a taunted crowd is a crowd hitting you. This is a weapon for a fighter with a
-- healer, and a fast way to die for one without.
return {
    name = "Bellowing Edge",
    description = "Winds up, then falls on one tile. The impact taunts every foe within two tiles onto you.",
    flavor = "The wind-up was never the problem. Getting them to still be standing there was.",
    sprite = "assets/items/bellowing_edge.png",
    type = "weapon",
    tags = { "greatsword", "slash", "physical", "melee" },
    hands = 2,
    class = "fighter",
    price = 480,
    repRank = 3,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 1,
        minRange = 1,
        speed = 7,
        channel = 2,
        cost = { stat = "stamina", amount = 15 },
        -- Under the iron greatsword's: the roar is the rest of the price.
        damage = { 20, 22, 24, 26, 28, 30, 32, 35, 37, 39, 42 },
        effect = function(fx)
            if fx.target then fx.damage(fx.target) end
            -- The roar goes out whether or not the blow found a body -- a greatsword falling on empty
            -- ground still makes the noise, and a player who mistimed the telegraph should at least get
            -- the enemy line walked into their reach for it.
            for _, u in ipairs(fx.unitsNear(fx.tx, fx.ty, 2)) do
                if u.alive and u.side ~= fx.user.side then
                    local st = fx.applyStatus(u, "status_taunt")
                    if st then st.taunter = fx.user end -- who the roar drags them toward (see ability_shout)
                end
            end
        end,
    },
}
