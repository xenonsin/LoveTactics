-- Battlemage -- fighter x mage multiclass discipline. (Named in models/growth.lua years before it
-- could be sold.)
-- Signature mechanic: Spellstrike -- fold a cantrip into a melee swing (cast on hit).
-- Exemplar: a spell-and-steel veteran (character_battlemage, NEW -- pending), met as a BOSS.
-- Gate: earned advancement -- requires a fighter subclass AND a mage subclass unlocked, which opens
-- the_broken_siege (pending). See docs/disciplines-plan.md.
return {
    name    = "Battlemage",
    classes = { "fighter", "mage" },
    exemplar = "character_battlemage", -- NEW, pending
    requiredQuests = { "the_broken_siege" }, -- pending
}
