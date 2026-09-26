local Band = require("models.band")

-- THE SWARM: Gilded Scarabs and a Rust Mite. The gold moves, and your blades blunt on the thing behind it.
-- The Coin-Eaters' own ordinary fight on Greed's approach (reviewed 2026-09-25, "The Coin-Eaters").
return {
    name = "The Swarm",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "cave" end,
    rung = 1,
    composition = function(ctx)
        return Band.fill({ "character_rust_mite" }, ctx, "character_gilded_scarab",
            { base = 3, min = 3, per = 6, max = 4 })
    end,
}
