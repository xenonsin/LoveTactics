-- OMEN: GLUTTONY, one of the Hollow Crown's seven omens (models/hollow_crown.lua, phase 2; slice D). The Crown shows
-- a want over its head a turn before it acts it, so the company always has one turn to answer: the badge names the
-- want, and its description names the answer. Seven files rather than one relabelled status, because the badge
-- itself has to say WHICH want -- the same pattern Immune: Fire and its kin follow.
--
-- A readout, not a blessing: `undispellable` and `hideLog`, so no strip or grey water takes the warning away.
return {
    name = "Omen: Gluttony",
    abbr = "Glut",
    description = "Next turn it Swallows the nearest body. Deal a tenth of its health to free it.",
    color = { 0.520, 0.600, 0.280 }, -- badge tint (the Swallowed bog-green)
    duration = 9999,
    hideDuration = true,
    hideLog = true,
    undispellable = true,
}
