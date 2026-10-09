-- OMEN: ENVY, one of the Hollow Crown's seven omens (models/hollow_crown.lua, phase 2; see status_omen_gluttony.lua).
-- The Fairest is Envy's own word (models/fairest.lua): the body holding the most blessings.
return {
    name = "Omen: Envy",
    abbr = "Envy",
    description = "Next turn it names the Fairest and copies the last ability it used. Spread your blessings out.",
    color = { 0.420, 0.700, 0.420 }, -- badge tint (green-eyed)
    duration = 9999,
    hideDuration = true,
    hideLog = true,
    undispellable = true,
}
