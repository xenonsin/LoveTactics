-- Briarfloor: the Dryad grows thorn ground in a diamond around a foe, and it bills every tile crossed.
--
-- What the ground does is the hazard's (data/hazards/hazard_briarfloor.lua): a foe that enters a thorn
-- tile takes a sting, whether it walked in or was thrown in, and a slide across three tiles of it is
-- billed three times. Grown around a body, so the one standing in the middle has to cross thorn to
-- leave -- and a harpy's gust does the crossing for it.
--
-- A natural weapon: no class, no price, noSteal (tests/bestiary_spec.lua).
return {
    name = "Briar Spread", -- not the spell's name (ability_briarfloor): see weapon_mistlight on why
    description = "Grows thorn ground around a foe: foes take damage for every tile of it they cross.",
    flavor = "The keep's floor was stone, once. It has been a long time since anyone swept it.",
    sprite = "assets/items/briarfloor.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "nature", "magical", "ranged" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 4,
        requiresSight = true,
        speed = 5,
        cost = { stat = "mana", amount = 10 },
        aoe = { shape = "diamond", radius = 1 },
        effect = function(fx)
            for _, c in ipairs(fx.aoeCells()) do
                fx.placeHazard(c.x, c.y, "hazard_briarfloor", { amount = 3 + fx.level })
            end
        end,
    },
}
