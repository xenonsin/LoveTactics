-- THE HERD: what a stag looks like when it is not alone. Same body, brought in the numbers it lives
-- in -- and now the ONLY stop in the game that fields Ancient Stags.
--
-- IT USED TO STAND BESIDE encounter_stag, a lone animal of the same body, and the pair was one cast at
-- two counts: not two fights, one fight met twice under two names. That file's own header recorded why
-- it was the half to go -- a single stag against a company of four rated 582% against
-- Muster.WALK_OVER of 200, so every marker it drew went calm and the stop offered to resolve itself
-- instead of opening a board. A fight nobody plays is not texture, it is a tile that says "not today".
--
-- THIS IS THE HALF THE RULES WERE BUILT FOR. trait_herd_warmth pays a stag a little health every tick
-- it has an ally beside it and nothing at all alone, so it is worth exactly nothing on a lone stop and
-- is the whole shape of this one: break them apart, or put one down before the rest close. Deleting
-- the other half costs the wood a walk-off and costs this rule nothing.
local Band = require("models.band")

return {
    name = "The Herd",
    kind = "combat",
    weight = 3,
    -- NO DEPTH GATE: ITS CIRCLE IS ITS PLACEMENT. The condition below locks this to one ground, and a
    -- circle owns a fixed stratum -- so a depth on top of that is a second opinion about where it goes,
    -- and it disagrees the moment the shuffle deals that circle at another depth (Descent.sinOrder).
    -- It also gated Lust's own elites off Lust's own floors: converted from the retired calendar they
    -- asked for floors three and four, and Lust owns one and two.
    --
    -- Which of a circle's floors a thing bills on is Descent.SINS' `elites` for the standing threat, and
    -- `rung` for anything an author wants split across the approach and the seat.
    -- LOCKED TO THE WOOD, which is the circle-lock rule arriving rather than a retune: humans
    -- float to every floor and everything else belongs to exactly one circle. This was shared
    -- road stock on all fifteen, and the beast band is Gluttony's identity now.
    condition = function(ctx) return ctx.biome == "forest" end,
    -- Three or four, rolled off the fight's own seed, so a herd met twice is not the same herd twice
    -- (models/band.lua). Three is the floor because three is what the other two files say -- a herd of
    -- two is the stop that was deleted, wearing this one's name.
    composition = function(ctx)
        return Band.fill({}, ctx, "character_stag_beast", { base = 3, min = 3, max = 4, per = 6 })
    end,
}
