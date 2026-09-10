-- Encounter blueprint. THE COLD FORGE: a bench somebody left burning down here, with coals enough for
-- ONE piece. Stepping onto it raises one item the company is CARRYING by a single rung, free -- no gold,
-- no technique, no craft stock (models/forge.lua's Forge.grant). The road's only source of DEPTH.
--
-- WHY THE ROAD IS ALLOWED TO GIVE THIS AT ALL. The city's division of labour is that gold buys breadth
-- and technique buys depth, and the descent already leans hard on the first half: gear comes off the
-- floors (models/gate.lua), the Merchant sells it, the Reliquary and the Altar deal relics. Every one of
-- those stops hands the company something NEW. Nothing out here makes what you already carry better, so
-- a run's answer to a weapon it likes was always "carry it home and come back in a week".
--
-- The gift is bounded by the same standing the bench is: Forge.grant waives the BILL and keeps the
-- CEILING, so the coals cannot take a knight's blade past what the company has actually played for. What
-- a run wins here is a rung EARLIER, never a rung it had no right to.
--
-- ONE PIECE, and the choice is the price -- the Reliquary's shape (encounter_relic_cache.lua) applied to
-- gear instead of relics. A stop that improved everything would be a floor-wide stat bump wearing a
-- panel; a stop that improves one thing is a question about which part of the loadout the rest of this
-- descent is going to be fought around.
--
-- CARRIED, not owned: the stash is out of reach (Forge.equipped). What the forge can touch is what
-- somebody walked in wearing, so the boon is aimed at a kit the player has already committed to rather
-- than at the pile back home.
--
-- `minDay = 2` for the Weeping Stone's reason (models/descent.lua's guaranteeKinds): on floor one every
-- piece is at +0 and the rungs all look alike, and by floor two the company has a favourite. Weighted
-- like the Reliquary -- an uncommon find, cut further on a descent floor by Descent.TEXTURE_SCALE, so a
-- run meets one or two of these and never counts on it.
return {
    name = "The Cold Forge",
    kind = "anvil",
    weight = 2,
    minDay = 2,
}
