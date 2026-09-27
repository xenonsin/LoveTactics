-- SNAPPED: an oni whose horn a critical hit broke (data/traits/trait_the_horn.lua). Reviewed 2026-09-26/27
-- ("The Oni of Wrath"): "the horn carries physical AND magical resist", read as a weakness once it is gone.
--
-- The horn (utility_oni_blood) gives +1 to slash, impact and pierce and +2 Magic Defense. This lays +2 damage on
-- each physical type and -4 Magic Defense on top, so a snapped oni stands at -1 and -2: open to every weapon and
-- every school. Its magic lived in the horn, so it can cast nothing that costs mana for the rest of the fight,
-- and it can never go Horn Out again (the trait asks for this status first).
--
-- NOT A DEBUFF, on purpose: `debuff = true` would put a snapped horn in the reach of Cure and of the Oni
-- Priestess's own Purifying Bell, and a horn does not grow back because somebody prayed.
return {
    name = "Horn Snapped",
    abbr = "Snap",
    description = "Horn snapped: takes 2 more damage from slash, impact and pierce, magic defense is reduced by 4, and mana abilities cannot be cast.",
    color = { 0.560, 0.500, 0.470 }, -- badge tint (bone)
    duration = math.huge,
    hideDuration = true,
    debuff = false,
    vulnerable = { slash = 2, impact = 2, pierce = 2 },
    statBonus = { magicDefense = -4 },
    silencesMana = true,
}
