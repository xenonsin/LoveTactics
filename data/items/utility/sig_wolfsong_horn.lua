-- The Archer's signature relic: the horn she was given the day the wolf first answered it. It carries
-- her innate companion (data/traits/wolf_companion.lua) -- a wolf fields itself at her side at the
-- opening bell, free of any mana reservation, distinct from the Summon Wolf ability any character can
-- carry. The trait now lives on this item and reaches her through the grid (models/trait.lua).
--
-- `bound = true` (models/item.lua): never moved, stowed, given, sold, or stolen -- only forged. Her
-- blueprint sits it in the center of the loadout grid as the build-around.
--
-- No `class`/`price`: no vendor stocks or buys it. Forged at the Blacksmith, its speed curve rising.
return {
    name = "Wolfsong Horn",
    description = "Raised beside a wolf; it still comes when the horn sounds. You start each battle " ..
        "with it at your side, free of any reservation.",
    sprite = "assets/items/sig_wolfsong_horn.png",
    type = "utility", -- a horn: `bound` (not the type) is what locks it in place
    tags = { "signature" },
    bound = true,
    traits = { "wolf_companion" },
    bonus = { speed = { 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3 } }, -- levels 0..10
}
