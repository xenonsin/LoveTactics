-- TORMENT: what the Pit Locusts lay ("The Crown's Bestiary", slice C, approved 2026-10-09). From Revelation's locusts
-- out of the bottomless pit: in those days men shall seek death, and shall not find it. A locust's sting cannot take a
-- body below 1 (trait_seek_death), and a body it finds already at 1 is Tormented instead: -3 Damage and -1 Movement a
-- stack, until Cured.
--
-- A DEBUFF WITH NO CLOCK, and that is the rule rather than a convenience. A locust never kills anybody, so what it
-- costs the company has to outlast the swarm, or the swarm costs nothing once it is swatted. A Cure lifts every stack
-- at once, and so does the Lethe's grey water. Capped at three, the point at which a body is no longer worth stinging.
-- The Plague Knight's Torment (ability_torment) lays the same status on any foe it strikes.
return {
    name = "Torment",
    abbr = "Trm",
    description = "Torment: -3 Damage and -1 Movement per stack, until Cured.",
    color = { 0.545, 0.396, 0.204 }, -- badge tint (locust brown)
    duration = math.huge,
    hideDuration = true, -- the count is the story
    debuff = true, -- Cure lifts it
    magnitude = 1,
    stacks = 3,
    statBonus = { damage = -3, movement = -1 },
    statBonusScales = true,
}
