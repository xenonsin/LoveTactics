-- What a MOSS SLIME has instead of a hide (data/characters/character_moss_slime.lua): the Amorphous
-- Body (data/items/utility/utility_amorphous_body.lua) grown over with the wood, and softer for it.
--
-- A RESIST, NOT AN IMMUNITY, AND THAT IS THE WHOLE DIFFERENCE. The fen's slimes void steel outright,
-- which is a lesson a company can only answer by having found an element -- and the wood is where a
-- descent OPENS, walked by a pair who have not (Descent.isOpeningFloor). So the wood's slimes ask the
-- same question softly: steel still lands, for a sliver, and an element lands whole. A company with
-- only blades wins the long way round; one that brought fire wins the short way. The fen then asks it
-- categorically, four floors down, of a company that has had the time to answer it.
--
-- Carried on the relic rather than on the blueprint's own `resist`, because Balance.INNATE_PHYSICAL
-- holds a creature's innate lines to a zero sum -- a body is tougher against one weapon and softer
-- against another -- and this one is tougher against every weapon at once. That is a property of the
-- thing it IS, which is what a bound relic is for, and it keeps the innate table honest.
--
-- The adaptation rides along unchanged (trait_adaptive), so the elemental rhythm the fen charges for is
-- taught here first: throw fire, it burns and stops burning; throw ice and it hits back cold.
return {
    name = "Mossy Body",
    description = "Blades, points and blows barely get through. Takes on the element of whatever does.",
    flavor = "The moss is the part that keeps. The rest of it is just wet.",
    sprite = "assets/items/mossy_body.png",
    type = "utility",
    class = "creature",
    tags = { "relic" },
    bound = true,
    noSteal = true, -- a creature's body is not loot
    resist = { slash = 12, pierce = 12, impact = 12 },
    traits = { "trait_adaptive" },
}
