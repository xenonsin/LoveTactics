-- HOLD THE QUARRY: the Lioness's trophy (data/characters/character_lioness.lua), on the Hunter's shelf. Approved
-- 2026-09-30 on Pride's bestiary review. Her hold, without a Lion to hold it for: a blow that takes a foe from a
-- quarter of its health or more to below it Roots it (trait_hold_the_quarry, on the striker's side of the blow).
-- The Root is the status's own length, which runs out about when the bearer's next turn comes round.
--
-- `unstocked`: the body's own piece, visible on its house's rack and never sold (docs/drops.md).
return {
    name = "Hold the Quarry",
    description = "A foe you bring below a quarter of its health is Rooted until your next turn.",
    flavor = "The pride's whole craft is the moment before the kill, and making it last.",
    sprite = "assets/items/utility_hold_the_quarry.png",
    type = "utility",
    tags = { "charm" },
    class = "hunter",
    unlockLevel = 13,
    unstocked = true,
    traits = { "trait_hold_the_quarry" },
}
