-- The Knight's signature relic: the shield they swore their oath on. It carries the Knight's innate
-- guard (data/traits/oathward.lua) -- the trait now rides on this item, not on the character, and
-- reaches the unit through the grid exactly like any other item-granted reaction (models/trait.lua).
--
-- `bound = true` is the reusable lock (models/item.lua): it can never be moved off its cell, stowed,
-- given away, sold, or stolen -- only forged. The Knight's blueprint places it in the center of the
-- loadout grid, where it is the build-around the eight surrounding cells arrange themselves for.
--
-- No `class` and no `price`: no vendor stocks or buys it. It is upgraded at the Blacksmith like a
-- shield, its defense curve climbing with the forge.
return {
    name = "Sworn Aegis",
    description = "The shield the oath was sworn on. The first hit each turn on an adjacent ally is " ..
        "taken by you instead. It never leaves your hand.",
    sprite = "assets/items/sig_sworn_aegis.png",
    type = "armor", -- a shield: `bound` (not the type) is what locks it in place
    tags = { "signature", "shield" },
    class = "knight",
    bound = true,
    traits = { "oathward" },
    bonus = { defense = { 3, 3, 4, 4, 4, 5, 5, 5, 5, 6, 6 } },
    resist = { physical = { 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2 } },
    waitBehavior = { kind = "defend", speed = 5 },
}
