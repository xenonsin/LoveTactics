-- Shaman -- hunter x mage multiclass discipline.
-- Signature mechanic: Spirit totems -- summon elemental spirits bound to hazards; nature magic that
-- fights on its own.
-- Exemplar: a spirit-caller (character_shaman, NEW -- pending), met as a MENTOR.
-- Gate: earned advancement -- requires a hunter subclass AND a mage subclass unlocked, which opens
-- the_spirit_wood (pending). See docs/disciplines-plan.md.
return {
    name    = "Shaman",
    classes = { "hunter", "mage" },
    exemplar = "character_shaman", -- NEW, pending
    requiredQuests = { "the_spirit_wood" }, -- pending
}
