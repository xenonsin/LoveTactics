-- Water Ball: a surging sphere of water that slams into a foe and drives it three tiles straight back
-- (a stopped shove hurts both it and whatever it hits -- see Combat.knockback), then bursts, soaking
-- the ground it struck. A Rain hazard (Wet) is left across a 3x3 where the blow landed, so anyone who
-- steps through is left vulnerable to lightning -- set up a Thunder Storm. Being water-tagged, it also
-- douses fire on the tile it hits. Positional utility, not raw damage.
return {
    name = "Water Ball",
    description = "Slams a foe three tiles back and soaks the area, inflicting Wet.",
    flavor = "Positional utility, not raw damage -- a sentence no fighter has ever finished reading.",
    sprite = "assets/items/ability_water_ball.png",
    type = "ability",
    tags = { "water", "magical" },
    class = "mage",
    price = 260,
    repRank = 2,
    activeAbility = {
        target = "enemy",
        range = 3,
        requiresSight = true,
        speed = 4,
        cost = { stat = "mana", amount = 12 },
        damage = { 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10 }, -- the impact damage a stopped shove deals; the soak is the real payoff
        effect = function(fx)
            local ox, oy = fx.target.x, fx.target.y -- the tile the blow lands on, before the shove
            fx.knockback(fx.target, 3, { amount = fx.amount })
            -- The splash soaks a 3x3 around where it struck; off-grid tiles are skipped by placeHazard.
            for dx = -1, 1 do
                for dy = -1, 1 do
                    fx.placeHazard(ox + dx, oy + dy, "hazard_rain")
                end
            end
        end,
    },
}
