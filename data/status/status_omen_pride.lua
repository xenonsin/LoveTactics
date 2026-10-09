-- OMEN: PRIDE, one of the Hollow Crown's seven omens (models/hollow_crown.lua, phase 2; see status_omen_gluttony.lua).
return {
    name = "Omen: Pride",
    abbr = "Prd",
    description = "Next turn the last body to cast a spell is Magic Denied for 3 turns. Vary who casts.",
    color = { 0.452, 0.452, 0.513 }, -- badge tint (Magic Denied's leaden grey)
    duration = 9999,
    hideDuration = true,
    hideLog = true,
    undispellable = true,
}
