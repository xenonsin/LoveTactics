-- Necromancer -- mage subclass.
-- Signature mechanic: Corpse-raise -- enemies that die on the field rise as your undead.
-- Exemplar: a radical of the Arcanum (character_necromancer, NEW -- pending), met as a BOSS.
-- Gate: one quest in the mage (Arcanum) line -- arcanum_the_radical. See docs/disciplines-plan.md.
return {
    name    = "Necromancer",
    classes = { "mage" },
    exemplar = "character_necromancer", -- NEW, pending
    requiredQuests = { "arcanum_the_radical" },
}
