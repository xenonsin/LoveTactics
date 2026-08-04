-- Herbalist -- hunter x alchemist multiclass discipline.
-- Signature mechanic: Field brewing -- harvest field hazards/plants into consumables mid-fight;
-- nature poisons and heals both.
-- Exemplar: a field-apothecary (character_herbalist, NEW -- pending), met as a RECRUIT.
-- Gate: earned advancement -- requires a hunter subclass AND an alchemist subclass unlocked, which
-- opens quest_alchemist_the_poisoned_glade (pending). See docs/disciplines-plan.md.
return {
    name    = "Herbalist",
    description = "The field brewer. Harvests the ground's own hazards and growth into consumables mid-fight; the same stem poisons and cures.",
    classes = { "hunter", "alchemist" },
    exemplar = "character_herbalist", -- NEW, pending
    requiredQuests = { "quest_alchemist_the_poisoned_glade" }, -- pending
}
