-- THE CONFESSIONAL: the Long Gallery's rule with a healer as the charmed body.
--
-- A lesser succubus and one of the Cathedral's priests, blooded and wearing her Charm
-- (utility_the_blooded). Kill her and he walks off the board; leave her standing and the company spends
-- the fight watching him mend her. The lightest ordinary fight on the floor, and a short one: two bodies,
-- one of them cut to end it. MOVE: the succubus trades tiles.
--
-- The congregation is one priest or two; a priest is not plate, so the Long Gallery's cap of two holds.
--
-- Approved on review 2026-09-25 (variety round 1, `l3_confessional`).
local Band = require("models.band")

return {
    name = "The Confessional",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "swamp" end,
    rung = 1, -- home floor of the circle (models/encounter.lua)
    composition = function(ctx)
        local list = { "character_lesser_succubus" }
        return Band.fill(list, ctx, "character_priest", { base = 1, per = 8, max = 2 })
    end,
}
