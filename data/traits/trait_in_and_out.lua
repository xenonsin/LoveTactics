-- IN AND OUT: the pack's disengage, granted to a person.
--
-- A FLAG, NOT A HOOK, and that is the shape the engine wanted. Combat.charmGivesGround asks one
-- yes/no question at the seam -- "does this body step back after a melee blow, and how far" -- and this
-- answers it. A hook would have to re-derive what was swung, whether it connected, and whether the
-- thing swung at is still standing, all of which the cast already knows (models/trait.lua, Trait.flag).
--
-- HONOURED IN BOTH DIRECTIONS, like the teeth it is copied from. On the bearer's own turn the step is
-- taken in resolveCast, inside the answer window and before the counters are thrown; when the bearer
-- ANSWERS a blow it is taken in Combat.answerStrike. A skirmisher who counters and then stands in reach
-- to be worked over has bought nothing, which is the same sentence weapon_wolf_fangs' header makes
-- about wolves.
--
-- `givesGround` is the distance AND the flag: Trait.flag returns the trait so the caller reads the
-- magnitude out of the same lookup, and Trait.param lets the item override it. One tile is the figure
-- every hit-and-run thing in this game uses -- the wolf's teeth, the Bloom Reach, Harrying Strike,
-- Vanishing Strike -- because one tile is exactly what a melee counter's reach check costs.
--
-- Sundered gags it, as Trait.flag gags every standing charm rule: a bearer whose relics have gone quiet
-- does not keep the quiet ones working.
return {
    name = "In and Out",
    description = "After a melee blow, step back one tile.",
    givesGround = 1,
}
