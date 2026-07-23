-- Spellbreaker -- knight x mage multiclass discipline.
-- Signature mechanic: Counterspell -- melee that interrupts an enemy channel and negates the next
-- spell cast nearby. The anti-caster.
-- Exemplar: an anti-mage sword-oath (character_spellbreaker, NEW -- pending), met as a BOSS.
-- Gate: earned advancement -- requires a knight subclass AND a mage subclass unlocked, which opens
-- the_silenced_tower (pending). See docs/disciplines-plan.md.
return {
    name    = "Spellbreaker",
    classes = { "knight", "mage" },
    exemplar = "character_spellbreaker", -- NEW, pending
    requiredQuests = { "the_silenced_tower" }, -- pending
}
