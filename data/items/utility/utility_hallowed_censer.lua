-- The Priest's signature relic: the censer whose smoke marks the ground they stand on as consecrated.
-- It carries the Priest's innate (data/traits/sanctified_presence.lua) -- each tick, every ally
-- standing adjacent (and the Priest) mends a little. Like Overchannel it hangs no hook; the recovery
-- loop reads it via Trait.has, and Trait.attach finds it on this item where it once sat on the char.
--
-- `bound = true` (models/item.lua): never moved, stowed, given, sold, or stolen -- only forged. The
-- Priest's blueprint places it in the center of the loadout grid as the build-around.
--
-- No `class`/`price`: no vendor stocks or buys it. Forged at the Blacksmith, its ward against magic
-- climbing with the level.
return {
    name = "Hallowed Censer",
    description = "You and adjacent allies mend a little health each tick.",
    flavor = "The ground a priest stands on is consecrated by the standing. It never leaves your hand.",
    sprite = "assets/items/sig_hallowed_censer.png",
    type = "utility", -- a censer: `bound` (not the type) is what locks it in place
    tags = { "signature" },
    bound = true,
    traits = { "trait_sanctified_presence" },
    bonus = { magicDefense = { 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7 } }, -- levels 0..10
}
