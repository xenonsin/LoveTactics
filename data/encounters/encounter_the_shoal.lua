-- THE SHOAL: the Mere's ordinary traffic, and the fight that teaches the fen.
--
-- A screen of Shoalkin with a Fen Lancer working the bank behind them. It is a skirmish rather than a
-- set-piece, so it opens at the plain four-body ceiling -- which is the right size for the lesson: the
-- company learns that the walls of this arena are water, that the things in them do not pay to cross
-- it, and that a spear can reach the second rank from ground nobody can follow it onto.
--
-- Gated on the SWAMP because that is where the channels are (Arena.BIOME_TERRAIN's blocker), and on a
-- board with no water on it the Mere is simply a slow pack with a spear.
return {
    name = "The Shoal",
    kind = "combat",
    weight = 3,
    minDay = 2,
    condition = function(ctx) return ctx.biome == "swamp" end,
    -- THICKENS EARLY AND FLATTENS, which is the shape both measurements asked for. A shoal of two
    -- behind one lancer is a fight a levelled company walks over (tests/descent_spec.lua rates it on
    -- floor three); a shoal that kept growing is a fight that stops ending (tests/skirmish_spec.lua
    -- caps an ordinary road stop at 22 unit-turns). One more body early, none later.
    composition = function(ctx)
        local list = { "character_fen_lancer" }
        for _ = 1, 2 + math.min(1, math.floor((ctx.day or 1) / 6)) do
            list[#list + 1] = "character_shoalkin"
        end
        return list
    end,
}
