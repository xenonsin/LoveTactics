-- Elementalist -- mage subclass. The first Tier-A shelf: its stock already exists (the sigils).
-- Signature mechanic: Sigils -- aura tiles that reshape spells cast beside them (careful / twin /
-- range / speed).
-- Exemplar: Gyeom (character_mage), met as a MENTOR -- the mage companion; his unlock deepens him.
-- (Reuse flagged in docs/disciplines-plan.md.)
-- Gate: one quest in the mage (Arcanum) line -- grimoire_ruins. See docs/disciplines-plan.md.
return {
    name    = "Elementalist",
    classes = { "mage" },
    exemplar = "character_mage",
    requiredQuests = { "grimoire_ruins" },
}
