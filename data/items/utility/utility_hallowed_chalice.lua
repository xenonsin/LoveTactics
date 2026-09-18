-- The Priest's signature relic: the chalice they never set down, which consecrates the ground they
-- stand on. It carries the Priest's innate (data/traits/sanctified_presence.lua) -- each tick, every
-- ally standing adjacent (and the Priest) heals a little. Like Overchannel it hangs no hook; the
-- recovery loop reads it via Trait.has, and Trait.attach finds it on this item where it once sat on
-- the char.
--
-- IT IS NOT A CENSER, though it was called one until the rename. `censer` is a weapon family
-- (docs/weapons.md) and the family's whole claim is `incense` -- ground that is lifted and laid again
-- wherever the bearer walks. This lays no ground and swings at nobody. A liturgical name is not
-- membership in a weapon family, and docs/classes.md used to cite this item's old name as proof the
-- family was the Cathedral's alone; the real censers carry that argument on their own.
--
-- `bound = true` (models/item.lua): never moved, stowed, given, sold, or stolen -- only forged. It is
-- in no blueprint's starting grid, the generic priest's included (character_priest.lua is deliberately
-- relic-free). Xin carries utility_reliquary_kept_trust instead, which grants this same trait plus
-- her own giving loop -- so this is the plain version of the presence, and hers is the built-out one.
--
-- No `class`/`price`: no vendor stocks or buys it. Forged at the Blacksmith, its ward against magic
-- climbing with the level.
local Curve = require("models.curve")

return {
    name = "Hallowed Chalice",
    description = "Heals you and adjacent allies each tick.",
    flavor = "The ground a priest stands on is consecrated by the standing. It never leaves your hand.",
    sprite = "assets/items/sig_hallowed_chalice.png",
    type = "utility", -- `bound` (not the type) is what locks it in place
    class = "creature",
    tags = { "signature" },
    bound = true,
    traits = { "trait_sanctified_presence" },
    bonus = { magicDefense = Curve.ramp(2, 12) }, -- levels 0..10
}
