-- DRAG BELOW: the Chain Fiend's hooked chain (data/characters/character_chain_fiend.lua; "The Crown's Bestiary",
-- slice B, approved 2026-10-09). Reach 3: the struck body is pulled in beside the fiend and Rooted there for 1 turn
-- (models/crown_demons.lua's dragBelow). The pull is Combat.pull's, so it stops on a body in the line -- keep a wall
-- or an ally between you and it, and Cure the Root.
--
-- A demon's blow burns: a physical chain with fire on it (tests/bestiary_spec.lua's demon rule).
local Curve = require("models.curve")

return {
    name = "Drag Below",
    description = "Lashes a foe within 3, pulls it beside you and Roots it for 1 turn.",
    flavor = "The chain is hot all the way along. It has been down there a long time.",
    sprite = "assets/items/weapon_drag_below.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "pierce", "physical", "fire", "melee" },
    noSteal = true, -- a creature's body is not loot
    activeAbility = {
        target = "enemy",
        range = 3,
        speed = 4,
        requiresSight = true, -- a hook cannot catch what it cannot see
        cost = { stat = "stamina", amount = 6 },
        damage = Curve.ramp(8, 18),
        effect = function(fx)
            local t = fx.target
            if not t then return end
            fx.damage(t)
            require("models.crown_demons").dragBelow(fx, t)
        end,
    },
}
