-- WHICH DOTH MOCK THE MEAT IT FEEDS ON: the Green-Eyed Monster's rule, on its organ
-- (data/items/utility/utility_mocks_the_meat.lua). Reviewed 2026-10-01..03 ("Envy's Bestiary", round 2).
--
-- It hates closeness: every blow it throws deals +2 for each pair of the struck body's side standing side by side
-- (orthogonally adjacent, each pair once -- models/envy_oneoffs.lua's pairsOf). Read on the blow, so the hover and
-- the wound agree. Its roar is the other half (ability_green_eyed_roar).
return {
    name = "Which Doth Mock the Meat",
    description = "Deals +2 damage for every pair of foes standing side by side.",
    perPair = 2,
    damageBonusVs = function(ctx)
        if not (ctx.combat and ctx.target) then return 0 end
        local pairs = require("models.envy_oneoffs").pairsOf(ctx.combat, ctx.target.side)
        return #pairs * ctx.param("perPair", 2)
    end,
}
