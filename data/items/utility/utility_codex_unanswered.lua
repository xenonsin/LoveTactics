-- Lifted off Sublimitas (data/characters/character_sublimitas.lua), and it kept her rule (data/traits/
-- trait_already_known.lua): carry the Codex and every spell worked in your sight is written into it, and a spell
-- you have already seen cast this fight is unravelled when it is aimed at you. The first casting of anything
-- still lands -- the book has to read a working before it can answer it.
--
-- A MAGE'S TROPHY (reworked 2026-10-01, when she moved down to Pride's stair): `class = "mage"` and `unstocked`,
-- so the Arcanum's rack shows it greyed and never sells it, and it is a real piece of mage kit rather than a
-- creature's organ. Her own copy of the rule rides on her organ (utility_already_known); this is the one she
-- drops. It answers only what is SHOWN, and teaches its bearer that having the measure of every visible thing
-- is the same as being unbeatable (docs/story.md, "The Arcanum").
--
-- The FLAVOR carries a fragment of the Gate Below's location (docs/item-text.md: story, not a rule). The Gate
-- is keyed off the QUEST finished, never off this item (questGate in models/quest.lua).
local Curve = require("models.curve")

return {
    name = "The Codex Unanswered",
    description = "A spell you have already seen cast this fight is unravelled when aimed at you.",
    flavor = "Sublimitas's book, and it has never met a spell it did not already know. Tooled on the " ..
        "spine: \"where the shelves answer only themselves, and the readers were spent\".",
    sprite = "assets/items/codex_unanswered.png",
    type = "utility",
    class = "mage",
    unlockLevel = 13, -- Pride's stair, where she stands
    unstocked = true, -- her trophy: on the rack, never for sale
    noSteal = true, -- a stair's piece stays with whoever earned it (tests/sin_drops_spec.lua)
    tags = { "relic" },
    traits = { "trait_already_known" },
    bonus = { magicDefense = Curve.ramp(3, 13) },
}
