-- OMEN: SLOTH, one of the Hollow Crown's seven omens (models/hollow_crown.lua, phase 2; see status_omen_gluttony.lua).
-- Stillness is measured from the moment this goes up (Desidia's Drowse, models/desidia.lua).
return {
    name = "Omen: Sloth",
    abbr = "Slth",
    description = "Next turn every body that has not moved since this omen grows Drowsy. Keep moving.",
    color = { 0.600, 0.660, 0.820 }, -- badge tint (Drowsy's snow-light blue)
    duration = 9999,
    hideDuration = true,
    hideLog = true,
    undispellable = true,
}
