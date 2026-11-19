-- GLASS-FED: what a Glass-Eater does with what it takes (data/items/weapon/weapon_vitreous_bite.lua). Creature
-- identity pass, 2026-11-19.
--
-- The eater stripped two blessings a bite and hit for less than anything on its rung, and nothing on floor 11
-- cashed in what it took -- so it was a body you could leave for last. Now every blessing it strips is one stack
-- here, +2 damage each, and the badge prints the count. An eater that has been fed your wards is the thing to kill
-- next, and an eater that has been fed nothing is still the soft body it was.
--
-- IT IS A BLESSING, AND THAT IS THE COUNTERPLAY. Not a debuff and not undispellable, so the company's own Dispel
-- takes the whole meal back off it in one cast -- glass that eats blessings is undone by the same verb.
--
-- Capped at 6 (+12), which is the bite's top-of-band damage again: a well-fed eater hits like a mid-rung body,
-- never like an elite.
return {
    name = "Glass-Fed",
    abbr = "Fed",
    description = "Glass-Fed: +2 damage for each blessing it has stripped, up to 6.",
    color = { 0.560, 0.780, 0.760 }, -- badge tint (pale bottle-glass)
    duration = math.huge,
    hideDuration = true, -- the count is the story
    badgeCount = true,
    magnitude = 1,
    stacks = 6,
    statBonus = { damage = 2 },
    statBonusScales = true,
}
