-- THE HOLLOW CROWN: the relic the last fight pays, first on the Crown's list (Descent.DROPS.crown; "The Crown's
-- Bestiary", slice D, approved over rounds 3-4). A warlord's trophy: unstocked, so it hangs on the rack greyed as a
-- monster drop and is never sold, and the body at the bottom of the rift is the only road to it.
--
-- WHAT IT IS, in the approved words: +3 damage for each different status on you, good or bad. The Crown was hollow
-- because seven people carried its wants away; worn, it fills with whatever the fight hangs on its wearer, a Haste
-- and a Burn alike. Read live (trait_wanting), so a Cure that strips a bad status also takes a share of the edge --
-- which is the decision it hands the warlord.
--
-- IT USED TO BE THE BODY'S OWN ORGAN under this id, the centre cell of the Crown's grid. The organ is
-- utility_the_first_archon now; this id is the company's.
local Curve = require("models.curve")

return {
    name = "The Hollow Crown",
    description = "+3 damage for each different status on you, good or bad.",
    flavor = "Wanting is what fills it.",
    sprite = "assets/items/armor_hollow_crown.png",
    type = "armor",
    tags = { "helm", "relic" },
    class = "warlord",
    unlockLevel = 15, -- the bottom floor, which is the only place it falls from
    unstocked = true,
    noSteal = true, -- a relic stays with whoever earned it off the body
    traits = { "trait_wanting" },
    bonus = { defense = Curve.ramp(2, 12), movement = -1 },
}
