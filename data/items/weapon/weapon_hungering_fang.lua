-- THE HUNGERING FANG: the Fledgling's drop (Wrath's vampires, 2026-09-26). A DAGGER (docs/weapons.md: quick, and
-- it opens a wound), and a hungry one: +3 Damage for each turn you end without drawing blood, up to three, and the
-- next hit spends all of it (trait_hungering_fang, status_hungering). A blade that rewards waiting for the opening.
local Curve = require("models.curve")

return {
    name = "Hungering Fang",
    description = "Inflicts Bleed. +3 damage per turn you end without drawing blood, up to 3. The next hit consumes it.",
    flavor = "A long yellowed canine set in a bone grip, and the grip is warm when it has not been used.",
    sprite = "assets/items/weapon_hungering_fang.png",
    type = "weapon",
    tags = { "dagger", "pierce", "physical", "melee" },
    class = "rogue",
    unlockLevel = 7,
    unstocked = true,
    traits = { "trait_hungering_fang" },
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 2,
        cost = { stat = "stamina", amount = 5 },
        damage = Curve.ramp(10, 20),
        effect = function(fx)
            fx.damage(fx.target, { inflicts = "status_bleed" })
        end,
    },
}
