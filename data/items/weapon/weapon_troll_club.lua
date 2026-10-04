-- TROLL CLUB: a troll's weapon (data/characters/character_troll.lua). Approved 2026-10-04 ("Sloth's Bestiary",
-- slice B): "a heavy club that hits hard and slow."
--
-- A hammer by family -- ponderous, two hands -- and a creature's own kit, so it gives up the family's stun: the
-- troll's threat is the regrowth behind the swing, not the swing. Never loot; what a troll drops is its blood.
local Curve = require("models.curve")

return {
    name = "Troll Club",
    description = "Strikes an adjacent foe.",
    flavor = "Most of a tree, and none of the parts anybody would have kept.",
    sprite = "assets/items/weapon_troll_club.png",
    type = "weapon",
    tags = { "hammer", "impact", "physical", "melee" },
    hands = 2,
    class = "creature",
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 7, -- slow: the review's word, and the hammer's
        cost = { stat = "stamina", amount = 10 },
        damage = Curve.ramp(14, 24),
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
