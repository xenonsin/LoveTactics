-- THE PENALTY HALF of The Standing Order (data/relics/relic_standing_order.lua): a body standing with
-- nobody beside it fights with less guard. The relic grants this alongside trait_formation_fighter, so
-- the pair reads as one rule with two faces -- armour in the rank, a hole out of it.
--
-- SPLIT INTO ITS OWN TRAIT rather than folded into the formation charm, for two reasons. The charm is
-- worn by items and characters that never agreed to a penalty (it is a plain positive on every one of
-- them), so teaching it a downside would re-author every bearer. And the two halves want tuning apart:
-- how much a rank is worth and how badly being caught alone should sting are different questions, and a
-- single trait answers them with one number.
--
-- `live` for the same reason its partner is (see trait_formation_fighter's header, which is where that
-- argument lives): this is a claim about the board as it stands right now, so it has to be re-read on
-- every stat read rather than banked at the opening bell. It returns a table and touches nothing --
-- damage previews and the inventory tooltip call flatStat on every hover frame.
--
-- Note the asymmetry with the charm: that one pays PER neighbour and this one is a flat penalty at zero
-- neighbours, not a per-missing-ally slope. Standing alone is a state, not a quantity -- a body with no
-- one beside it is not more alone for having three empty tiles instead of one.
return {
    name = "Standing Order",
    description = "Fights with less defense while no ally stands beside it.",
    live = function(ctx)
        if ctx.count(1, "ally") > 0 then return nil end
        return { defense = -3 }
    end,
}
