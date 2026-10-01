-- THE DANCER'S VEIL: the Elf Bladedancer's drop (data/characters/character_elf_bladedancer.lua). Approved 2026-09-30
-- ("Pride's Bestiary"). Untouchable, cut down to what a company can wear: at full health, the first attack each
-- round that rolls to hit is evaded (trait_dancers_veil, Combat.veilReady). Every armour costs a square of pace.
--
-- `unstocked`: the body's own piece, visible on the duelist's rack and never sold (docs/drops.md).
local Curve = require("models.curve")

return {
    name = "Dancer's Veil",
    description = "While at full health, evade the first attack each round that rolls to hit.",
    flavor = "A length of grey silk worn over one shoulder and flicked across a blade's path.",
    sprite = "assets/items/armor_dancers_veil.png",
    type = "armor",
    tags = { "cloth" },
    class = "duelist",
    unlockLevel = 13,
    unstocked = true,
    traits = { "trait_dancers_veil" },
    bonus = { defense = Curve.ramp(1, 11), movement = -1 },
}
