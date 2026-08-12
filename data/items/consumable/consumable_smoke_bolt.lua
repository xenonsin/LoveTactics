-- THE ONE ITEM THAT ENDS A RUN ON THE PLAYER'S TERMS.
--
-- The board's standing rule is that the objective is the only extract: clear it and the expedition's
-- finds become permanent, and every other way off the map -- a wipe, a walk-out -- rolls the company
-- back to what it marched in with (docs/overworld.md, states/game.lua's rollbackRun). That rule earns
-- its keep. Without it, forfeiting a run the moment it had paid out was the optimal way to bank a
-- haul, and every risk the board offered was decorative.
--
-- But it also collapsed two very different exits into one event. A party that walks out at four stops
-- with a good haul and a bad feeling is making the oldest decision in the genre -- knowing when to
-- stop -- and the game answered it with the same zero a wipe pays. So the decision did not exist.
--
-- A charge is what lets it exist without giving the exploit back. Leaving early with everything is
-- available, and it costs a thing the player had to buy in the city, carry through the run in a grid
-- cell that could have held something else, and NOT spend on the last three occasions they wanted to.
-- That is a price paid before the moment of weakness rather than at it, which is the only kind of
-- price a "cut your losses" button can honestly carry.
--
-- WHY THE UNDERCROFT. Greed's house, and the rogue's whole discipline is the exit: taking a thing is
-- the easy half, and leaving with it is the half you train for. No other house would sell this without
-- an argument -- the Bastion in particular would call it desertion, which is the Bastion's business
-- and precisely why it is not on that shelf.
--
-- WHY AN OBJECT AND NOT A BUTTON. The object decides the mechanic's form. A bolt of smoke fired off
-- breaks contact for the whole company at once, which is what the mechanic needs (the party leaves,
-- not a member), and it is spent in the firing, which is what makes it a charge rather than a
-- standing permission. It is aimed at nothing, so it carries no activeAbility at all.
--
-- `extract = true` is the whole contract, read by Player.extractCharge / Player.spendExtract. It is
-- the SPENT half of the overworld-item category, whose other member is utility_torch's passive
-- `visionRadius`; see the Overworld items block in models/player.lua.
return {
    name = "Smoke Bolt",
    description = "On the overworld, breaks off a run and walks out with everything found.",
    flavor = "The Undercroft teaches the going-in for one night and the coming-out for a year.",
    sprite = "assets/items/smoke_bolt.png",
    type = "consumable",
    class = "rogue",
    extract = true, -- overworld: spend to leave a run without voiding its haul
    stackable = true,
    -- MID-LINE, AND THE PRICE FOLLOWS FROM THAT. Both numbers are the grade chain's (slot -> price,
    -- docs/shelf.md), not hand-picked: 175g is exactly Grade.priceFor(6, "consumable"), and the pin in
    -- Grade.SLOT_PINS is what holds the slot where the design put it.
    --
    -- An opening-shelf version was written first, on the argument that the rule this answers binds
    -- hardest on a player who has not learned yet how much a board can take off them. The grade chain
    -- refused it and was right to. At slot 0 the derived price is thirty gold, and a thirty-gold way out
    -- is one a player carries three of permanently -- which makes walking out free again, which is the
    -- exploit the whole extraction rule exists to close. The charge only works while it is scarce at the
    -- moment you want it.
    --
    -- Reading it as pacing rather than as a price rescues the argument anyway: a newcomer has no haul
    -- worth saving -- two caches and a chest -- while a company six quests into a house is carrying
    -- forged gear, house stock and a run's technique. The mercy arrives when the stake does.
    unlockQuests = 6,
    price = 175,
}
