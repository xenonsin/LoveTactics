-- SPLITTING IMAGE: the Many Faced One's split, made small enough to carry (Descent.DROPS, behind its relic). A
-- second of you stands up beside you for two turns, on YOUR health pool (Summon's `sharePool`) -- one bar, two
-- bodies, two turns' worth of actions -- and wears Split, so if the pool empties under either of you, both fall.
--
-- On the Ninja's shelf beside Mirror Image, which is the opposite trade: that double is fragile and does nothing;
-- this one fights, and costs you every blow it takes. Unpriced and `unstocked`: the body is the only road to it.
return {
    name = "Splitting Image",
    description = "Split into two of you for 2 turns, sharing one health pool. Both act.",
    flavor = "It did this with a whole company. One of you is a modest beginning.",
    sprite = "assets/items/ability_splitting_image.png",
    type = "ability",
    tags = { "illusion", "utility" },
    class = "ninja",
    unlockLevel = 12,
    unstocked = true,
    activeAbility = {
        target = "tile",
        range = 1,
        speed = 4,
        cost = { stat = "mana", amount = 12 },
        effect = function(fx)
            local double = fx.copy(fx.tx, fx.ty, { duration = 10, sharePool = true })
            if not (double and double.alive) then return end
            fx.applyStatus(double, "status_split")
        end,
    },
}
