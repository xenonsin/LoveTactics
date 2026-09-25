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
    -- WHICH of the two is `rung` below, and on an elite it is REQUIRED rather than optional: one elite,
    -- one floor. A biome lock places a body in the stratum and then leaves it standing on both of that
    -- stratum's stairs, which makes a landmark into traffic -- see models/encounter.lua's eligibility
    -- note for the whole argument, and tests/elite_floor_spec.lua for the count that holds it.
    --
    -- Descent.SINS' `elites` is the SEPARATE question of which of a floor's candidates the floor is
    -- ABOUT (billed at ELITE_NAMED_WEIGHT). The rung says where a thing may stand at all.
    condition = function(ctx) return ctx.biome == "swamp" end,
    -- RUNG 2 -- the seat. It was Greed's billed seat until the swap (2026-09-25) took the fen and the naga
    -- to Lust, where it stands as a spare beside the Eyrie. Opens at Arena.ELITE_CAP rather than at a
    -- skirmish's size.
    rung = 2,
    -- ...AND A SIREN SINGS IN IT (approved on review). The drag and the song together: Longing makes
    -- every step away from the bank cost, and the Undertow pulls you onto it. The Tidecaller soaks, so the
    -- Siren's voice reaches the whole company.
    composition = function(ctx)
        local list = { "character_undertow", "character_tidecaller", "character_siren", "character_fen_lancer" }
        return Band.fill(list, ctx, "character_fen_lancer", { base = 1, per = 6 })
    end,
}
