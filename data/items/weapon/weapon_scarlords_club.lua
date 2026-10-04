-- SCARLORD'S CLUB: the Troll Scarlord's weapon (data/characters/character_troll_scarlord.lua). Approved 2026-10-04
-- ("Sloth's Bestiary", slice B).
--
-- Scarring Blows' first half: the blow carries the Unclosing Wound (`inflicts`, so a miss lays nothing), laid long
-- and lifted at the Scarlord's next turn by its organ (data/traits/trait_scarring_blows.lua). A creature's copy of
-- the Scarring Club, which is what it drops.
local Curve = require("models.curve")

return {
    name = "Scarlord's Club",
    description = "Inflicts Unclosing Wound until your next turn.",
    flavor = "Every notch in it is somebody's healer arriving one turn late.",
    sprite = "assets/items/weapon_scarlords_club.png",
    type = "weapon",
    tags = { "hammer", "impact", "physical", "melee" },
    hands = 2,
    class = "creature",
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 7,
        cost = { stat = "stamina", amount = 10 },
        damage = Curve.ramp(14, 24),
        effect = function(fx)
            -- Laid for 30 ticks and taken off at the striker's next turn: the length is a ceiling, the turn is
            -- the rule (models/sloth_trolls.lua, Trolls.closeScars).
            fx.damage(fx.target, { inflicts = { id = "status_unclosing_wound", duration = 30 } })
        end,
    },
}
