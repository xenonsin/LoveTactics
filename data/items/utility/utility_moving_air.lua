-- What a Wind Elemental is instead of a body, and the vessel Nothing to Hold rides in.
--
-- A creature's rule lives on an ITEM in its grid -- a blueprint's own `traits` field is never collected
-- (models/trait.lua). Natural kit: no class, no price, noSteal (tests/bestiary_spec.lua).
--
-- NOT STEALABLE FOR ONCE MEANS SOMETHING, since the rule it carries is one a player can actually own:
-- the Unheld hands the same stance over on a real shelf (data/items/utility/utility_the_unheld.lua).
-- What is refused here is the shortcut -- you cannot pickpocket a draught for the trick, you go and
-- kill one for it, which is the rift's whole arrangement with the player (docs/drops.md).
return {
    name = "Moving Air",
    description = "Cannot be moved: no shove, drag, throw or charge shifts it.",
    flavor = "You can put a hand through the middle of it and close the hand on nothing at all.",
    sprite = "assets/items/moving_air.png",
    type = "utility",
    class = "creature",
    tags = { "natural" },
    noSteal = true,
    traits = { "trait_nothing_to_hold" },
}
