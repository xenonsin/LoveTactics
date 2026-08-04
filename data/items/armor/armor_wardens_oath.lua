-- The item form of the Knight's Oathward: a warden's plate that binds its wearer to the same vow --
-- soak the first blow each turn on an adjacent ally. Any character who wears it becomes a guardian.
-- A knight-class chestpiece, sold at the Bastion; solid steel, so it is a shield in both senses.
local Curve = require("models.curve")

return {
    name = "Warden's Oath",
    description = "The first hit each turn on an adjacent ally is taken by you instead.",
    flavor = "The Bastion will sell the vow to anyone. Keeping it is not included in the price.",
    sprite = "assets/items/wardens_oath.png",
    type = "armor",
    tags = { "plate" },
    class = "knight",
    discipline = "sentinel", -- the Intercept mechanic itself -- soak the blow aimed at the ally beside you
    price = 280,
    unlockQuests = 4,
    traits = { "trait_oathward" },
    bonus = { defense = Curve.ramp(6, 16), movement = -1 },
    resist = { physical = 2 },
}
