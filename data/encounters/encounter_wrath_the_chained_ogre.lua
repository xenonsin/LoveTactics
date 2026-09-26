-- THE CHAINED OGRE: on Wrath's seat (approved as pitched, 2026-09-26, "The Orcs of Wrath"). The Handler points and
-- the ogre follows; kill the Handler and the ogre is Unchained, striking whoever is nearest. It is a 2x2 body, so
-- WHERE it comes off the chain matters as much as when. The fight the review flagged as likeliest to outgrow an
-- ordinary stop; if the road harness says so it moves to elite, as the Redcaps did.
local Band = require("models.band")

return {
    name = "The Chained Ogre",
    kind = "combat",
    weight = 2,
    condition = function(ctx) return ctx.biome == "volcanic" end,
    rung = 2,
    composition = function(ctx)
        return Band.fill({ "character_orc_beast_handler", "character_war_ogre" }, ctx,
            "character_orc_grunt", { base = 1, min = 1, per = 6, max = 2 })
    end,
}
