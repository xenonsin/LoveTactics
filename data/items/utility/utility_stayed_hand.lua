-- The Stayed Hand: a thin bronze disc, warm to the touch. When its wearer is cut down to nearly
-- nothing, something intervenes -- every affliction on them is stripped, and they are lifted out of
-- the fight for a moment (data/traits/trait_stayed_hand.lua).
--
-- THE INSURANCE POLICY, and it is a genuinely different one from the two this game already had. Last
-- Stand and Survivor's Reflex keep a body ALIVE through the blow that would have ended it, which is
-- useful and frequently pointless: surviving at one health in the middle of four enemies buys a turn
-- the next enemy takes away again. This buys the thing that actually saves somebody, which is being
-- UNREACHABLE -- nothing can aim at a Suspended unit at all.
--
-- Priced at exactly what that is worth. The suspension costs the wearer their own next turn (it shoves
-- them down the order), the cleanse fires whether or not there was anything worth cleansing, and the
-- whole thing is on a sixty-tick cooldown, so it is once a fight rather than once a corner. A wearer
-- saved by it comes back down having lost tempo and gained nothing but distance -- which is the right
-- shape for a thing nobody can plan around.
--
-- THE LIMITATION IS REAL AND THE ITEM SAYS SO. It hangs on onDamaged, which only ever sees a SURVIVOR
-- (Trait.onDamaged is not called on a killing blow), so a single hit large enough to kill outright
-- goes straight past it. The Stayed Hand answers attrition, not execution -- and the party that dies
-- to one enormous swing will get no help from it at all.
return {
    name = "The Stayed Hand",
    description = "At the edge of death, cleanses its wearer and lifts them out of reach for a moment.",
    flavor = "Nobody agrees on whose hand. Everyone who has felt it agrees it was not theirs.",
    sprite = "assets/items/utility_stayed_hand.png",
    type = "utility",
    tags = { "holy" },
    class = "priest",
    price = 500,
    repRank = 5,
    traits = { "trait_stayed_hand" },
    bonus = { magicDefense = { 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6 } },
}
