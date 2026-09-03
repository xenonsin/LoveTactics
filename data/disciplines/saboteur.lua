-- Saboteur -- rogue x alchemist multiclass discipline.
-- Signature mechanic: Planted charges -- stealth-place delayed bombs, detonate on your signal.
-- Exemplar: a demolitions ghost (character_saboteur, NEW -- pending), met as a RECRUIT.
-- Gate: earned advancement -- requires a rogue subclass AND an alchemist subclass unlocked, which
-- opens quest_undercroft_the_collapsed_vault (pending). See docs/disciplines-plan.md.
return {
    name    = "Saboteur",
    description = "The demolitions ghost. Place delayed charges unseen, then detonate them on your own signal.",
    classes = { "rogue", "alchemist" },
    exemplar = "character_saboteur", -- NEW, pending
    requiredLevel = { rogue = 8 }, -- pending
}
