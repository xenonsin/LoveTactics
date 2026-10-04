-- BRIDGE MAUL: the Toll-Troll's weapon (data/characters/character_toll_troll.lua). Approved 2026-10-04 ("Sloth's
-- Bestiary", slice B).
--
-- Its reach IS the toll's: The Toll strikes whatever uses something within the weapon's reach
-- (data/traits/trait_the_toll.lua), so a two-tile haft is a two-tile bridge. Two, because no carried melee weapon
-- reaches past 2 (tests/tactics_ability_spec.lua). A creature's own kit: never loot.
local Curve = require("models.curve")

return {
    name = "Bridge Maul",
    description = "Strikes a foe within 2.",
    flavor = "The haft is long so it can reach the far side of the bridge without the troll having to.",
    sprite = "assets/items/weapon_bridge_maul.png",
    type = "weapon",
    tags = { "hammer", "impact", "physical", "melee" },
    hands = 2,
    class = "creature",
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 2,
        speed = 7,
        cost = { stat = "stamina", amount = 10 },
        damage = Curve.ramp(14, 24),
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
