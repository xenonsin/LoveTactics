-- Quest-only: `class` with no `price` (docs/classes.md).
--
-- Bites anyone who works a spell within reach of it (trait_gaunt_vigil). Not when they attack the
-- wearer -- when they CAST, at all, anywhere in reach. The enemy caster is punished for the act rather
-- than for the target.
--
-- A BORROW, and docs/classes.md requires it be said out loud: this is heavy plate, and heavy plate is
-- the Bastion's language, not the Arcanum's. It is on the mage's shelf anyway because of what the
-- plate is FOR -- it is the Arcanum policing the Arcanum, the answer a school of magic builds for its
-- own defectors, and the sin it expresses is pride's (there is one correct way to work, and it is
-- ours). A knight in it is a Spellbreaker, which is a pair docs/classes.md already names and cannot
-- yet sell; that is the borrow paying for itself.
--
-- The rule is also why it is the one mage item in this file with no magic defense worth the name. It
-- does not survive spells, it makes them expensive to cast -- and a wearer who could do both would
-- retire the Mirrorsilk on the same shelf.
--
-- Heavy: two squares of pace, and the wearer has to be close enough to matter.
return {
    name = "Gaunt Vigil Plate",
    description = "Bites anyone who works a spell within reach of you.",
    flavor = "The Arcanum drives one into the floor of every room it does not trust. This one was cut free.",
    sprite = "assets/items/armor_gaunt_vigil_plate.png",
    type = "armor",
    tags = { "heavy", "arcane" },
    class = "mage",
    traits = { "trait_gaunt_vigil" },
    bonus = { defense = { 8, 9, 9, 10, 11, 12, 12, 13, 14, 15, 15 }, magicDefense = { 2, 2, 3, 3, 3, 4, 4, 4, 5, 5, 5 }, movement = -2 },
    resist = { physical = { 3, 3, 4, 4, 4, 5, 5, 5, 5, 6, 6 } },
}
