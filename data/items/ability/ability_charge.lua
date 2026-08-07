-- Charge: pick an adjacent tile and rush three tiles down that lane (fx.chargeInto -- see
-- models/combat.lua). What the aimed tile HOLDS decides which kind of charge it is:
--
--   a body   -- it is pinned and driven three tiles straight back, the charger running in lockstep
--               behind it. Displacement, not a strike: the pinned target takes no damage from the run.
--               Use it to bury a foe in a corner, or plough it back through its own line.
--   nothing  -- the charger runs the empty lane itself, three tiles of ground crossed on an ACTION
--               instead of on its move. That is the whole reason this aims a tile rather than a foe:
--               movement is the scarcest thing in this game, and a gap-closer that could only be
--               pointed at somebody already standing next to you was never closing a gap.
--
-- Either way the run stops the moment the lane ahead is barred by impassable terrain, a wall, furniture
-- or the board edge, and any bystander caught in it is shoved aside and trampled for minor damage.
--
-- `allowOccupied`, so the tile may hold a body -- and, as with Push and Heave, the grip is the TILE:
-- an ally standing in front of you is charged exactly as a foe is. That is a cost, not an oversight;
-- the fighter who wants the lane clears it.
--
-- One thing this shape gives up: a tile-aimed ability with no AoE is not surfaced by
-- Combat.abilityTargets, so the enemy AI cannot plan a Charge (it plans Push no better). No shipped
-- blueprint carries this, so nothing regresses today -- but a foe handed one would simply never use it.
return {
    name = "Charge",
    description = "Rushes three tiles down an adjacent lane, driving whatever stands in it.",
    flavor = "Displacement, not a strike. Where everyone ends up is the entire point of the exercise.",
    sprite = "assets/items/ability_charge.png",
    type = "ability",
    tags = { "impact", "physical" },
    class = "fighter",
    price = 80,
    unlockQuests = 0,
    activeAbility = {
        target = "tile",
        allowOccupied = true, -- the lane may start on a body (pin and drive) or on open ground (run it)
        range = 1,            -- the tile aimed is the FIRST tile of the lane, never the far end of it
        minRange = 1,         -- an adjacent neighbour: aiming your own square names no direction
        speed = 4,
        cost = { stat = "stamina", amount = 10 },
        effect = function(fx)
            fx.chargeInto(fx.tx, fx.ty, 3)
        end,
    },
}
