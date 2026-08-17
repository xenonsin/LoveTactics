-- Shaman -- hunter x mage multiclass discipline.
-- Signature mechanic: Spirit totems -- summon elemental spirits bound to hazards; nature magic that
-- fights on its own.
-- Exemplar: a spirit-caller (character_shaman, NEW -- pending), met as a MENTOR.
-- Gate: earned advancement -- requires a hunter subclass AND a mage subclass unlocked, which opens
-- quest_hunters_lodge_the_spirit_wood (pending). See docs/disciplines-plan.md.
return {
    name    = "Shaman",
    description = "The spirit-caller. Summons elemental spirits bound to the hazards they stand in, and leaves them to fight on their own.",
    classes = { "hunter", "mage" },
    exemplar = "character_shaman", -- NEW, pending
    hire = "character_ondo",
    requiredQuests = { "quest_hunters_lodge_the_spirit_wood" }, -- pending
}
