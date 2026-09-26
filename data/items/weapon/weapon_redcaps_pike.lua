-- THE REDCAP'S PIKE: the Redcap's weapon, and its second drop. Round 2 (2026-09-26, "The Goblins of Wrath"),
-- on Keno's note beside the Dipped Cap: "also have another item that heals on kills." A killing blow heals the
-- bearer 20% of its max health (trait_redcaps_pike) -- the half of the round-1 Redcap drop that was kept.
local Curve = require("models.curve")

return {
    name = "Redcap's Pike",
    description = "A killing blow heals you for 20% of your max health.",
    flavor = "Short for a pike, long for a knife, and never once cleaned.",
    sprite = "assets/items/weapon_redcaps_pike.png",
    type = "weapon",
    tags = { "spear", "pierce", "physical", "melee" },
    class = "assassin",
    unlockLevel = 8,
    unstocked = true,
    traits = { "trait_redcaps_pike" },
    activeAbility = {
        target = "tile",       -- a spear: aim an adjacent tile, and the thrust runs two deep
        allowOccupied = true,
        range = 1,
        minRange = 1,
        speed = 3,
        cost = { stat = "stamina", amount = 6 },
        damage = Curve.ramp(11, 22),
        aoe = { shape = "line", length = 2 },
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do fx.damage(u) end
        end,
    },
}
