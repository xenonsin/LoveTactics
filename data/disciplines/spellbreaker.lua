-- Spellbreaker -- knight x mage multiclass discipline.
-- Signature mechanic: Counterspell -- melee that interrupts an enemy channel and negates the next
-- spell cast nearby. The anti-caster.
-- Exemplar: an anti-mage sword-oath (character_spellbreaker, NEW -- pending), met as a BOSS.
-- Gate: earned advancement -- requires a knight subclass AND a mage subclass unlocked, which opens
-- quest_arcanum_the_silenced_tower (pending). See docs/disciplines-plan.md.
return {
    name    = "Spellbreaker",
    description = "The anti-caster. Melee that interrupts a channel and negates the next spell cast nearby.",
    classes = { "knight", "mage" },
    exemplar = "character_spellbreaker", -- NEW, pending
    requiredQuests = { "quest_arcanum_the_silenced_tower" }, -- pending
}
