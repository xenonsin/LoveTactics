-- Wild Shape (Wolf): the hunter puts on a wolf's body. Always succeeds -- there is no roll and no
-- resist, because there is no victim: you are not doing this TO anyone, and a spell aimed at your own
-- skin has nobody to argue with it.
--
-- The trade is the hunter's whole identity, inverted. A hunter is a bow: reach, line of sight, and the
-- careful business of not being reached back. A wolf is none of that -- movement 5, fangs at range 1,
-- and a counter-bite for anyone who closes. You give up the thing you are good at to become the thing
-- you were keeping at a distance, for as long as you can hold the mana to stay it.
--
-- UPKEEP. `reserve` is why this file wears the shape itself rather than leaving it to the status (the
-- way Polymorph does): a self-transform is sustained exactly like a summon -- the reserved mana is
-- spent AND its ceiling locked away for as long as the shape is worn -- and only the cast knows what
-- its own ability declared. fx.transform binds it for a self-cast; the status
-- (data/status/wild_shape_wolf.lua) counts the shape down and the revert releases the lien.
--
-- Priced at the SAME 25% as data/items/ability/ability_summon_wolf.lua, and with no cost beside it, for
-- the same reason that one has none: wearing a wolf and having a wolf are the same commitment made from
-- different ends, so they are the same price. A reservation is already both a price and a lock (the mana
-- is spent AND its ceiling drops), and charging a cost on top would bill the hunter twice for one wolf.
-- It also has to be affordable out of a hunter's pool, which is the smallest mana bar that matters here.
--
-- The status is applied only if the shape actually took: fx.transform refuses a unit already wearing
-- one (one shape at a time), and a timer for a shape that never happened would revert someone else's.
--
-- COUNTERPLAY, and it is not the one a hunter expects: the shape is an ILLUSION (see the status), so a
-- Dispel Illusions sweeping the tile tears it off and the reserved mana comes back with it. Cure does
-- nothing -- this isn't a debuff, you did it to yourself. So the risk of wearing a shape isn't that it
-- wears off; it is that a priest on the other side ends it early, on their turn, at range, after
-- you have already paid for it.
return {
    name = "Wild Shape: Wolf",
    description = "Take a wolf's body -- fast and sharp-toothed. Reserves mana while worn.",
    sprite = "assets/items/ability_wild_shape_wolf.png",
    type = "ability",
    tags = { "primal", "illusion", "utility" },
    class = "hunter",
    price = 300,
    repRank = 2,
    activeAbility = {
        target = "self",
        range = 0,
        speed = 5,
        -- No cost: the reservation IS the price (see the upkeep note above), exactly as it is for the
        -- wolf you summon rather than wear.
        reserve = { stat = "mana", percent = 0.25 }, -- held for as long as the shape is worn
        effect = function(fx)
            if fx.transform(fx.user, "wolf_grunt") then
                fx.applyStatus(fx.user, "wild_shape_wolf")
            end
        end,
    },
}
