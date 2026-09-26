-- MARCHING DRUM: the orc War-Drummer's drop, round 2 (2026-09-26, "The Orcs of Wrath"). The March as a cast: every
-- ally takes one free step toward its own nearest foe (models/march.lua). Keno's note: "have the step be forced,
-- the player didn't select" -- you choose WHEN to beat it, never where anyone goes, so a body beside a Berserker
-- steps in whether you want it to or not.
return {
    name = "Marching Drum",
    description = "Every ally takes one step toward its nearest foe.",
    flavor = "It is not a signal. A signal can be ignored.",
    sprite = "assets/items/ability_marching_drum.png",
    type = "ability",
    tags = { "command" },
    class = "warlord",
    unlockLevel = 7,
    unstocked = true,
    activeAbility = {
        target = "self",
        range = 0,
        speed = 3,
        cooldown = 10,
        support = true,
        cost = { stat = "stamina", amount = 6 },
        effect = function(fx)
            local user, combat = fx.user, fx.combat
            if not (user and combat) then return end
            local line = {}
            for _, u in ipairs(combat.units or {}) do
                if u.alive and u.side == user.side then line[#line + 1] = u end
            end
            require("models.march").stepAll(combat, line, function(u, x, y) fx.teleport(u, x, y, { glide = true }) end)
        end,
    },
}
