-- Thunder Storm: a barrage of lightning over a 3x3 area. Everyone within -- friend and foe, so mind
-- your line -- takes lightning damage (reaping the bonus on any Wet target, so rain it first) and is
-- Stunned (data/status/stun.lua), shoved down the turn order. The lightning counterpart to Blizzard;
-- a ground-target area cast.
return {
    name = "Thunder Storm",
    description = "A barrage of lightning over an area: damages and Stuns everyone within.",
    sprite = "assets/items/ability_thunder_storm.png",
    type = "ability",
    tags = { "lightning", "magical" },
    class = "mage",
    price = 400,
    repRank = 3,
    activeAbility = {
        name = "Thunder Storm",
        target = "tile",
        allowOccupied = true,
        range = 3,
        speed = 5,
        cost = { stat = "mana", amount = 16 },
        damage = { 6, 7, 7, 8, 8, 9, 10, 10, 11, 11, 12 },
        aoe = { radius = 1, shape = "square" },
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                fx.damage(u)
                fx.applyStatus(u, "stun", { magnitude = fx.amount })
            end
        end,
    },
}
