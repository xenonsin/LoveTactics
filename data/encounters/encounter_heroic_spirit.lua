-- Encounter blueprint. A HEROIC SPIRIT: somebody who went down here and did not come back up, still
-- standing where they fell, who hands you the means to call somebody else through.
--
-- THIS IS THE OLD RECRUIT STOP, REBUILT AROUND THE THING IT SHOULD ALWAYS HAVE GIVEN. The stop used to
-- hand over a BODY -- a survivor met on the floor who walked out with you -- and it was removed because
-- it latched shut: a company held four, nothing ever left it, and the stop stopped seating the moment
-- it was full, which was the second floor of the first run. The place was good. What it paid was the
-- problem.
--
-- So it pays a TOKEN now (models/voucher.lua). Nothing about it can latch: there is no roster cap on a
-- purse, so a floor can always afford to put one of these on the board, and what the player does with
-- it is a decision taken later at the Crossing rather than on the spot.
--
-- IT ALSO FIXES THE FICTION IT USED TO STRAIN. A living survivor standing patiently on floor nine, in a
-- place the game says has swallowed four companies, was a body the world had to explain. A spirit is
-- what the floors are actually full of, and handing you a way to call somebody through is the one thing
-- a dead adventurer is well placed to do.
--
-- `kind = "spirit"`: a non-combat modal, resolved in states/game.lua's resolveNonCombat, which is where
-- the grant happens. A NEW kind rather than the retired `recruit` one, because the two mean different
-- things -- that one put a body in the company and this one puts a token in the purse -- and a spec
-- pins that no `recruit` blueprint comes back (tests/descent_recruit_spec.lua).
--
-- `weight = 0`: authored-only, like the Rest, so it never turns up on a rolled campaign board and never
-- clusters. The descent's per-floor guarantee is the only thing that seats it
-- (models/descent.lua's guaranteeKinds).
return {
    name = "A Heroic Spirit",
    kind = "spirit",
    weight = 0,
    minDay = 1,
    description = "Somebody who came down here and stayed. They have nothing left to carry and no way " ..
        "back up, so they give you what they still have: a name, and the means to call it.",
}
