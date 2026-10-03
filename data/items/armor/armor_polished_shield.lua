-- POLISHED SHIELD: the Mirror-Knight's drop, on the sentinel's shelf. Reviewed 2026-10-01..03 ("Envy's Bestiary").
--
-- The knight's mirror without the knight: whoever strikes you in melee sees themselves, and is Rattled for it
-- (trait_polished_shield). Rattled is the existing status -- aim worse, act later -- so a front line carrying one
-- slows down whatever it is holding back. A shield, so a Shield Bash beside it can bash with it.
local Curve = require("models.curve")

return {
    name = "Polished Shield",
    description = "A foe that strikes you in melee is Rattled.",
    flavor = "Polished until it stopped being a shield and started being a question.",
    sprite = "assets/items/armor_polished_shield.png",
    type = "armor",
    tags = { "shield" },
    class = "sentinel",
    unlockLevel = 12,
    unstocked = true,
    traits = { "trait_polished_shield" },
    bonus = { defense = Curve.ramp(3, 13), movement = -1 },
    waitBehavior = { kind = "defend", speed = 3, defense = Curve.ramp(6, 16) }, -- a shield, like every shield
}
