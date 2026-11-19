-- SWORN RETAINER: the Elf Retainer's organ (data/characters/character_elf_retainer.lua; the creature identity pass,
-- 2026-11-19). It carries the Retainer's Oath (trait_retainers_oath): beside an Unblemished elf, the retainer takes
-- every blow meant for it, and that elf wears Retained.
--
-- `bound`, `noSteal`, `class = "creature"`: a creature's organ is never handed to the player. What the fight hands
-- over is on the body's `drops` list instead (the Livery of the House).
return {
    name = "Sworn Retainer",
    description = "Takes every blow meant for an Unblemished elf beside it.",
    flavor = "It was promised to the house before it could walk. Nobody has asked it what it wanted since.",
    sprite = "assets/items/utility_sworn_retainer.png",
    type = "utility",
    class = "creature",
    tags = { "natural" },
    bound = true,
    noSteal = true, -- a creature's body is not loot
    traits = { "trait_retainers_oath" },
}
