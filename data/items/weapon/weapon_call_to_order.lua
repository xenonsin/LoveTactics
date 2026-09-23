-- Call to Order: the Verger bangs its staff on the floor and every foe within two tiles has to deal with
-- it first.
--
-- A Taunt on each of them (status_taunt: the body is taken out of its owner's hands and driven at the
-- taunter, and the taunt ends when the taunter falls). Which is the whole of what the Verger is for: a
-- company made to hit it is a company hitting Spongeflesh (trait_spongeflesh), and every one of those
-- swings comes back as a swoon. The counterplay is the circle's standing law -- cut the one doing it --
-- and magic or reach, because the flesh only answers a melee hand.
--
-- A natural weapon: no class, no price, noSteal (tests/bestiary_spec.lua).
return {
    name = "Call to Order",
    description = "Taunts every foe within 2 tiles.",
    flavor = "The staff comes down on the flags and the whole nave turns to look. That is its only trick. It is enough.",
    sprite = "assets/items/call_to_order.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "command" },
    noSteal = true,
    activeAbility = {
        target = "self",
        support = false, -- aimed at its own feet, and a blow at the company's will (items_spec)
        range = 0,
        speed = 4,
        cost = { stat = "stamina", amount = 8 },
        aoe = { shape = "diamond", radius = 2 },
        ai = {
            { priority = "high", act = "cast", when = { subject = "any_foe", test = "within", value = 2 } },
        },
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                if u ~= fx.user and u.side ~= fx.user.side then fx.applyStatus(u, "status_taunt") end
            end
        end,
    },
}
