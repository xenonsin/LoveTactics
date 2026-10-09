-- MANA-CUT BLADE: the Lesser Archon's blade, and the Duke's (data/characters/character_lesser_archon.lua; "The Crown's
-- Bestiary", slice A, 2026-10-09). MANA EDGE, the Lesser Archon's rule: the blade is cut from its own mana, so its
-- blows land on Magic Defense, not Defense.
--
-- NO CODE FOR THAT, ON PURPOSE. A `magical` blade already scales on Magic Damage and lands on Magic Defense
-- (Combat.mitigatedDamage), and a Magical Barrier already eats it -- so the review's counter ("wear a magic ward, or
-- put your spell-hardened bodies in front") is the engine as it stands, and a company's plate is decoration.
--
-- An Archon is not a demon: no fire rides it (data/races/archon.lua). The piece a company carries out is the Mana
-- Edge, a Battlemage's (data/items/utility/utility_mana_edge.lua); this blade is the body's own and is never loot.
local Curve = require("models.curve")

return {
    name = "Mana-Cut Blade",
    description = "Strikes an adjacent foe. Lands on Magic Defense.",
    flavor = "There is no steel in it. There never was; the court simply decided there would be an edge.",
    sprite = "assets/items/weapon_mana_cut_blade.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "slash", "magical", "melee" },
    noSteal = true, -- a creature's body is not loot
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 6 },
        damage = Curve.ramp(7, 17),
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
