-- THE MEDITATION HALL (Wrath, floor 8, elite): a Three-Faced Asura and two Acolytes on a board laid with shrine stones
-- (hazard_shrine). An asura standing on a shrine does not cool -- its chi never drains -- so the fight is about
-- pulling or pushing them off it. The reference is Nioh's Yokai Realm, ground that stops your ki from
-- recovering. Approved on review 2026-09-27/28.
--
-- Approved as "an Adept and two Acolytes", which is the Sparring Ground's cast (one cast, one stop, counted by
-- the kinds of body). The Three-Faced takes the Adept's place, and it is the better body for the room: it
-- Gathers, its Gather heats it (Tapas), and on a shrine nothing cools it again.
--
-- `scatter` is the fight's own ground (Arena.build's bodyGround), the same seam Avaritia's treasury uses.
local Band = require("models.band")

return {
    name = "The Meditation Hall",
    kind = "elite",
    weight = 1,
    condition = function(ctx) return ctx.biome == "volcanic" end,
    rung = 2,
    scatter = { { id = "hazard_shrine", count = 5 } },
    composition = function(ctx)
        return Band.fill({ "character_asura_three_faced", "character_asura_acolyte", "character_asura_acolyte" }, ctx,
            "character_asura_acolyte", { base = 0, min = 0, per = 6, max = 1 })
    end,
}
