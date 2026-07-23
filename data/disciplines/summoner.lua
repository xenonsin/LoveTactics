-- Summoner -- mage subclass.
-- Signature mechanic: Reserve court -- bank mana to field independent elementals that fight on their
-- own. (The `reserve` summons are the first stock.)
-- Exemplar: a conjurer with an elemental court (character_summoner, NEW -- pending), met as a BOSS.
-- Gate: one quest in the mage (Arcanum) line -- donor_roll. See docs/disciplines-plan.md.
return {
    name    = "Summoner",
    classes = { "mage" },
    exemplar = "character_summoner", -- NEW, pending
    requiredQuests = { "donor_roll" },
}
