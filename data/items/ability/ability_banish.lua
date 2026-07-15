-- Banish: the priest speaks a word of unmaking over a 3x3 area, and every SUMMONED creature caught in
-- it is undone at once -- a wolf, an elemental, a raised zombie, a doppelganger, an enemy banner. It
-- does nothing to real flesh: a knight or a boar in the blast is untouched, so this is not a damage
-- spell but an answer to a board flooded with conjurations. The unmaking is a dismissal, not a kill
-- (fx.dismiss) -- no corpse to raise, and none of the death reactions a real killing blow would trip.
--
-- The blast sweeps allies too, so mind your OWN summons: banish a tile your wolf stands on and the wolf
-- goes with the enemy's. A ground-target support cast, aimed at a cell in range.
return {
    name = "Banish",
    description = "Unmake every summoned creature in a 3x3 area -- wolves, elementals, the raised dead.",
    sprite = "assets/items/ability_banish.png",
    type = "ability",
    tags = { "holy" },
    class = "priest",
    price = 300,
    repRank = 3,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 4,
        requiresSight = true,
        speed = 5,
        cost = { stat = "mana", amount = 14 },
        aoe = { radius = 1, shape = "square" }, -- 3x3 area of unmaking
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                fx.dismiss(u) -- only `summoned` units are undone; real combatants are left be
            end
        end,
    },
}
