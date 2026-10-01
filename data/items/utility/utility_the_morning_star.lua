-- THE MORNING STAR: Superbia's relic (reviewed over three rounds, "Pride's Generals"). Non Serviam for a person:
-- once per turn, a debuff laid on the bearer rebounds onto whoever laid it (trait_non_serviam, with `oncePerTurn`
-- on and the refusal off -- a second debuff in the same turn lands as any debuff does).
--
-- A Mage's piece, because the mage is the one who will not be told: the Arcanum's whole shelf is a body
-- answering a working with its own. A real class trophy, never a creature drop (the author's rule).
--
-- `unstocked`: a trophy, seen on the rack and never sold (docs/drops.md).
return {
    name = "The Morning Star",
    description = "Once per turn, a debuff laid on you rebounds onto whoever laid it.",
    flavor = "It was the brightest thing in the sky before dawn. It fell, and it is still the brightest thing.",
    sprite = "assets/items/utility_the_morning_star.png",
    type = "utility",
    tags = { "charm", "holy", "relic" },
    class = "mage",
    unlockLevel = 14, -- the seat floor that pays a general's relic, as every circle's does (tests/sin_drops_spec.lua)
    unstocked = true,
    noSteal = true, -- a relic stays with whoever earned it off the body
    traits = { "trait_non_serviam" },
    traitParams = { oncePerTurn = true, refusesAll = false },
}
