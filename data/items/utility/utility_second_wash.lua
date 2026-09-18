-- THE SECOND WASH: Livia's rule, cut down, and the mini sin's whole reason to exist.
--
-- Livia's Envious Glass looks across the field at the OPENING BELL and stands a copy of your STRONGEST
-- body on her own side (data/traits/trait_covetous_reflection.lua). Meeting that cold is a fight whose
-- read you lost before anybody moved: your best unit is suddenly on the wrong side and you were never
-- offered a turn in which to prevent it.
--
-- So the honour-guard floor teaches it in the opposite direction and at half the price:
--
--   from the bell   nothing. It is a body with a bite.
--   at 50%          Lesser Reflection: it copies the WEAKEST body it can see, once
--
-- The copy arrives late, arrives small, and arrives after the player has had several turns to work out
-- what this circle is about. Then the stair goes down to Livia, who takes the best one before anybody
-- has moved -- and the mechanic is already paid for.
--
-- THAT IS THE RULE FOR THE WHOLE TIER: a mini sin's second phase is its general's first.
--
-- "Second water" is the alchemist's term for the thinner wash you get running the process again over
-- what is left -- the Crucible's own vocabulary, and a name for the body that says what it IS without
-- naming what it does.
--
-- Natural kit: no class, no price, noSteal (tests/bestiary_spec.lua).
return {
    name = "Second Wash",
    description = "Once wounded, it takes the shape of the weakest foe, and it fights for the mirror.",
    flavor = "Everything worth keeping came out on the first pass. This is what the Crucible poured away.",
    sprite = "assets/items/second_wash.png",
    type = "utility",
    class = "creature",
    tags = { "natural" },
    noSteal = true,
    -- The reflection IS the phase, so the trait carries its own 50% gate and no boss_phases table is
    -- needed beside it. A second phase engine on top would fire two rules at one threshold and make the
    -- tier's one-phase promise a lie.
    traits = { "trait_lesser_reflection" },
}
