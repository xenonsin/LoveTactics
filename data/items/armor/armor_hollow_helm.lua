local Curve = require("models.curve")

-- THE HOLLOW HELM: the Dwarf Skeleton's. A dead dwarf walks past the gold that damned it -- the want died
-- with it -- and the helm is that absence generalised: nothing can make its wearer want anything. No
-- Charm, no Taunt, no Cowering. Approved 2026-09-25 ("The Dead Hand", round 3). Every armour costs a
-- square of pace (tests/armor_spec.lua), and this one does.
return {
    name = "Hollow Helm",
    description = "You cannot be Charmed, Taunted or made to Cower.",
    flavor = "There is nothing behind the eyes for a voice to reach. That was the dwarf's problem. Now it is yours.",
    sprite = "assets/items/armor_hollow_helm.png",
    type = "armor",
    tags = { "helm" },
    class = "bulwark",
    unlockLevel = 5,
    unstocked = true,
    statusImmunity = { "status_charm", "status_taunt", "status_cowering" },
    bonus = { defense = Curve.ramp(2, 12), movement = -1 },
}
