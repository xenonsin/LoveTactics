-- THE GALLERY: armour that keeps standing more of itself up.
--
-- Every threshold it is cut past adds a Gilded Sworn, which in a circle where power IS adjacency means
-- the formation is being repaired while you dismantle it. Killing the Gallery is the only way to stop
-- the hall refilling.
local Band = require("models.band")

return {
    name = "The Gallery",
    kind = "elite",
    weight = 2,
    -- NO DEPTH GATE: ITS CIRCLE IS ITS PLACEMENT. The condition below locks this to one ground, and a
    -- circle owns a fixed stratum -- so a depth on top of that is a second opinion about where it goes,
    -- and it disagrees the moment the shuffle deals that circle at another depth (Descent.sinOrder).
    -- It also gated Lust's own elites off Lust's own floors: converted from the retired calendar they
    -- asked for floors three and four, and Lust owns one and two.
    --
    -- WHICH of the two is `rung` below, and on an elite it is REQUIRED rather than optional: one elite,
    -- one floor. A biome lock places a body in the stratum and then leaves it standing on both of that
    -- stratum's stairs, which makes a landmark into traffic -- see models/encounter.lua's eligibility
    -- note for the whole argument, and tests/elite_floor_spec.lua for the count that holds it.
    --
    -- Descent.SINS' `elites` is the SEPARATE question of which of a floor's candidates the floor is
    -- ABOUT (billed at ELITE_NAMED_WEIGHT). The rung says where a thing may stand at all.
    condition = function(ctx) return ctx.biome == "spire" end,
    -- RUNG 1 -- the approach, which is where Pride bills it -- AND IT IS THE SPIRE'S ONLY ELITE, so
    -- Pride's seat floor now stands none at all. It used to stand THIS one a second time (the `rung
    -- == 2 and named.seat or named.approach` fallback), which is exactly what the rule forbids: a
    -- bare floor is the honest reading of a circle with one elite, and a doubled billing was not.
    rung = 1,
    composition = function(ctx)
        local list = { "character_the_gallery", "character_standard_bearer" }
        return Band.fill(list, ctx, "character_gilded_page", { base = 2, per = 6 })
    end,
}
