-- RETAINED: the readout for the Retainer's Oath (models/elf_court.lua; the creature identity pass, 2026-11-19). An
-- Unblemished elf with a Retainer sworn beside it wears this, so the company can see which elf a blow will not reach.
--
-- A BADGE AND NOTHING ELSE. The redirect reads the retainer's guard, not this status, so a Dispel that strips it
-- changes no blow; ElfCourt.badges lays it again at the next turn's edge. Not a debuff, so no Cure touches it.
return {
    name = "Retained",
    abbr = "Ret",
    description = "Retained: a Retainer beside it takes the blows meant for it.",
    color = { 0.780, 0.720, 0.520 }, -- badge tint (a duller gold than Unblemished's)
    duration = math.huge,
    hideDuration = true,
}
