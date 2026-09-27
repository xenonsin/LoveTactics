-- UNBLESSING: the Oni Priestess's dispel. Approved 2026-09-26 ("The Oni of Wrath"): "she strips one buff off a
-- company body." fx.dispelUnit with a cap of one -- the single-target strip the Confessor's Needle shelf built.
local Curve = require("models.curve")

return {
    name = "Unblessing",
    description = "Strips one blessing from a foe within 4.",
    flavor = "What a god gave, a shrine can ask back.",
    sprite = "assets/items/ability_unblessing.png",
    type = "ability",
    tags = { "holy", "magical" },
    class = "creature",
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 4,
        speed = 3,
        cooldown = 10,
        cost = { stat = "mana", amount = 6 },
        ai = { priority = "high", act = "cast" },
        effect = function(fx)
            if fx.target and fx.target.alive then fx.dispelUnit(fx.target, 1) end
        end,
    },
}
