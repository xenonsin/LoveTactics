-- Lifted off the Tally, and it makes robbing a body worth doing for its own sake.
--
-- THE PAIR. The Bottomless Purse lifts an item off an adjacent foe into your hands -- it costs you an
-- action and pays you a piece of gear you may not even want. The stick notches every one of those
-- (data/traits/trait_assayers_tally.lua), so the theft itself is the reward and the Purse stops being a
-- utility you use when convenient and starts being the engine you build around. Which is the sin.
--
-- IT WORKS ALONE, and it works from the first fight of a fresh save: the baseline is your COMPANY'S
-- purse, read live, so what you are hoarding is what you swing with. Spend the money and the damage goes
-- back down, which is the honest half of greed and the reason it is capped.
--
-- No `class` and no `price`: no vendor stocks it, no shelf can replace it. There is one.
local Curve = require("models.curve")

return {
    name = "The Tally Stick",
    description = "Heavier for the coin your company holds, and for everything you have taken this fight.",
    flavor = "Notched on both edges, end to end. The Tally kept the accounts of everyone who came down " ..
        "here, and all of them were behind.",
    sprite = "assets/items/tally_stick.png",
    type = "utility",
    tags = { "relic" },
    noSteal = true,
    traits = { "trait_assayers_tally" },
    bonus = { defense = Curve.ramp(1, 11) },
}
