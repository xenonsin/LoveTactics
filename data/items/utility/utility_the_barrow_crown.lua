-- THE BARROW CROWN: the machinery of the Skeleton King, and the third and last statement of the rule
-- this whole line of bodies is built on.
--
-- A boss's identity is machinery, not a shelf (docs/bestiary.md), and this is all of it. Two traits,
-- neither of them new in kind:
--
--   BONE-KNIT       the same refusal to fall the Barrow Lord wears and the same one Marrowlight sells
--                   the player (data/traits/trait_bone_knit.lua). Killed, it stands back up WHOLE, for
--                   mana. Nothing about it is special-cased for being on a king.
--   COURT OF BONE   what IS special. It pins the King's mana to thirty per standing subject
--                   (data/traits/trait_court_of_bone.lua), so the pool Bone-Knit spends from is not a
--                   resource at all -- it is a headcount.
--
-- THE TWO TOLLS ARE ONE NUMBER, and that is the whole readout. Thirty per subject, thirty per rise:
-- one body on the floor is exactly one death refused, so the blue bar the player has already been
-- taught to watch (the Lord's fight) now reads as "how many of these are left". Clear the room and the
-- bar empties itself; then the King dies like anything else. No badge, no tutorial, no new widget.
--
-- IT DOES NOT MAKE THE KING UNKILLABLE, and the file it leans on says why at length: between two deaths
-- the pool does not refill, so a company that ignores the court can grind three whole bars instead. The
-- door is open and it costs five times as much, which is the correct shape for a lesson -- the clever
-- line is cheaper, the stubborn line still works, and nobody is told which is which.
--
-- Unpriced, `class = "creature"`, noSteal, bound: a crown nobody takes off a king. It is on the far
-- side of every shelf, which is exactly what separates the King's version of the rule from the one the
-- player earns (data/items/utility/utility_marrowlight.lua).
return {
    name = "The Barrow Crown",
    description = "Consume 30 mana when a blow would fell this body, and it stands back up at full health. Its mana is its court.",
    flavor = "It was put on him by people who wanted him to stay where he was. It is not clear that anybody checked whether it would work the other way.",
    sprite = "assets/items/the_barrow_crown.png",
    type = "utility",
    class = "creature",
    tags = { "dark", "relic" },
    noSteal = true,
    bound = true, -- a crown does not come off a king, and a thief may not lift the fight off him
    traits = { "trait_bone_knit", "trait_court_of_bone" },
    -- ONE NUMBER, DECLARED TWICE, exactly as The Whetted Vow declares its divisor and its multiplier:
    -- the rise costs what a subject is worth, so the headcount and the pool are the same reading. An
    -- implicit second number here would be a mechanic nobody could find.
    traitParams = {
        cost = { stat = "mana", amount = 30 },
        per = 30,
    },
}
