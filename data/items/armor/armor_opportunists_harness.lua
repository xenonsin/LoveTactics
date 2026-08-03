-- Quest-only: `class` with no `price` (docs/classes.md).
--
-- Afflict a foe with any debuff and the harness pays you a Haste (trait_opportunist), then recharges.
-- The one armor whose value is decided entirely by what ELSE is in the grid: beside a bleeding dagger
-- or a poisoned kris it fires most turns, and on a character carrying nothing but a sword it never
-- fires at all.
--
-- That conditionality is the point and the reason it sits on greed's shelf rather than being a flat
-- speed bonus somebody could just wear. Haste halves ability and movement costs (status_hasted), so
-- what the harness actually converts is the rogue's own setup into a second action -- debuff, then
-- spend the turn you were not going to have.
--
-- utility_opportunists_charm is the charm form. Same rule, different slot; the harness is for a build
-- that has already spent its nine cells.
local Curve = require("models.curve")

return {
    name = "Opportunist's Harness",
    description = "On inflicting a debuff: gain Haste, then recharge.",
    flavor = "Undercroft tailoring: the buckles are placed for someone who intends to be elsewhere shortly.",
    sprite = "assets/items/armor_opportunists_harness.png",
    type = "armor",
    tags = { "leather" },
    class = "rogue",
    traits = { "trait_opportunist" },
    bonus = { defense = Curve.ramp(3, 7) },
}
