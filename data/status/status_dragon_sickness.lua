-- DRAGON-SICKNESS: what gold does to a dwarf. Thorin's sickness under the Mountain, reviewed 2026-09-24
-- (round 3, "The Dwarves of Greed"), on Keno's round-2 note on the heaps: "have heaps collected give them
-- a buff that stacks".
--
-- Each coin heap a dwarf pockets (data/hazards/hazard_coin_heap.lua) is one stack: +2 Damage and -1
-- Defense, with no cap, for the rest of the fight -- a sick dwarf hits harder and stops watching its
-- guard, so greed blinds even before Gold Fever does. The stacks pass to the heir with Inheritance, the
-- way the gold does (data/traits/trait_inheritance.lua), so a heap left on the floor is a threat whoever
-- reaches it, and it stays one after they fall.
return {
    name = "Dragon-Sickness",
    abbr = "Sick",
    description = "Each heap of gold pocketed: increase damage, reduce defense.",
    color = { 0.760, 0.560, 0.220 }, -- badge tint (tarnished gold)
    duration = math.huge,
    hideDuration = true, -- the count is the story
    magnitude = 1,
    stacks = 99, -- a count, not a cap
    statBonus = { damage = 2, defense = -1 },
    statBonusScales = true,
}
