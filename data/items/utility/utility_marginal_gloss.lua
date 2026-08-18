-- Lifted off Marginalia, and it is what pays the Codex's bill.
--
-- THE PAIR, and the one in the set that gets STRONGER the worse the matchup is. The Codex Unanswered
-- deflects a single-target spell aimed at you for MANA, on a cooldown -- and its real limit was never
-- the cooldown, it was the bill: against a caster party you run dry and stop being able to refuse
-- anything. This returns mana every time a spell is worked nearby (data/traits/trait_glossed.lua), so
-- the more they throw the more you can afford to unravel. The gloss is funded by the thing it funds.
--
-- IT WORKS ALONE, and better than it looks: mana never regenerates on its own in this game, so a trickle
-- back on every enemy working is the difference between a caster who runs dry on turn four and one who
-- does not.
--
-- A GLOSS IS A NOTE IN A MARGIN -- somebody else's answer, written beside the thing it answers. Named
-- for the object rather than the mechanic, which is how this whole tier is named.
--
-- No `class` and no `price`: no vendor stocks it, no shelf can replace it. There is one.
local Curve = require("models.curve")

return {
    name = "Marginal Gloss",
    description = "Any spell worked near you returns mana.",
    flavor = "One line, in a hand that is not the author's, beside a passage the author got wrong.",
    sprite = "assets/items/marginal_gloss.png",
    type = "utility",
    tags = { "relic" },
    noSteal = true,
    traits = { "trait_glossed" },
    bonus = { magicDefense = Curve.ramp(2, 12) },
}
