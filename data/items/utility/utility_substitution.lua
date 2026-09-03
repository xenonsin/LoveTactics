-- Substitution: the rogue half of the Ninja's Shadowclone (rogue x mage). A blow that would land on you
-- kills a standing clone instead, and you take its tile.
--
-- The item that makes a clone worth casting twice. Mirror Image plants a double and hides you; until
-- now the double's whole job was to be a wrong guess for the enemy AI, and a fight where nobody swung
-- at it was a fight where the mana was wasted. Here the clone is a second life you positioned on
-- purpose, and where you put it decides where you end up when it is spent.
--
-- It reads any live `decoy` summon of the bearer (Summon.copy's decoyOf), so Mirror Image and
-- Scatterlight both feed it and any future clone will too. No cooldown and no charge: the clone was the
-- charge, and the mage half had to pay for it.
--
-- The teleport is not a bonus, it is part of the cost. You are moved somewhere you did not pick this
-- turn -- possibly into the middle of the line, possibly onto a trap -- which is what keeps a free
-- negated blow from being strictly better than a dodge.
return {
    name = "Substitution",
    description = "Redirects a blow that would hit you onto a clone, swapping you to its tile.",
    flavor = "Two of them fell. Only one of them had ever been there.",
    sprite = "assets/items/utility_substitution.png",
    type = "utility",
    tags = { "charm", "illusion" },
    class = "ninja",
    price = 575,
    unlockQuests = 6,
    traits = { "trait_substitution" },
    -- the blow lands on a clone, which from outside looks like luck
    bonus = { luck = 2 },
}
