-- Bastion Plate: the knight's Rampart keeper (docs/engines.md). The bearer's barrier pool no longer wears
-- off (trait_bastion): what the knight raises, it keeps until a blow spends it. Barricade, in a game
-- whose barrier used to time out four turns after it was laid.
--
-- `class = "knight"` with NO `price`: unbuyable, and still tallying toward knight growth
-- (docs/classes.md, "class without price").
--
-- Reworked from The Closed Entry (2026-11-18), a plain defense charm. The id stays for saves.
local Curve = require("models.curve")

return {
    name = "Bastion Plate",
    description = "Your barrier no longer wears off.",
    flavor = "The Bastion hangs one over every gate it holds, and has never taken one down.",
    sprite = "assets/items/closed_entry.png",
    type = "utility",
    tags = { "charm" },
    class = "knight",
    unlockLevel = 2,
    traits = { "trait_bastion" },
    bonus = { defense = Curve.ramp(1, 11) },
}
