-- THE BAILIFF'S BAR: what the Bailiff drops (data/characters/character_bailiff.lua; "Sloth's Bestiary", 2026-10-04,
-- slice F, approved word for word). A shield, so it swaps Wait into Defend; and Defend also Braces every adjacent
-- ally until your next turn.
--
-- The Barrier (data/traits/trait_the_barrier.lua) on a Defend instead of on every turn. It is the Oathkeeper's
-- `covers` with the clock moved: an Oathkeeper's lent brace drops as each ally's own turn opens, this one holds until
-- the holder's next turn does (the lent brace is stamped `heldBy`, which status_defending honours) -- so an ally
-- that acts before you comes back to a wall still standing. The impact rule that breaks a Tollkeeper's gate is the
-- Tollkeepers' own and does not come with it.
--
-- A BULWARK'S, the shelf that holds ground. An unstocked trophy on the seat's rung.
local Curve = require("models.curve")

return {
    name = "Bailiff's Bar",
    description = "Defend also Braces every adjacent ally until your next turn.",
    flavor = "It does not stop anyone. It only makes them decide whether they meant it.",
    sprite = "assets/items/armor_bailiffs_bar.png",
    type = "armor",
    tags = { "shield" },
    class = "bulwark",
    unlockLevel = 10,
    unstocked = true,
    bonus = { defense = Curve.ramp(3, 13), movement = -1 },
    resist = { physical = 2 },
    waitBehavior = { kind = "defend", speed = 2, defense = Curve.ramp(8, 18) },
    traits = { "trait_the_barrier" },
    traitParams = { covers = 6 },
}
