-- Pure displacement: no damage of its own, but it drives whatever stands on an adjacent tile three
-- tiles straight back. The payoff is positional -- shove a foe off a vantage point, into a fire hazard,
-- over a spike trap, or hard against a wall (a stopped shove deals impact damage to BOTH sides -- the
-- Power, scaled up by however much of the three tiles it never got to travel, so a foe with its back to
-- a wall takes double). See Combat.knockback.
--
-- It aims a TILE, not a foe, so the grip is the same one Heave uses (data/items/ability/ability_heave.lua):
-- whatever is standing there is what gets shoved -- a body (friend OR foe), a prop (a powder keg rolls
-- off into the enemy line and bursts on impact), or a trap you have found (walk the demons' own spikes
-- back down their approach). Bodies route through Combat.knockback, furniture through Combat.hurlObject;
-- either way it is the same journey, told in each layer's currency.
return {
    name = "Push",
    description = "Knockback 3 on an adjacent body, barrel or trap; a collision hurts both sides.",
    flavor = "No damage of its own. The wall, the fire and the spikes do all of the talking.",
    sprite = "assets/items/ability_push.png",
    type = "ability",
    tags = { "impact", "physical" },
    class = "knight",
    discipline = "bulwark", -- deeper cut of the shelf: buyable only once the bulwark gate is cleared
    price = 200,
    repRank = 2,
    activeAbility = {
        target = "tile",       -- an adjacent tile, so what is shoved may be friend, foe or furniture
        allowOccupied = true,
        range = 1,
        minRange = 1,          -- an adjacent neighbour, never the shover's own tile
        speed = 3,
        cost = { stat = "stamina", amount = 5 },
        damage = { 6, 7, 7, 8, 8, 9, 10, 10, 11, 11, 12 }, -- the collision's bite (only a blocked shove lands it)
        effect = function(fx)
            -- Whatever stands on the aimed tile: a body first (a unit and an object never share a tile,
            -- so the order is a preference in name only), otherwise the furniture on it -- a prop, or a
            -- trap this side has detected. Exactly Heave's dispatch.
            local body = fx.unitAt(fx.tx, fx.ty)
            if body then
                fx.knockback(body, 3, { amount = fx.amount })
                return
            end
            local obj, kind = fx.objectAt(fx.tx, fx.ty)
            if obj then fx.hurl(obj, kind, 3, { amount = fx.amount }) end
        end,
    },
}
