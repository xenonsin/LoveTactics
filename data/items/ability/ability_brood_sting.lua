-- BROOD STING: the Brood Queen's egg, laid in a foe instead of a heap (status_brood_sting). In two turns
-- it hatches: the host takes the sting's damage, and two Gilded Scarabs crawl out on your side. Cure takes
-- the egg out before it hatches. Reviewed 2026-09-25 ("The Coin-Eaters"): a drop has to work on every
-- floor, so the heap became a body.
--
-- Beastmaster stock beside the Brood Sac -- the shelf that keeps animals. Rift-only: a trophy off the
-- Queen.
return {
    name = "Brood Sting",
    description = "Lays an egg in an adjacent foe; in 2 turns it hatches, dealing 10 damage and adding two "
        .. "scarabs to your side.",
    flavor = "It is not a poison. It is a nursery, and the host is the wall.",
    sprite = "assets/items/ability_brood_sting.png",
    type = "ability",
    tags = { "pierce", "physical" },
    class = "beastmaster",
    unlockLevel = 6,
    unstocked = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cooldown = 25,
        cost = { stat = "stamina", amount = 10 },
        notOn = { "status_brood_sting" },
        effect = function(fx)
            if fx.target then fx.applyStatus(fx.target, "status_brood_sting", { magnitude = 10 }) end
        end,
    },
}
