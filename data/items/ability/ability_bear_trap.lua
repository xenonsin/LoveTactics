-- Bear Trap: the hunter sets steel jaws on a nearby tile (data/traps/bear_trap.lua). The first enemy
-- across it is bitten and Rooted where it stands. Uses the tile-target ability kind (target = "tile"):
-- Combat.useItem allows any in-range cell and hands the clicked coordinates to the effect as
-- fx.tx / fx.ty, which fx.placeTrap turns into an owned trap.
--
-- The Lodge's version of data/items/ability/ability_spike_trap.lua, and the difference is what the
-- shelves are for. The Undercroft sets a spike trap to hurt whoever finds it; the Lodge sets this one
-- to STOP them, because a hunter's whole trade is setup and then payoff (docs/classes.md) and a foe
-- that cannot walk is a foe every bow on the field now has a free shot at. It deals less than the
-- rogue's trap does and costs more, which is the root being paid for.
--
-- Priced in stamina rather than mana, as the hunter's shelf mostly is -- and unlike the spike trap,
-- which the rogue buys with the mana it otherwise barely spends.
return {
    name = "Bear Trap",
    description = "Sets jaws on a nearby tile: they wound and Root the first enemy to cross it.",
    flavor = "The Lodge teaches that the difficult part of a hunt is never the killing.",
    sprite = "assets/items/ability_bear_trap.png",
    type = "ability",
    tags = { "trap", "utility" },
    class = "hunter",
    price = 360,
    repRank = 3,
    activeAbility = {
        target = "tile",
        range = 3,
        speed = 4,
        cost = { stat = "stamina", amount = 10 },
        effect = function(fx)
            -- The forged trap bites harder: base 12 damage, +1 per upgrade level. The root does not
            -- scale -- held is held, and an upgrade that lengthened it would be buying tempo twice.
            fx.placeTrap(fx.tx, fx.ty, "bear_trap", { amount = 12 + fx.level })
        end,
    },
}
