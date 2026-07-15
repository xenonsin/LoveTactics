-- Charge: pin the foe directly in front and drive it straight back three tiles, running in lockstep
-- behind it (fx.charge -- see models/combat.lua). The pair only stops when the lane ahead is barred by
-- impassable terrain, a wall, or the board edge; any bystander caught in the lane is shoved aside and
-- trampled for minor damage. The pinned target itself takes no damage from the charge -- this is
-- displacement, not a strike: use it to bury a foe in a corner, or plough it back through its own line.
return {
    name = "Charge",
    description = "Pin the foe in front and drive it (and yourself) three tiles ahead, trampling the lane.",
    sprite = "assets/items/ability_charge.png",
    type = "ability",
    tags = { "impact", "physical" },
    class = "fighter",
    price = 320,
    repRank = 3,
    activeAbility = {
        target = "enemy",
        range = 1, -- the target must start directly in front (adjacent) -- the "pin"
        speed = 4,
        cost = { stat = "stamina", amount = 10 },
        effect = function(fx)
            fx.charge(fx.target, 3)
        end,
    },
}
