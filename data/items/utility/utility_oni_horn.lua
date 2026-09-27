-- THE ONI HORN: the Oni's drop, the racial rule rebuilt for a person. Approved 2026-09-26 ("The Oni of Wrath").
--
-- The same rule the clan wears (trait_the_horn): below half health the bearer goes Horn Out (+3 Damage, +1 Speed,
-- heals 10% a turn), and a critical hit taken while it stands snaps it for the fight. On a company it is a
-- vengeance button with a price on it -- and an oni of its side falling sets it off too. It carries none of the
-- clan's physical resist: that is the horn on the oni's head, and this is a horn in somebody's hand.
return {
    name = "Oni Horn",
    description = "Below half health, or when an oni of your side falls, gain Horn Out. A critical hit taken snaps the horn.",
    flavor = "Still warm. It does not want to be carried; it wants to be worn, and it does not much mind by whom.",
    sprite = "assets/items/utility_oni_horn.png",
    type = "utility",
    tags = { "charm" },
    class = "barbarian",
    unlockLevel = 7,
    unstocked = true,
    traits = { "trait_the_horn" },
}
