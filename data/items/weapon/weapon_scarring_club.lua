-- SCARRING CLUB: the Troll Scarlord's drop, on the fighter's shelf. Approved 2026-10-04 ("Sloth's Bestiary",
-- slice B): "A foe you strike cannot heal or regrow until your next turn."
--
-- A hammer, so ponderous and two-handed; like the Frostfall Hammer it trades the family's stun for something else,
-- here the Unclosing Wound, laid on the hit and lifted at the wielder's next turn (trait_scarring_blows). Against a
-- troll it is the fire's answer without the fire; against a priest's company it is a turn in which nobody is saved.
--
-- `unstocked`: the body's own piece, visible on its house's rack and never sold (docs/drops.md).
local Curve = require("models.curve")

return {
    name = "Scarring Club",
    description = "Inflicts Unclosing Wound until your next turn.",
    flavor = "The troll it came from never found out what it was for. It only ever hit things that stayed down.",
    sprite = "assets/items/weapon_scarring_club.png",
    type = "weapon",
    tags = { "hammer", "impact", "physical", "melee" },
    hands = 2,
    class = "fighter",
    unlockLevel = 9,
    unstocked = true,
    traits = { "trait_scarring_blows" },
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 7,
        cost = { stat = "stamina", amount = 12 },
        damage = Curve.ramp(20, 32),
        effect = function(fx)
            fx.damage(fx.target, { inflicts = { id = "status_unclosing_wound", duration = 30 } })
        end,
    },
}
