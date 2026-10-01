-- THE SKYWALKER'S SANDALS: the Elf Starcaller's drop (data/characters/character_elf_starcaller.lua). Approved
-- 2026-09-30 ("Pride's Bestiary"). The Starcaller's first rule (Born to the Height, reworked into By Starlight on
-- 2026-10-01; the sandals were kept), worn anywhere: no hostile ground does anything to the
-- wearer, and standing in it the wearer casts for +2 Magic Damage (trait_skywalker, Hazard.shrugs). Armour, so it
-- costs its square like every other piece.
--
-- `unstocked`: the body's own piece, visible on the mage's rack and never sold (docs/drops.md).
local Curve = require("models.curve")

return {
    name = "Skywalker's Sandals",
    description = "Immune to ground hazards. Increase magic damage by 2 while standing on one.",
    flavor = "Thin soles of pale leather laced to the knee, without a scuff on them.",
    sprite = "assets/items/armor_skywalkers_sandals.png",
    type = "armor",
    tags = { "cloth", "arcane" },
    class = "mage",
    unlockLevel = 13,
    unstocked = true,
    traits = { "trait_skywalker" },
    bonus = { magicDefense = Curve.ramp(1, 11), movement = -1 },
}
