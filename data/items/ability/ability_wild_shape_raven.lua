-- Wild Shape (Raven): the hunter puts on a bird's body. Always succeeds -- there is no roll and no
-- resist, because there is no victim: a spell aimed at your own skin has nobody to argue with it.
--
-- THE FORM THAT DOES NOT MAKE THE TRADE. Wild Shape's other two shapes are both a bargain in the same
-- direction: a hunter is a bow -- reach, line of sight, the careful business of not being reached back
-- -- and the Wolf and the Bear each ask you to give that up and become the thing you were keeping at a
-- distance. This one asks the opposite. Flung Quills throws at three tiles (keeping a bow's dead zone
-- underneath it), the Fan of Feathers rakes a cone through anything that closes anyway, and the body
-- moves 6. You stay a shooter; you simply become a much more fragile one that can be anywhere.
--
-- That is why it is the LATER shape on the shelf (rank 3 against the wolf's 2). A form that keeps your
-- whole game plan intact and adds wings to it is a straight upgrade to a hunter's positioning, so it is
-- gated behind having already learned the two shapes that cost you something.
--
-- UPKEEP works exactly as the wolf's does: `reserve` is why this file wears the shape itself rather
-- than leaving it to the status -- a self-transform is sustained like a summon, the reserved mana is
-- spent AND its ceiling locked away for as long as the shape is worn, and only the cast knows what its
-- own ability declared. fx.transform binds it; the status counts the shape down and the revert releases
-- the lien. No cost beside the reservation, for the same reason the wolf has none: a reservation is
-- already both a price and a lock, and charging on top would bill the hunter twice for one bird.
--
-- COUNTERPLAY is the same and still the one a hunter does not expect: the shape is an ILLUSION, so a
-- Dispel Illusions tears it off at range, on somebody else's turn, after you have already paid for it.
-- Cure does nothing -- you did this to yourself.
return {
    name = "Wild Shape: Raven",
    description = "Turns you into a raven, gaining Raven Shape. Reserves mana while worn.",
    flavor = "The other shapes ask what you are willing to give up. This one asks how far you can see.",
    sprite = "assets/items/ability_wild_shape_raven.png",
    type = "ability",
    tags = { "primal", "illusion", "utility" },
    class = "hunter",
    discipline = "druid", -- deeper cut of the shelf: buyable only once the druid gate is cleared
    price = 340,
    unlockQuests = 6,
    activeAbility = {
        target = "self",
        range = 0,
        speed = 5,
        -- No cost: the reservation IS the price, exactly as it is for the shapes beside it.
        reserve = { stat = "mana", percent = 0.25 }, -- held for as long as the shape is worn
        effect = function(fx)
            if fx.transform(fx.user, "character_wild_raven") then
                fx.applyStatus(fx.user, "status_wild_shape_raven")
            end
        end,
    },
}
