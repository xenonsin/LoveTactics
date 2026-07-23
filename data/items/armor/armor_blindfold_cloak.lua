-- Quest-only: `class` with no `price` (docs/classes.md).
--
-- Walking Darkness (`incense`, Combat.layIncense): one tile of hazard_darkness seals a line of sight
-- outright (sightCost 2, Combat.SIGHT_BLOCK), and the cloak carries a square of it wherever the wearer
-- stops. Nothing in the cloud is harmed -- it is not a poison, it is a wall you can walk through.
--
-- THE ONLY ANTI-RANGED AREA ITEM IN THE GAME, and the counterpart to the Rimeguard from the other
-- side: that coat stops people arriving, this one stops people SHOOTING. An archer that cannot draw a
-- line has to move, and a caster with `requiresSight` (Stand Down, most of the Arcanum's aimed work)
-- simply cannot cast.
--
-- Unsided, and it must be: sight is symmetric, so the party's own archers are blinded by the same
-- tiles. That makes it an item for a melee-heavy line escorting one wearer, and actively bad in a
-- company of bows -- which is a genuinely uncomfortable thing for a HUNTER's shelf to sell, and is
-- exactly why it is the gluttony line that sells it. The appetite here is for the enemy's turn.
--
-- Cloth, so it costs a square of pace.
return {
    name = "Blindfold Cloak",
    description = "Carries a square of Darkness with you: no line of sight crosses it, either way.",
    flavor = "The Warren took it off a poacher who had worked out that the surest way to hunt is to stop being watched.",
    sprite = "assets/items/armor_blindfold_cloak.png",
    type = "armor",
    tags = { "cloth", "dark" },
    class = "hunter",
    incense = { hazard = "hazard_darkness", radius = 1 },
    bonus = { defense = { 2, 2, 3, 3, 4, 4, 4, 5, 5, 6, 6 }, movement = -1 },
}
