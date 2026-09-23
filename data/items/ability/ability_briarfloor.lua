-- Briarfloor: grow thorn ground in a diamond around a foe. A foe takes a sting for every tile of it it
-- crosses, walked or thrown (data/hazards/hazard_briarfloor.lua) -- so it is a tax on walking out, and a
-- multiplier on every shove the company already owns: a mace that drives a body two tiles across the
-- patch has billed it twice before the collision. Sided to the caster, so the company crosses its own
-- thorns freely. A fire cast clears it.
return {
    name = "Briarfloor",
    description = "Grows thorn ground around a foe: foes take damage for every tile of it they cross.",
    flavor = "The keep's floor was stone, once.",
    sprite = "assets/items/ability_briarfloor.png",
    type = "ability",
    tags = { "nature" },
    class = "druid",
    price = 390,
    unlockLevel = 7,
    activeAbility = {
        target = "enemy",
        range = 4,
        requiresSight = true,
        speed = 4,
        cost = { stat = "mana", amount = 10 },
        aoe = { shape = "diamond", radius = 1 },
        effect = function(fx)
            for _, c in ipairs(fx.aoeCells()) do
                fx.placeHazard(c.x, c.y, "hazard_briarfloor", { amount = 3 + fx.level })
            end
        end,
    },
}
