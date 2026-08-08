-- Trackless Boots: the ground stops charging their wearer. Forest, sand, snow, mud, rubble -- every
-- rough tile costs 1 to enter, exactly as open field does.
--
-- THE FIRST ITEM IN THE CATALOG THAT TOUCHES `moveCost`. That is worth saying plainly, because the
-- boot family is already eight strong and none of the others do it: Cinderstride and Tidewalker lay a
-- trail BEHIND the wearer, the Pilgrim's Sandals hallow it, Feather Boots refuse to spring a trap, and
-- the Sidelong Greaves walk through bodies. Every one of them changes what the ground does TO you, or
-- what you do to it. None change what it COSTS. Meanwhile models/arena.lua has priced forest at 2 and
-- mountain at 3 since the first arena, and for the whole life of the project nothing could be bought
-- that cared. Terrain was a fact about maps rather than a thing a player could get good at.
--
-- HOW IT WORKS: a `terrainEase` of 1 -- the most the ground may charge this body (Combat.terrainEase,
-- read by the one place a tile is priced, stepTerrainCost). A CAP, never a discount, so it can never
-- make a tile cheaper than open field: the wearer walks over broken country at the pace everyone else
-- walks over a lawn, and no faster.
--
-- WHAT IT DOES NOT EASE is the ground an enemy is watching (Combat.watchTax, added AFTER the cap).
-- Good boots answer bad footing; they do not answer a spear pointed at you. A wearer wading past a
-- sentry pays the tax in full, which keeps the two mechanics from cancelling each other out and keeps
-- this from quietly becoming the counter to the knight's whole shelf.
--
-- WHY THE DRUID'S. Hunter's shelf is setup-and-payoff, and its Druid branch is the one that belongs to
-- the country rather than merely hunting across it. A charm that makes the woods stop mattering is the
-- shape of that: the Trapper wants the enemy slowed, the Beastmaster wants a body between, and the
-- Druid simply is not inconvenienced. It is also, bluntly, what makes a forest map playable from the
-- side that chose to go into the forest.
--
-- Priced beside Feather Boots (220) rather than the 440-600 trail boots: it eases footing, it does not
-- paint hazards, and on an open arena it does nothing at all. Named for what it does not leave, where
-- the trail boots are named for what they do.
return {
    name = "Trackless Boots",
    description = "Rough ground. Forest, sand, snow, rubble. Costs you no more than open field.",
    flavor = "Two days behind her and the dogs were still casting about the treeline, insulted.",
    sprite = "assets/items/trackless_boots.png",
    type = "utility",
    tags = { "boots" },
    class = "hunter",
    discipline = "druid", -- deeper cut of the shelf: buyable only once the druid gate is cleared
    price = 320,
    unlockQuests = 4,
    -- The cap, flat rather than a Curve: 1 is open field and there is nowhere below it to climb to.
    -- A magnitude that cannot move is authored as a plain number (docs/classes.md on the forge span).
    terrainEase = 1,
}
