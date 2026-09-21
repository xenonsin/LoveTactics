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
return {
    name = "The Undertow",
    kind = "elite",
    weight = 2,
    minDay = 8,
    condition = function(ctx) return ctx.biome == "swamp" end,
    composition = function(ctx)
        local list = { "character_undertow", "character_tidecaller", "character_fen_lancer" }
        for _ = 1, 1 + math.floor((ctx.day or 1) / 15) do
            list[#list + 1] = "character_fen_lancer"
        end
        return list
    end,
}
