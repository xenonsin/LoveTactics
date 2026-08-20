-- Lifted off the Suppliant, and it is how the Reliquary finally profits from what it takes.
--
-- THE PAIR. The Reliquary of the Unbidden drains the stamina and mana a foe held back on every cast and
-- then has no way to benefit from having emptied them. This hits an empty body harder -- once for either
-- pool, twice for both (data/traits/trait_beggars_due.lua) -- so a second swing at the same target lands
-- on somebody with nothing left to answer with.
--
-- IT WORKS ALONE. Any long fight empties a caster, and a body out of stamina is a body that has been
-- swinging; the bowl is paid in both cases. What the Reliquary adds is the ability to CAUSE the
-- condition rather than wait for it.
--
-- No `class` and no `price`: no vendor stocks it, no shelf can replace it. There is one.
local Curve = require("models.curve")

return {
    name = "Beggar's Bowl",
    description = "Increase damage by 4 if the target's stamina is 0. Increase damage by 4 if the target's mana is 0.",
    flavor = "Carried through the nave for a hundred years. It has never held anything.",
    sprite = "assets/items/beggars_bowl.png",
    type = "utility",
    tags = { "relic" },
    noSteal = true,
    traits = { "trait_beggars_due" },
    bonus = { magicDefense = Curve.ramp(2, 12) },
}
