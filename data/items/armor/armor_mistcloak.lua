local Curve = require("models.curve")

-- THE MISTCLOAK: the Vampire Duelist's drop (Wrath's vampires, round 1, Keno's note: "don't pick, be auto"). The
-- first blow you take each fight does no damage: you turn to mist and re-form on the free tile 2 away that is
-- farthest from whoever struck (trait_mistcloak, Trait.tryMist). Every armour costs a square of pace
-- (tests/armor_spec.lua), and this one does.
return {
    name = "Mistcloak",
    description = "The first blow each fight does no damage: you turn to mist and re-form 2 tiles away from the attacker.",
    flavor = "A grey cloak that is always slightly damp, and slightly cold, and slightly not there.",
    sprite = "assets/items/armor_mistcloak.png",
    type = "armor",
    tags = { "cloak" },
    class = "duelist",
    unlockLevel = 7,
    unstocked = true,
    traits = { "trait_mistcloak" },
    bonus = { defense = Curve.ramp(1, 11), movement = -1 },
}
