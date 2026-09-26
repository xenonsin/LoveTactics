-- THE BONE WYRM: a dwarf that fell as a Gilt Wyrm, stood back up by the Paymaster's reveal
-- (models/paymaster.lua). Reviewed over five rounds, 2026-09-25/26 ("The Paymaster"). Nothing fields it
-- directly; the raise mints it where the wyrm fell, on the Paymaster's side, at the fallen dwarf's level.
--
-- WHAT IT WAS, PLUS UNDEAD. It extends character_gilt_wyrm.lua the way the Dwarf Skeleton extends the Delver:
-- the shape, the sprite (redrawn in bone by Bare Bones' skin), the race, the hide and the drop list are the
-- wyrm's, and `undead = true` is what happened to it (models/character.lua) -- Grave-Cold comes with the tag,
-- the lattice and the picture come with Bare Bones.
--
-- IT KEEPS THE BITE AND THE BREATH, AND LOSES WHAT WAS THE GOLD'S. The Gilt Maw and the Venom Breath are a
-- dragon's and stay; Dread and Stout were the sickness in it -- the helm of terror a hoard wears, and a dwarf's
-- pull toward loose gold -- and a skeleton covets nothing. So it never pockets a heap, and once the Paymaster
-- has turned the heaps he threw are the company's alone.
--
-- ITS DROPS ARE THE GILT WYRM'S LIST, unchanged: no new pieces, the same saga paid off a second time.
local base = require("data.characters.character_gilt_wyrm")

local dead = {}
for k, v in pairs(base) do dead[k] = v end

dead.name = "Bone Wyrm"
dead.undead = true

dead.stats = {}
for k, v in pairs(base.stats) do dead.stats[k] = v end

dead.startingItems = {
    "weapon_gilt_maw",    "ability_venom_breath", false,
    "utility_bare_bones", false,                  false,
    false,                false,                  false,
}
dead.drops = {}
for i, id in ipairs(base.drops) do dead.drops[i] = id end

return dead
