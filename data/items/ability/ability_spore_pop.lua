-- Pop: a Puffer that reaches the company goes off on purpose.
--
-- ability_self_destruct's shape, spore for fire: a channelled cast (the wind-up is the tell, and a step,
-- a shove or a stun answers it) that throws a ring of poison and Swoon over the tiles around it and
-- spends the Puffer through fx.expendSelf -- a dismissal, so the death-burst beside it (trait_spore_burst)
-- does not fire twice. The tactics ride on the ability, as the Bomblet's do: it walks at the nearest body
-- and pulls the pin the moment the ring can reach one.
--
-- BOTH SIDES, like every burst. A Puffer that pops in the middle of the mushroom folk swoons the Verger.
return {
    name = "Pop",
    description = "Channeled: bursts, dealing poison and Swoon to everything beside it.",
    flavor = "It has been holding its breath since it came up out of the floor.",
    sprite = "assets/items/spore_pop.png",
    type = "ability",
    class = "creature",
    tags = { "poison", "explosive" },
    bound = true, -- what the thing IS; never lifted off it
    activeAbility = {
        target = "self",
        support = false,
        range = 0,
        windup = 2, -- the tell: the window a step, a shove or a stun has to answer it
        speed = 4,
        damage = 6,
        aoe = { shape = "diamond", radius = 1 },
        ai = {
            { priority = "high", act = "cast", when = { subject = "any_foe", test = "exists" } },
        },
        effect = function(fx)
            fx.burst(fx.user.x, fx.user.y, { "poison" })
            for _, u in ipairs(fx.aoeUnits()) do
                if u ~= fx.user then
                    fx.damage(u, { tags = { "poison", "magical" } })
                    if u.alive then fx.applyStatus(u, "status_swoon") end
                end
            end
            fx.expendSelf(string.format("%s bursts.", fx.user.char.name or "The puffer"))
        end,
    },
}
