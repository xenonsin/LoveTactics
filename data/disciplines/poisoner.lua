-- Poisoner -- alchemist subclass. A Tier-A shelf: its stock already exists (the coatings).
-- Signature mechanic: Coatings -- depleting weapon infusions applied between swings.
-- Exemplar: a vat-master (character_poisoner, NEW -- pending), met as a BOSS.
-- Gate: one quest in the alchemist (Crucible) line -- the_vats. See docs/disciplines-plan.md.
return {
    name    = "Poisoner",
    description = "The vat-master. Coatings: depleting weapon infusions applied between swings.",
    classes = { "alchemist" },
    exemplar = "character_poisoner", -- NEW, pending
    hire = "character_zosia",
    requiredQuests = { "quest_alchemist_slot_05" },
}
