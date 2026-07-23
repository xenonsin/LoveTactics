-- Break Off: loose, then give ground. Modest damage and the hunter steps one tile straight back from
-- whatever it just shot -- the ranged half of the wolf's hit-and-run (data/items/weapon/weapon_wolf_fangs.lua),
-- bought rather than born.
--
-- IT IS ABOUT THE DEAD ZONE, not the damage. Every bow in the game has `minRange = 2` and no point-blank
-- shot (docs/weapons.md), so an archer with a foe in its face is an archer holding a stick -- and it
-- cannot even answer a counter, since Combat.answeringWeapon honours the dead zone too. This is the one
-- ability on the shelf that buys the band BACK: one tile of separation, and a hunter that had no shot at
-- the start of its turn has one at the end of it.
--
-- The step is GROUND MOVEMENT, not a blink, and that is the price rather than an oversight. fx.retreat
-- routes through Combat.knockback, so backing off drags the hunter over whatever is behind it -- a
-- caltrop, a fire, its own spike trap -- and a bleeding hunter pays for the tile it crossed
-- (Combat.enterTile's `reason`). Retreating into your own prepared ground is a real mistake you are
-- allowed to make. It is harmless against a WALL, though: fx.retreat passes no collision damage, so
-- backing into stone simply does not move you, and the shot still landed.
--
-- WHY IT IS GLUTTONY'S, and it is the shelf's line read from the far end. Hunter is "setup, then
-- payoff, and most of it gated on a bow beside it in the grid" (docs/classes.md) -- and every other
-- gated ability on that shelf spends the bow to do something to the QUARRY (mark it, cripple it, pin
-- it). This spends the bow on the hunter's own footing. The Lodge's sin is never stopping, and a
-- predator that will not let the distance close so that it can keep eating is precisely that.
return {
    name = "Break Off",
    description = "Deals damage, then steps you one tile back from the target. Requires an adjacent bow.",
    flavor = "The Lodge does not teach retreat. It teaches keeping the range you chose.",
    sprite = "assets/items/ability_break_off.png",
    type = "ability",
    tags = { "pierce", "physical" },
    class = "hunter",
    price = 240,
    repRank = 2,
    activeAbility = {
        target = "enemy",
        -- NO `minRange` of its own, deliberately, and it is the only bow-gated ability on the shelf
        -- without one. The whole point is being usable from inside the dead zone the bow cannot shoot
        -- into -- an ability that inherited the bow's own restriction would be unusable in the exact
        -- situation it exists to answer.
        range = 4,
        requiresSight = true,
        speed = 4,
        cost = { stat = "stamina", amount = 6 },
        -- Under Hobbling Shot's curve: this one already pays out in position, and a step back out of
        -- reach is worth more than the two damage it gives up.
        damage = { 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8 },
        requiresAdjacent = { type = "weapon", tag = "bow" },
        effect = function(fx)
            fx.damage(fx.target)
            fx.retreat(fx.target, 1)
        end,
    },
}
