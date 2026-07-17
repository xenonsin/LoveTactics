-- Renewal: the priest lays a mending grace on a single ally, granting Regeneration
-- (data/status/regen.lua) -- flat health recovered at the start of each of that unit's turns for a
-- while. The over-time counterpart to Heal: where Heal restores a lump of HP now, Renewal drips it
-- back across the coming rounds, so it wants to land BEFORE the wounds come, on a frontliner about to
-- take the brunt. A close-range support cast (range 2), cheaper than a burst heal because its value
-- arrives on a timer rather than all at once.
return {
    name = "Renewal",
    description = "Grants an ally Regeneration, mending them at the start of each of their turns.",
    flavor = "It wants to land before the wounds come, which is the hardest thing the Cathedral teaches.",
    sprite = "assets/items/ability_renewal.png",
    type = "ability",
    tags = { "holy", "restorative" },
    class = "priest",
    price = 180,
    repRank = 2,
    activeAbility = {
        target = "ally", -- includes the caster (a unit is its own ally)
        range = 2,
        speed = 4,
        support = true,
        cost = { stat = "mana", amount = 10 },
        effect = function(fx)
            fx.applyStatus(fx.target, "status_regen")
        end,
    },
}
