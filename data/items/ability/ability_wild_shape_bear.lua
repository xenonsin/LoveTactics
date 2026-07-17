-- Wild Shape (Bear): the hunter puts on a bear's body. Always succeeds, for the same reason its wolf
-- twin does -- a spell aimed at your own skin has nobody to argue with it. See
-- ability_wild_shape_wolf.lua for the shared machinery (the reservation is bound by fx.transform on a
-- self-cast; the status owns the countdown and the revert).
--
-- Where the wolf trades the bow for REACH, the bear trades it for WEIGHT: the best raw defense of any
-- body in the game, damage that reads as a greatsword, and a movement of 2 that means wherever it
-- plants itself is where the fight now is. A hunter who needs to be a knight for one exchange buys it
-- here, and pays for it in the two things a hunter values most -- position and tempo (the claws are
-- speed 7; the bear acts rarely and decisively).
--
-- Priced above the wolf in reservation and in the shorter window its status grants, because it is the
-- stronger body by a distance. Like the wolf it charges no cost beside the reservation -- a reservation
-- is already both a price and a lock, and billing twice for one shape would put the bear out of reach of
-- the pool it exists to be cast from (a hunter's mana bar is the smallest that matters here).
--
-- The two shapes are not a ladder -- neither is the upgrade of the other -- they are a question the
-- fight asks: do you need to be everywhere, or unmoved?
return {
    name = "Wild Shape: Bear",
    description = "Take a bear's body: armored and heavy-handed. Reserves mana while worn.",
    flavor = "Do you need to be everywhere, or unmoved? The bear is the second answer.",
    sprite = "assets/items/ability_wild_shape_bear.png",
    type = "ability",
    tags = { "primal", "illusion", "utility" },
    class = "hunter",
    price = 420,
    repRank = 3,
    activeAbility = {
        target = "self",
        range = 0,
        speed = 6,
        -- No cost: the reservation IS the price (see above). Deeper than the wolf's 25% -- the heavier
        -- body is the bigger commitment -- but the same kind of price, so the two read as one choice.
        reserve = { stat = "mana", percent = 0.40 }, -- held for as long as the shape is worn
        effect = function(fx)
            if fx.transform(fx.user, "character_dire_bear") then
                fx.applyStatus(fx.user, "status_wild_shape_bear")
            end
        end,
    },
}
