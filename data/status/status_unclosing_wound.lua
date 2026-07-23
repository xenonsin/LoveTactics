-- Unclosing Wound: the cut will not knit. Nothing mends this body while it holds -- not a spell, not
-- a potion, not a Regeneration tick, not a lifesteal drink, not the priest's Sanctified Presence.
-- Combat.applyHeal refuses at the top, which is the single funnel every mend in the game runs through,
-- so one flag closes all of them at once and none of them can route around it.
--
-- THE GAP IT FILLS. Every other debuff in this catalog makes a body take more or do less. None of them
-- touched the lever that actually decides whether a focused kill FINISHES: the enemy priest. A party
-- could commit three turns to dropping a target and watch one cast undo the lot, and the only answer
-- the game offered was "kill the priest first", which is the same problem moved one tile.
--
-- Deliberately total rather than a percentage. A heal cut to 40% is arithmetic the healer answers with
-- a bigger heal; a heal that does not happen is a DECISION they have to answer some other way -- cleanse
-- it, or spend the turn elsewhere. That is the same reasoning the cast ward is built on, and it is why
-- the duration is short and the status is an ordinary cleansable debuff on the physical school. It
-- takes a window away, not a healer.
return {
    name = "Unclosing Wound",
    abbr = "Uncl",
    description = "Unclosing: cannot be healed by any means.",
    color = { 0.62, 0.10, 0.16 }, -- badge tint (dark arterial red)
    duration = 10,                -- ~2 turns: long enough to finish what it was opened for
    debuff = true,
    resistible = "physical",      -- warded by defense + statusResist, halved on every repeat
    blocksHealing = true,
}
