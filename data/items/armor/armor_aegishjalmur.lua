-- Aegishjalmur, the Helm of Terror: Fafnir's own, off the Gilt Wyrm (data/characters/character_gilt_wyrm.lua),
-- reviewed 2026-09-25. It lends the wearer the wyrm's Dread (data/traits/trait_helm_of_terror.lua): foes
-- within 2 move 2 fewer squares, so a front-liner wearing it is a place the enemy does not want to stand.
--
-- Armour, and armour costs a square of pace (tests/armor_spec.lua) -- the helm's weight is the one thing
-- about it that is not frightening.
local Curve = require("models.curve")

return {
    name = "Aegishjalmur",
    description = "Foes within 2 of you move 2 fewer spaces.",
    flavor = "The helm of terror, that all living creatures fear. The wearer included, the first time.",
    sprite = "assets/items/armor_aegishjalmur.png",
    type = "armor",
    class = "warlord",
    unlockLevel = 9,
    unstocked = true,
    traits = { "trait_helm_of_terror" },
    bonus = { defense = Curve.ramp(3, 13), movement = -1 },
}
