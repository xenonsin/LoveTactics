-- THE OUTRIDER: a Tollkeeper of Sloth's seat ("Sloth's Bestiary", 2026-10-04, slice F), mounted on a hollow beast.
--
--   RIDE PAST  it charges up to 4 tiles in a line, striking every body it passes through, and ends its move beyond
--              them. It never ends a turn beside a foe. A charge with nowhere to come out stops dead, and the
--              Outrider is Stunned (weapon_ride_past; its turn is models/toll.lua's Toll.plan)
--   EXIT FEE   as every Tollkeeper (utility_exit_fee)
--
-- THE COUNTERPLAY, STATED: put your back to a wall or a body. A lane that ends on one is a lane it cannot come out of.
--
-- A demon: holy bites, and the lance burns. Barding over hollow ribs: a point skids, a club caves it in.
return {
    name = "Outrider",
    race = "demon",
    tier = 3,
    sprite = "assets/chars/outrider.png",
    stats = {
        health = 88, mana = 0, stamina = 30,
        staminaRegen = 4,
        damage = 12, magicDamage = 0,
        defense = 5, magicDefense = 4,
        movement = 5,
        speed = 5,
        skill = 6, luck = 3,
    },
    resist = { pierce = 2, impact = -2 },
    startingItems = {
        false,              false,              false,
        "weapon_ride_past", "utility_exit_fee", false,
        false,              false,              false,
    },
    defaultAction = "weapon_ride_past",
    -- ITS OWN PIECE (docs/drops.md): the ride, in a company's hands.
    drops = { "weapon_passing_lance" },
    archetype = "aggressive",
}
