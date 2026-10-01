-- IFRIT'S COAL: the Ifrit's drop. Reviewed 2026-09-30 ("Pride's Bestiary").
--
-- The half of the Ifrit's Flame a person can carry: every fire spell its bearer finishes sets the target's tile
-- alight (trait_ifrits_coal). On the elementalist's shelf because that is where the fire spells are, and a Fire
-- Bolt with a coal behind it is an Emberwand with a Burn on top.
return {
    name = "Ifrit's Coal",
    description = "Your fire spells set the target's tile alight.",
    flavor = "Still burning. It has been burning since before the spire had a floor to drop it on.",
    sprite = "assets/items/utility_ifrits_coal.png",
    type = "utility",
    tags = { "charm" },
    class = "elementalist",
    unlockLevel = 13,
    unstocked = true,
    traits = { "trait_ifrits_coal" },
}
