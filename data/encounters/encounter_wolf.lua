-- DIRE WOLF: grunts, and nothing else. That is the whole blueprint and it is load-bearing.
--
-- It used to hand itself an alpha at depth three, which made it encounter_wolf_pack.lua with a slower
-- start -- the same cast, the same kill order, a different pair of numbers. Two stops that field one
-- cast are one stop the player meets twice, and this pair was the clearest case of it in the game.
--
-- FOUR FILES ALREADY SAID SO. encounter_wolf_pack.lua's opening line is "encounter_wolf.lua fields
-- grunts and nothing else"; ability_howl_lesser.lua, utility_pack_presence.lua and
-- character_wolf_alpha.lua all price themselves on the alpha turning up in the pack stop and nowhere
-- else. The alpha was added here later and none of those sentences were revisited, so the fix is not a
-- retune -- it is the four claims becoming true again.
--
-- What is left is the honest shape of the pair: this is the teeth with no head, and the pack stop is
-- what the teeth are worth when something is leading them.
--
-- Uses models/band.lua for the count. See data/encounters/encounter_boar.lua for the shape.
local Band = require("models.band")

return {
    name = "Dire Wolf",
    kind = "combat",
    weight = 6, -- see encounter_boar.lua: the four road fights were doubled together
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
    rung = 1, -- home floor of the circle (models/encounter.lua)
    -- A pack that grows as the descent runs on, and never gains a head: that is the pack stop's.
    --
    -- ONE BODY PER TWO FLOORS WAS ALSO TOO STEEP TO READ. A skirmish seats four (Arena.SKIRMISH_CAP),
    -- so `2 + depth/2` was pinned at the ceiling from floor four down and the curve was arithmetic
    -- nobody could see. One per five floors puts the centre inside the tier at every depth, which is
    -- what leaves the band room to actually roll.
    composition = function(ctx)
        return Band.fill({}, ctx, "character_wolf_grunt", { base = 3, per = 5 })
    end,
}
