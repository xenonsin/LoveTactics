-- THE EMBER LINE: the Wrath circle's ordinary traffic, and the stratum's rule at the cheapest rung.
--
-- Every body here leaves fire on the tile it dies on, so the fight rearranges the board as you win it.
-- Clear the swarm and you have won the exchange and lost the room -- which is what makes the deeper
-- stops of this circle work, because the Unquenched drinks that fire and the Anvil is paid for the
-- trades you take when you can no longer kite.
--
-- Locked to the volcanic stratum by ctx.biome, the same gate every circle uses.
local Band = require("models.band")

return {
    name = "The Ember Line",
    kind = "combat",
    weight = 5,
    -- NO DEPTH GATE: ITS CIRCLE IS ITS PLACEMENT. The condition below locks this to one ground, and a
    -- circle owns a fixed stratum -- so a depth on top of that is a second opinion about where it goes,
    -- and it disagrees the moment the shuffle deals that circle at another depth (Descent.sinOrder).
    -- It also gated Lust's own elites off Lust's own floors: converted from the retired calendar they
    -- asked for floors three and four, and Lust owns one and two.
    --
    -- Which of a circle's floors a thing bills on is Descent.SINS' `elites` for the standing threat, and
    -- `rung` for anything an author wants split across the approach and the seat.
    condition = function(ctx) return ctx.biome == "volcanic" end,
    rung = 1, -- home floor of the circle (models/encounter.lua)
    composition = function(ctx)
        local list = { "character_cinder_kin" }
        return Band.fill(list, ctx, "character_ember_spit", { base = 3, per = 5 })
    end,
}
