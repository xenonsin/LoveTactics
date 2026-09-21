-- THE SECOND HOUND: named for what a stag is actually counting.
--
-- It does not run from the first hound. One hound is a thing you can turn and face; two is the moment
-- the arithmetic changes, and everything a deer does for its whole life is built on knowing which it
-- is looking at. So is this charm (data/traits/trait_the_second_hound.lua): nothing happens in a duel,
-- and the step arrives the instant a fight becomes a surrounding.
--
-- THE MIDDLE RUNG OF WHAT THE STAG HANDS OVER. Its flight is the one part of that fight a person can
-- plausibly have -- the trail belongs to the ground, the detonation is the chase piece, and the animal
-- itself simply cannot be caught, which is not a thing to sell anybody. What is left is the count, and
-- the count travels.
--
-- Filed to the SKIRMISHER, whose whole shelf is about where you are standing rather than what you are
-- holding (docs/classes.md), and who already owns the Outrider's Harness and Running Shot -- the two
-- other items in the game that pay for having gone somewhere. `class` is the vendor shelf and never an
-- equip gate: anyone may carry it.
--
-- RIFT-ONLY (`unstocked`). It comes off the body and nowhere else: no counter deals one however many
-- the company carries out, and none will buy one back (docs/drops.md, Vendor.foundPrice).
return {
    name = "The Second Hound",
    description = "Struck while two or more foes are on you, you give a step of ground.",
    flavor = "It never ran from the first one. Nobody ever saw it wait for the third.",
    sprite = "assets/items/utility_the_second_hound.png",
    type = "utility",
    tags = { "charm", "nature" },
    class = "skirmisher",
    -- The second of three by depth, which is this system's rarity (docs/drops.md): the sandals are the
    -- print you meet, this is the rule, and the Brand is the one you are still after.
    unlockLevel = 9,
    unstocked = true,
    traits = { "trait_the_second_hound" },
}
