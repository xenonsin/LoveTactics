-- Bombardier -- alchemist subclass.
-- Signature mechanic: Scatter bombs -- thrown consumables that seed hazards at range and
-- chain-detonate.
-- Exemplar: a counterfeit-bomb runner (character_bombardier, NEW -- pending), met as a BOSS.
-- Gate: one quest in the alchemist (Crucible) line -- by_the_dram (slot 4).
-- A subclass opens no earlier than slot 3: a discipline handed over on a line's first or
-- second quest is not earned advancement, it is a welcome gift.
-- welcome gift.
-- See docs/disciplines-plan.md.
return {
    name    = "Bombardier",
    description = "The thrower. Scatter bombs seed hazards at range and chain-detonate off each other.",
    classes = { "alchemist" },
    exemplar = "character_bombardier", -- NEW, pending
    requiredQuests = { "quest_alchemist_slot_04" },
}
