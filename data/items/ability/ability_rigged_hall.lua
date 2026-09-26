-- THE RIGGED HALL: the Goblin King's levers (picked over Temper in round 1, 2026-09-26, "The Goblins of Wrath").
--
-- He never leaves his throne. Each turn he pulls a lever: a row of the hall five wide is marked (the wind-up, one
-- turn, drawn for both sides), and next turn it opens into fire. Anyone still on it is DOWNED -- goblins too --
-- which is the Coin-Eaters' rule for a puzzle elite: fatal means downed in a zone you were shown, never a wipe.
-- The row runs across the line from him to the tile he picks, so the whole hall is reachable from the throne.
--
-- A body's own, never shelved: the drop is the King's Lever, which hurts rather than downs.
return {
    name = "The Rigged Hall",
    description = "Marks a row of five for a turn; then it opens into fire, and everyone on it is downed.",
    flavor = "Every flagstone in the hall has a lever. He has never told anyone which.",
    sprite = "assets/items/ability_rigged_hall.png",
    type = "ability",
    tags = { "trap", "fire" },
    class = "creature",
    noSteal = true,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 6,
        minRange = 1,
        speed = 4,
        windup = 5,
        cost = { stat = "stamina", amount = 5 },
        aoe = { shape = "front", width = 5 },
        ai = { priority = "urgent", act = "cast" },
        effect = function(fx)
            local user = fx.user
            for _, u in ipairs(fx.aoeUnits()) do
                if u ~= user and u.alive then
                    local hp = u.char and u.char.stats and u.char.stats.health
                    local cur = (hp and hp.current) or 0
                    if cur > 0 then fx.flatDamage(u, cur, { "fire" }) end
                end
            end
            for _, c in ipairs(fx.aoeCells() or {}) do
                fx.placeHazard(c.x, c.y, "hazard_fire", { side = false, duration = 8 })
            end
        end,
    },
}
