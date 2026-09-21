-- Herbalist -- hunter x alchemist multiclass discipline.
-- Signature mechanic: Field brewing -- harvest field hazards/plants into consumables mid-fight;
-- nature poisons and heals both.
-- Exemplar: a field-apothecary (character_herbalist, NEW -- pending), met as a RECRUIT.
-- Gate: earned advancement -- requires a hunter subclass AND an alchemist subclass unlocked, which
-- opens quest_alchemist_the_poisoned_glade (pending). See docs/disciplines-plan.md.
return {
    name    = "Herbalist",
    description = "Brews from the ground it stands on. Harvests hazards and growth on the board into "
        .. "consumables mid-fight, and the same stem makes a poison or a cure.",
    exemplar = "character_herbalist", -- NEW, pending
    requires = { hunter = 12, alchemist = 12 },
}
