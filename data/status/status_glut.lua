-- GLUT: what the Godling has eaten (data/traits/trait_the_tithe.lua). Each kobold that gives itself up is
-- one stack: +2 Damage, +2 Defense, no cap, for the rest of the fight -- unless a critical finds the bare
-- patch (trait_bare_patch), which strips them all at once.
return {
    name = "Glut",
    abbr = "Glut",
    description = "Each worshipper devoured: increase damage and defense. A critical hit strips it all.",
    color = { 0.700, 0.250, 0.200 }, -- badge tint (dragon red)
    duration = math.huge,
    hideDuration = true, -- the count is the story
    magnitude = 1,
    stacks = 99, -- a count, not a cap
    statBonus = { damage = 2, defense = 2 },
    statBonusScales = true,
}
