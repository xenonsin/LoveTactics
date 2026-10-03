-- THE ONE WHO HAS NOT ACTED: a Faceless squad with an Assassin standing in it, wearing a glass-thing's face until
-- it strikes. Never let it finish anyone, and watch for the body in the pack that has not moved yet.
-- Approved 2026-10-02 ("Envy's Bestiary", round 2).
--
-- One soldier and a second on some rolls: with three it measured 24 unit-turns on the skirmish harness's seed
-- (budget 22). As built it measures 14 there, and 23-25 on three other seeds.
local Band = require("models.band")

return {
    name = "The One Who Has Not Acted",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "desert" end,
    rung = 2,
    composition = function(ctx)
        return Band.fill({ "character_faceless_assassin", "character_faceless" }, ctx,
            "character_faceless", { base = 0, min = 0, per = 6, max = 1 })
    end,
}
