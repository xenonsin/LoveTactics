-- OVER THE DEEPS: Avaritia's second third (reviewed 2026-09-25, "Avaritia, the Unspent"). Laid by her phase
-- relic at 60% of her health and lifted at 30%; while she wears it her strafe (ability_strafe) is live -- she
-- takes wing, marks a whole row or column of the cavern a turn ahead, burns it and lands at its far end, on
-- a cooldown. A badge that tells the company which third of the fight it is in.
--
-- Named apart from the Griffin's On the Wing (status_on_the_wing), which is a different rule.
return {
    name = "Over the Deeps",
    abbr = "Sky",
    description = "Takes to the air between blows and strafes the cavern in lines of fire.",
    color = { 0.900, 0.420, 0.180 }, -- badge tint (fire from above)
    duration = math.huge,
    hideDuration = true,
}
