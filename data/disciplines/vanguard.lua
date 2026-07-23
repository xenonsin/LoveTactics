-- Vanguard -- knight x rogue multiclass discipline.
-- Signature mechanic: Breach -- knockback that strips guard/armor, punching a hole in the line for
-- allies to pour through.
-- Exemplar: a shieldbreaker turncoat (character_vanguard, NEW -- pending), met as a BOSS.
-- Gate: earned advancement -- requires a knight subclass AND a rogue subclass unlocked, which opens
-- the_salted_gate (pending). See docs/disciplines-plan.md.
return {
    name    = "Vanguard",
    classes = { "knight", "rogue" },
    exemplar = "character_vanguard", -- NEW, pending
    requiredQuests = { "the_salted_gate" }, -- pending
}
