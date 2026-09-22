-- THE UNDERTOW: the Mere's set-piece, and the fight the Gillscale Wrap comes out of.
--
-- `kind = "elite"`, so it opens at Arena.ELITE_CAP rather than the four-body skirmish ceiling. That is
-- not a size preference -- a composition this shape opened at four would be the elite and a screen of
-- two, which is not a screen, and the whole fight is about being unable to reach her while three other
-- bodies work the bank.
--
-- THE READING ORDER IS THE FACTION'S OWN SENTENCE: the Lancers soak, the Tidecaller conducts, and the
-- Undertow drags. Every one of those three verbs is answered by a different thing the player brings, so
-- a company that has met the Mere once arrives with an opinion.
--
-- The Tidecaller is named ONCE. Two of them would make a soaked front lethal before anybody had a turn
-- to dry off, which is the same argument encounter_gluttony_fen_mouth makes about its one maw.
local Band = require("models.band")

return {
    name = "The Undertow",
    kind = "elite",
    weight = 2,
    -- NO DEPTH GATE: ITS CIRCLE IS ITS PLACEMENT. The condition below locks this to one ground, and a
    -- circle owns a fixed stratum -- so a depth on top of that is a second opinion about where it goes,
    -- and it disagrees the moment the shuffle deals that circle at another depth (Descent.sinOrder).
    -- It also gated Lust's own elites off Lust's own floors: converted from the retired calendar they
    -- asked for floors three and four, and Lust owns one and two.
    --
    -- Which of a circle's floors a thing bills on is Descent.SINS' `elites` for the standing threat, and
    -- `rung` for anything an author wants split across the approach and the seat.
    condition = function(ctx) return ctx.biome == "swamp" end,
    composition = function(ctx)
        local list = { "character_undertow", "character_tidecaller", "character_fen_lancer" }
        return Band.fill(list, ctx, "character_fen_lancer", { base = 1, per = 6 })
    end,
}
