-- Quest-only: `class` with no `price` (docs/classes.md).
--
-- At the edge of death the hem cleanses its wearer and lifts them out of reach (trait_stayed_hand):
-- status_suspended takes them off the field entirely -- they cannot act, be acted on, or answer --
-- and everything on them is washed off on the way up.
--
-- The one self-preservation item that costs the party something real, and that is what makes it a
-- decision. A Second Wind stands you back up and you keep fighting; this REMOVES you for a stretch, so
-- a priest saved by it is a priest whose heals are not landing while the line that needed them is
-- still standing there. It buys the wearer's life with the party's tempo.
--
-- Which is why it belongs to lust rather than to any of the shelves that sell survival. The Cathedral's
-- mercy is not free and is not asked for -- it simply happens to you, and the cost lands on somebody
-- else. See docs/story.md.
--
-- utility_stayed_hand is the charm form; the hem is for a priest with no cell to spare.
return {
    name = "Hem of the Stayed Hand",
    description = "At the edge of death, cleanses you and lifts you out of reach for a while.",
    flavor = "The Cathedral maintains that nobody is ever taken. It says the word is gathered, and will not be drawn further.",
    sprite = "assets/items/armor_hem_of_the_stayed_hand.png",
    type = "armor",
    tags = { "cloth", "holy" },
    class = "priest",
    traits = { "trait_stayed_hand" },
    bonus = { magicDefense = { 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9 }, defense = { 2, 2, 2, 3, 3, 3, 3, 3, 4, 4, 4 }, movement = -1 },
    resist = { magical = { 2, 2, 2, 3, 3, 3, 3, 3, 4, 4, 4 } },
}
