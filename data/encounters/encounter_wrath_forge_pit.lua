-- THE FORGE PIT: the Forge-Wretch, and the fight that teaches Kindling.
--
-- The wretch sharpens with every blow it takes, up to a ceiling. The kin beside it are there to make
-- chipping tempting -- there is always something else worth hitting -- which is exactly the mistake the
-- wretch is priced against. Commit and it dies before it matters; spread your damage and you build it.
--
-- Two wretches on purpose at depth: the lesson lands harder when the second one is already sharp.
local Band = require("models.band")

return {
    name = "The Forge Pit",
    kind = "combat",
    weight = 4,
    -- NO DEPTH GATE: ITS CIRCLE IS ITS PLACEMENT. The condition below locks this to one ground, and a
    -- circle owns a fixed stratum -- so a depth on top of that is a second opinion about where it goes,
    -- and it disagrees the moment the shuffle deals that circle at another depth (Descent.sinOrder).
    -- It also gated Lust's own elites off Lust's own floors: converted from the retired calendar they
    -- asked for floors three and four, and Lust owns one and two.
    --
    -- Which of a circle's floors a thing bills on is Descent.SINS' `elites` for the standing threat, and
    -- `rung` for anything an author wants split across the approach and the seat.
    condition = function(ctx) return ctx.biome == "volcanic" end,
    composition = function(ctx)
        local list = { "character_forge_wretch", "character_cinder_kin" }
        return Band.fill(list, ctx, "character_forge_wretch", { base = 1, per = 6 })
    end,
}
