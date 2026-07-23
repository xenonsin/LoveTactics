-- Poisoner -- alchemist subclass. A Tier-A shelf: its stock already exists (the coatings).
-- Signature mechanic: Coatings -- depleting weapon infusions applied between swings.
-- Exemplar: a vat-master (character_poisoner, NEW -- pending), met as a BOSS.
-- Gate: one quest in the alchemist (Crucible) line -- the_vats. See docs/disciplines-plan.md.
return {
    name    = "Poisoner",
    classes = { "alchemist" },
    exemplar = "character_poisoner", -- NEW, pending
    requiredQuests = { "the_vats" },
}
