-- ALREADY KNOWN: Sublimitas's own (data/characters/character_sublimitas.lua). It carries the rule her fight is
-- about (trait_already_known): every spell cast in her sight becomes Known, and a Known spell aimed at her is
-- unravelled.
--
-- `bound`, `noSteal`, `class = "creature"`: an organ, never handed to the player. What she hands over is the
-- Codex Unanswered, on her `drops` list.
return {
    name = "Already Known",
    description = "Spells cast in her sight become Known. A Known spell aimed at her is unravelled.",
    flavor = "She has only to see a working once. She has never once been shown one twice.",
    sprite = "assets/items/utility_already_known.png",
    type = "utility",
    class = "creature",
    tags = { "relic" },
    bound = true,
    noSteal = true, -- a creature's body is not loot
    traits = { "trait_already_known" },
}
