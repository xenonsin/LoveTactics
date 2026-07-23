-- Quest-only: `class` with no `price` (docs/classes.md).
--
-- Gluttony stated plainly: every blow the wearer lands feeds them (trait_ravenous), so a long trade
-- only fattens them. It is the sin's own item, lifted off the shelf's own general and handed to a
-- character who has to decide whether they want to be that.
--
-- Mechanically it is SUSTAIN PRICED ON AGGRESSION, and it is the exact opposite number to the
-- fighter's Unspent Heart, which pays out only while nobody is touching you. The two together
-- describe the whole axis: one rewards disengaging, the other rewards never stopping, and no build
-- can want both.
--
-- The hide itself is thin on purpose. A ravener who is winning is unkillable and a ravener who is
-- losing is dead, and armour in the middle of that would only blur it -- the healing has to come from
-- landing blows, or the item is just a bigger health bar with a story attached.
--
-- Pairs with anything that swings twice. Beside a bow that fires two shafts it is a heal per shaft.
return {
    name = "Ravener's Hide",
    description = "Every blow you land feeds you: heal on the hit, and a long trade only fattens you.",
    flavor = "The Warren keeps it in a locked case and is very clear that this is for the case's benefit.",
    sprite = "assets/items/armor_raveners_hide.png",
    type = "armor",
    tags = { "hide" },
    class = "hunter",
    traits = { "trait_ravenous" },
    bonus = { defense = { 2, 2, 3, 3, 4, 4, 4, 5, 5, 6, 6 } },
}
