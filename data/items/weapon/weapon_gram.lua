-- Gram: the sword Sigurd killed Fafnir with, from a pit dug in the wyrm's path. Off the Gilt Wyrm
-- (data/characters/character_gilt_wyrm.lua), reviewed 2026-09-25.
--
-- A sword, so it keeps the family's Parry (docs/weapons.md). What it adds is the pit, carried: FROM BELOW
-- (data/traits/trait_from_below.lua) -- stand your ground, and a foe that came to you is struck
-- critically. The trench itself was an encounter's board and was cut with the encounter; this is the
-- half of it a company can take home.
local Curve = require("models.curve")

return {
    name = "Gram",
    description = "Answers an adjacent melee blow. If you have not moved this turn, a strike on a foe that came to you is a critical.",
    flavor = "Reforged from a father's broken sword, to kill a brother's son. It has never been asked to do anything smaller.",
    sprite = "assets/items/weapon_gram.png",
    type = "weapon",
    tags = { "sword", "slash", "physical", "melee" },
    hands = 1,
    class = "knight",
    unlockLevel = 12,
    unstocked = true,
    traits = { "trait_parry", "trait_from_below" },
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 3,
        cost = { stat = "stamina", amount = 8 },
        damage = Curve.ramp(14, 24),
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
