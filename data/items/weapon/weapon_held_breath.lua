-- A longbow, so it is drawn before it looses (docs/weapons.md). Its extra is that DRAWING HIDES YOU: the
-- moment the archer commits to the wind-up they become Unseen (status_invisible), and stay so through the
-- turn the enemy would have used to punish the draw.
--
-- Quest-only: `class` with no `price`.
--
-- It answers the family's single defining weakness, which docs/weapons.md states outright: "you stand
-- where nothing can close on you in the turn you spend drawing, or you don't get the shot at all." Every
-- other longbow pays for its reach by being a stationary target for a full turn. This one is not a target
-- at all while it draws.
--
-- What makes that a trade rather than a straight upgrade is that the invisibility is spent by the shot.
-- It lasts until the archer's next turn, which is precisely when the arrow looses -- so the weapon buys
-- safety DURING the commitment and none at all afterwards, and an archer who used it to walk into a
-- better position arrives visible and adjacent to everything.
--
-- The interaction worth knowing: hard control still breaks the draw, and being unseen does not stop an
-- AoE or a hazard from landing on the tile you are standing in. Invisible answers targeting, not
-- geometry.
return {
    name = "The Held Breath",
    description = "Drawn over a full turn -- and while you draw, you cannot be seen or targeted.",
    flavor = "The trick was never the shot. It was the part beforehand, where everybody is looking for you.",
    sprite = "assets/items/held_breath.png",
    type = "weapon",
    tags = { "longbow", "pierce", "physical", "ranged" },
    hands = 2,
    class = "hunter",
    activeAbility = {
        target = "enemy",
        range = 5,
        minRange = 2,
        requiresSight = true,
        speed = 4,
        channel = 2,
        cost = { stat = "stamina", amount = 10 },
        damage = { 9, 10, 11, 12, 13, 15, 16, 17, 18, 19, 21 },
        -- The whole weapon, in one field. `channelStatus` lands on the caster the moment the draw is
        -- COMMITTED rather than when it resolves (Combat.useItem's channel branch), which is the half an
        -- `effect` cannot reach -- an effect runs when the arrow arrives, and by then the turn this was
        -- meant to survive has already happened. It lasts the wind-up's own length, so it lifts on the
        -- beat the shaft looses.
        channelStatus = "status_invisible",
        effect = function(fx)
            if fx.target then fx.damage(fx.target) end
        end,
    },
}
