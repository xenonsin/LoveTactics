-- THE CHAPTER HOUSE: the middle rung of the succubus line, and the fight where the congregation starts
-- paying her back.
--
-- A chapter house is the room a religious house MEETS in, and that is both the joke and the fight. What
-- is sitting in it is a succubus, a lesser one behind her, and two of the Cathedral's own -- a knight
-- and a priest, both blooded, both wearing a Charm badge, both entirely convinced they are where they
-- ought to be (data/traits/trait_the_blooded.lua).
--
-- WHAT THIS RUNG ADDS IS THE CLOCK. The Long Gallery's succubus holds a body and does nothing further
-- with it; this one DRINKS (data/traits/trait_borrowed_blood.lua) -- every blow her congregation lands
-- on the company heals her. So the answer the Gallery taught, cut the charmer and the room empties,
-- stops being optional: a party that grinds through the thralls first is feeding her the whole time it
-- does it, and arrives at her with her bar fuller than it started.
--
-- WHICH IS THE LESSON THE LADY CHAPEL CHARGES FOR. Down there the same congregation is also what makes
-- her unhittable (trait_the_congregation), and a company that has already learned to go through the
-- room AT HER rather than at her people walks into that with the right instinct.
--
-- TWO CHARMERS, WHICH IS THIS LINE'S CEILING. One takes a party member on a good roll; two make it
-- likely. More than that and the fight stops being answerable by play and starts being answerable by
-- luck, which is the failure the Matriarch's cry was re-cut to avoid one stratum over.
--
-- See encounter_lust_the_long_gallery for why there are human bodies on a floor the 2026-09-22 sweep
-- cleared of them, and what the distinction is.
--
-- Locked to the castle stratum by ctx.biome. NO DEPTH GATE: ITS CIRCLE IS ITS PLACEMENT.
local Band = require("models.band")

return {
    name = "The Chapter House",
    kind = "combat",
    weight = 4,
    condition = function(ctx) return ctx.biome == "castle" end,
    composition = function(ctx)
        local list = { "character_succubus", "character_lesser_succubus" }
        Band.fill(list, ctx, "character_knight", { base = 1, per = 7, max = 2 })
        return Band.fill(list, ctx, "character_priest", { base = 1, per = 7, max = 2 })
    end,
}
