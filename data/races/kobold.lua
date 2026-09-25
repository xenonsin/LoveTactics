-- Kobold: dog-faced, dragon-worshipping folk of Greed's deeps, the second race in the circle beside the
-- dwarves. Reviewed over two rounds, 2026-09-24/25 ("The Kobolds of Greed").
--
-- NOT GREEDY FOR GOLD. That was the note that decided the line -- "Kobolds don't care about gold" -- and
-- it is the whole difference between the two races who share these caves. A dwarf goes for the heap and
-- sickens on it; a kobold walks straight over one on its way to its dragon. What a kobold wants is to be
-- near the dragon, to brood its eggs, and at the last to give itself to the Godling. Greed, in these
-- caves, is the dwarves' sin; the kobolds' is only that they would die for a god that eats them.
--
-- THE PHYSICAL THREE SUM TO ZERO (+1 pierce, +1 impact, -2 slash), the innate contract held: small enough
-- that a point misses, light enough to roll with a hammer, and a blade opens thin scales. So the two races
-- of this circle want different weapons -- a hammer for the dwarves, a sword for the kobolds. No element:
-- the dwarves already take fire, and two races resisting one element in one circle would flatten it.
--
-- THE STAT LINE is quick feet. The review approved movement +1, speed +1 AND defense -1, and that is
-- three points against a racial budget of two (Race.STAT_BUDGET). The budget stands; the brittleness is
-- authored on each kobold's own stat block instead, where a low Defense is a body's fact and not a race's.
--
-- UNDERFOOT IS GRANTED rather than authored into five grids (utility_underfoot): Pack and Devotion, the
-- two rules that make a kobold a kobold. Bound and unstealable -- an organ, not kit.
--
-- PLAYABLE (approved): a company may hire one, and a hired kobold wears Underfoot too -- it fights harder
-- beside its kin and near a dragon, and a company carrying the Godling's Scale IS its dragon.
return {
    name = "Kobold",
    description = "Small, quick, dog-faced folk who worship dragons. Dangerous in a pack, and fearless near their god.",
    kind = "humanoid",
    resist = {
        pierce = 1,  -- small enough that a point misses...
        impact = 1,  -- ...light enough to roll with a hammer...
        slash = -2,  -- ...and a blade opens thin scales. Sums to zero.
    },
    bonus = {
        movement = 1, -- quick feet
        speed = 1,    -- and quicker to act
    },
    grants = { "utility_underfoot" },
}
