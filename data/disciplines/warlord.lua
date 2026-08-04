-- Warlord -- fighter subclass.
-- Signature mechanic: Banner zones -- planted banners project stacking aura fields the party fights
-- inside of.
-- Exemplar: The Warlord (character_warlord), met as a BOSS -- the shelf is already named after him.
-- Gate: one quest in the fighter (Colosseum) line -- warlord_keep. See docs/disciplines-plan.md.
return {
    name    = "Warlord",
    description = "The commander. Planted banners project stacking aura fields the party fights inside of.",
    classes = { "fighter" },
    exemplar = "character_warlord",
    requiredQuests = { "quest_colosseum_slot_03" },
}
