local Curve = require("models.curve")

-- IRON MAIDEN: the Blood Countess's second drop (Wrath's vampires, round 3: "Iron Maiden too"). Plate with its
-- spikes turned outward: any foe that hits you in melee Bleeds, and the wound is yours (trait_iron_maiden). Heavy,
-- so it pays the heavy tier's two squares of pace (tests/armor_spec.lua).
return {
    name = "Iron Maiden",
    description = "Melee attackers Bleed.",
    flavor = "It was built to be closed on somebody. Worn open, it closes on whoever comes close.",
    sprite = "assets/items/armor_iron_maiden.png",
    type = "armor",
    tags = { "heavy" },
    class = "knight",
    unlockLevel = 8,
    unstocked = true,
    traits = { "trait_iron_maiden" },
    bonus = { defense = Curve.ramp(5, 15), movement = -2 },
}
