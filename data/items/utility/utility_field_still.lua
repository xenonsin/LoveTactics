-- Field Still: the Warbrewer's fifth (fighter x alchemist). At the top of each of your turns, it brews
-- something into your grid.
--
-- The item S4 and S2 were both built to serve, and the one that makes the Warbrewer self-sufficient: a
-- fighter who drinks for free (the Battle Tonic) still runs out of things to drink, and a shelf whose
-- whole pitch is "the Crucible is a fighter's shelf now" cannot end at three vials. The still is the
-- supply line.
--
-- What it makes is ephemeral (Combat.grantItem), so a Warbrewer cannot distil a stockpile over a long
-- fight and walk it home. It is a fight's worth of brewing, and it stops at the gate.
--
-- Silent on a full grid -- Combat.grantItem narrates the refusal itself -- which is also the item's real
-- constraint: nine cells, and a still that keeps producing means keeping a cell empty to catch it. That
-- is the cost, and it is paid in the same currency the whole grid is.
return {
    name = "Field Still",
    description = "Brews a draught into your grid at the start of each of your turns.",
    flavor = "It is strapped to his back and it is still warm. Neither fact has ever concerned him.",
    sprite = "assets/items/utility_field_still.png",
    type = "utility",
    tags = { "charm" },
    class = "warbrewer",
    unlockQuests = 3,
    dropTier = 3,
    traits = { "trait_field_still" },
    -- something brewing in the grid every turn
    bonus = { magicDefense = 1 },
}
