-- Arcanum rank-4. A passive tome: raw magical power, and a ward against magic in turn. No ability
-- of its own -- it does not need one, and it would like you to know that.
--
-- The Arcanum's catalogue lists eleven owners. It does not list how many finished reading it -- the
-- first hint of Pride, whose general answers every spell with your own.
local Curve = require("models.curve")

return {
    name = "Codex of Hubris",
    description = "Grants potent magic, and a ward against it.",
    flavor = "The Arcanum's catalogue lists eleven owners. It does not list how many finished reading it.",
    sprite = "assets/items/codex_of_hubris.png",
    type = "utility",
    tags = { "arcane" },
    class = "mage",
    price = 800,
    unlockQuests = 10,
    bonus = { magicDamage = Curve.ramp(10), magicDefense = Curve.ramp(5) },
    resist = { magical = Curve.ramp(4) },
}
