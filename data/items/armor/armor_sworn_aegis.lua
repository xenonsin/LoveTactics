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
    description = "The first hit each turn on an adjacent ally is taken by you instead.",
    flavor = "The shield the oath was sworn on, and it never leaves your hand. A knight is the promise, not the steel.",
    sprite = "assets/items/sig_sworn_aegis.png",
    type = "armor", -- a shield: `bound` (not the type) is what locks it in place
    tags = { "signature", "shield" },
    class = "knight",
    bound = true,
    traits = { "trait_oathward" },
    bonus = { defense = { 3, 3, 4, 4, 4, 5, 5, 5, 5, 6, 6 } },
    resist = { physical = { 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2 } },
    -- Defend brace: the knight's core stance, its +defense climbing as the shield is forged.
    waitBehavior = { kind = "defend", speed = 5, defense = { 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 } },
}
