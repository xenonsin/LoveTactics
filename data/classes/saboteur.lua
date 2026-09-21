-- Saboteur -- rogue x alchemist multiclass discipline.
-- Signature mechanic: Planted charges -- stealth-place delayed bombs, detonate on your signal.
-- Exemplar: a demolitions ghost (character_saboteur, NEW -- pending), met as a RECRUIT.
-- Gate: earned advancement -- requires a rogue subclass AND an alchemist subclass unlocked, which
-- opens quest_undercroft_the_collapsed_vault (pending). See docs/disciplines-plan.md.
return {
    name    = "Saboteur",
    description = "Plants charges and picks the moment. Explosives are placed on tiles unseen and set off "
        .. "on your own signal rather than on a timer.",
    exemplar = "character_saboteur", -- NEW, pending
    requires = { rogue = 14, alchemist = 14 },
}
