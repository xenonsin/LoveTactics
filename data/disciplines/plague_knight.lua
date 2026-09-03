-- Plague Knight -- knight x alchemist multiclass discipline.
-- Signature mechanic: Contagion -- melee spreads poison, and standing adjacent to you sickens
-- enemies. A walking miasma tank.
-- Exemplar: the Forsworn Knight (character_forsworn_knight), met as a BOSS -- the fallen oath rotted
-- from within is what this discipline already is.
-- Gate: earned advancement -- requires a knight subclass AND an alchemist subclass unlocked, which
-- opens quest_bastion_the_rot_beneath_the_plate (pending). See docs/disciplines-plan.md.
return {
    name    = "Plague Knight",
    description = "A walking miasma. Melee spreads poison, and standing next to you sickens whoever is standing there.",
    classes = { "knight", "alchemist" },
    exemplar = "character_plague_knight", -- was character_forsworn_knight (a story-critical Bastion enemy); dedicated exemplar authored
    requiredLevel = { knight = 6 }, -- pending
}
