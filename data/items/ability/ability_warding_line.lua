-- Warding Line: the hunter half of the Warden (knight x hunter). Drives a snare stake into a tile
-- (data/traps/snare_stake.lua) -- whatever crosses it is Rooted. The knight's question ("where do we
-- stand") answered from the far edge of the field with a trapper's tools: a border a charger cannot
-- pass without stopping. Requires an adjacent bow in the grid.
return {
    name = "Warding Line",
    description = "Drives a snare stake into a tile: the foe that crosses it is Rooted. Needs an adjacent bow.",
    flavor = "The March does not build a wall. It teaches the ground to hold.",
    sprite = "assets/items/ability_warding_line.png",
    type = "ability",
    tags = { "utility" },
    class = "hunter",
    discipline = "warden", -- knight x hunter; the Lockdown-zone mechanic's first stock
    price = 240,
    repRank = 2,
    activeAbility = {
        target = "tile",
        range = 4,
        requiresSight = true,
        speed = 4,
        cost = { stat = "stamina", amount = 7 },
        requiresAdjacent = { type = "weapon", tag = "bow" },
        effect = function(fx)
            fx.placeTrap(fx.tx, fx.ty, "snare_stake", { amount = 10 + 2 * fx.level })
        end,
    },
}
