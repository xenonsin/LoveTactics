-- Dispel Illusions: sweep a 3x3 area clean of deceit. Every invisible unit standing in it is
-- revealed (stripping the Invisible that hides a Decoy's caster), and every `illusion`-tagged wall
-- there is torn down at a stroke. A tile-target cast whose AoE footprint (the 3x3 around the aimed
-- cell) is exactly the area fx.dispel clears by default.
--
-- Support-flagged so it reads as a friendly utility rather than an attack, even though it may land
-- on enemy ground: it deals no damage, it only lifts illusions.
return {
    name = "Dispel Illusions",
    description = "Reveals every hidden unit and shatters every illusion in the area.",
    flavor = "The Cathedral sweeps for deceit weekly, and weekly it finds some.",
    sprite = "assets/items/ability_dispel_illusions.png",
    type = "ability",
    tags = { "holy" },
    class = "priest",
    price = 240,
    repRank = 3,
    activeAbility = {
        target = "tile",
        range = 4,
        speed = 4,
        cost = { stat = "mana", amount = 14 },
        support = true,
        allowOccupied = true, -- the sweep may be centred on a tile a unit stands on
        aoe = { radius = 1, shape = "square" }, -- the 3x3 fx.dispel clears
        effect = function(fx)
            fx.dispel() -- defaults to the ability's own AoE footprint
        end,
    },
}
