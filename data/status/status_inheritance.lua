-- INHERITANCE: a fallen dwarf's Share, carried by the kinsman who took it up (data/traits/
-- trait_inheritance.lua). Each Share is weight: +2 Damage, +2 Defense, -1 Movement. HOARDING AND THE
-- BURDEN OF WEALTH in one badge -- the last dwarf standing is the slowest, the fattest and the richest.
--
-- UNCAPPED, AND THE MOVEMENT IS FLOORED INSTEAD (round 2, 2026-09-24: "Floor the movement"). The first
-- cut capped a dwarf at three Shares so a fourth could not plant it at 0; the review wanted the weight to
-- keep coming and the legs to stop short of nothing. So the per-Share line below is the READOUT, and the
-- live numbers are stamped onto the instance by trait_inheritance every time a Share lands: damage and
-- defense scale with every Share, movement stops cutting one short of the heir's own pace (never below 1).
return {
    name = "Inheritance",
    abbr = "Heir",
    description = "Each Share taken up from a fallen kinsman: increase damage and defense, reduce movement (never below 1).",
    color = { 0.811, 0.700, 0.335 }, -- badge tint (coin gold, greed's colour)
    duration = math.huge,
    hideDuration = true, -- the count is the story
    magnitude = 1,
    stacks = 99, -- a count, not a cap: the whole line can fall into one heir
    statBonus = { damage = 2, defense = 2, movement = -1 },
}
