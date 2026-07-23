-- Bombardier -- alchemist subclass.
-- Signature mechanic: Scatter bombs -- thrown consumables that seed hazards at range and
-- chain-detonate.
-- Exemplar: a counterfeit-bomb runner (character_bombardier, NEW -- pending), met as a BOSS.
-- Gate: one quest in the alchemist (Crucible) line -- crucible_the_counterfeiter.
-- See docs/disciplines-plan.md.
return {
    name    = "Bombardier",
    classes = { "alchemist" },
    exemplar = "character_bombardier", -- NEW, pending
    requiredQuests = { "crucible_the_counterfeiter" },
}
