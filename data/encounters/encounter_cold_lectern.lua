-- Encounter blueprint. THE COLD LECTERN: a book somebody chained open down here and did not finish
-- copying, with enough left in it to teach ONE thing. Stepping onto it raises one ABILITY the company
-- is carrying by a single rung, free -- no gold, no technique, no craft stock (models/forge.lua's
-- Forge.grant). The Cold Forge's pair, and between them the road's only source of DEPTH.
--
-- IT IS THE CITY'S OWN LINE, HELD OUT HERE. The Bastion's forge works what a smith can hold in a pair
-- of tongs and the Arcanum's study works what is written down (models/forge.lua's Forge.WORK); the road
-- keeps one wayside stop per room rather than one stop that does both. A player who has learned where
-- a spell gets better in town should not have to learn a different answer underground -- and the coals
-- honing a spell would rebuild, where nobody can see it, exactly the muddle the split took apart.
--
-- ABILITIES ONLY, AND NOT THE RECIPES THE STUDY ALSO REFINES. A recipe climbs per TYPE -- refine it
-- once and every copy bought afterwards comes at that tier (Player.recipeLevel) -- so a free refining
-- is a permanent upgrade to a shelf, which is not a thing a stop on a floor gives away. What a page
-- teaches is the spell in the hand that is holding it.
--
-- The gift is bounded exactly as the coals are: Forge.grant waives the BILL and keeps the CEILING, so
-- a reading cannot take an ability past what the company has actually played for.
--
-- WEIGHT 1 AGAINST THE FORGE'S 2, because the halves of the kit are not the same size: the forge works
-- three item types and several hundred pieces, this one works ninety-odd abilities. Together the two
-- stops make the road a little richer in depth than the single Cold Forge did, which is the price of
-- the split and is paid on purpose -- each one is now half as likely to be the stop you wanted.
--
-- `minDay = 2` for the Cold Forge's reason: on floor one every ability is at +0 and the rungs all look
-- alike, and by floor two the company has a favourite.
return {
    name = "The Cold Lectern",
    kind = "lectern",
    weight = 1,
    minDay = 2,
}
