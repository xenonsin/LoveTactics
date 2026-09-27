-- BESTOW: the Oni General's third verb. Approved 2026-09-27 ("The Oni of Wrath", round 2), after Reincarnated as a
-- Slime's premise that power is something a leader GIVES -- on an oni already standing, never an ogre.
--
-- One oni ally within 3 gains +2 to every stat, and its horn cannot be snapped while the General stands
-- (status_bestowed, read by trait_the_horn). The giving costs the giver: it is Spent (its next turn comes later).
return {
    name = "Bestow",
    description = "An oni ally within 3 gains +2 to every stat, and its horn cannot be snapped while you stand. You are Spent.",
    flavor = "What it gives is not strength. It is the permission to stop holding it back.",
    sprite = "assets/items/ability_bestow.png",
    type = "ability",
    tags = { "command" },
    class = "creature",
    noSteal = true,
    activeAbility = {
        target = "ally",
        excludeSelf = true,
        range = 3,
        speed = 3,
        cooldown = 20,
        cost = { stat = "stamina", amount = 8 },
        support = true,
        ai = { priority = "high", act = "cast" },
        effect = function(fx)
            local t, user = fx.target, fx.user
            if not (t and t.alive and t ~= user) then return end
            local Status = require("models.status")
            if Status.has(t, "status_bestowed") then return end
            if not require("models.trait").flag(t, "oniHorn") then return end
            fx.applyStatus(t, "status_bestowed")
            fx.applyStatus(user, "status_spent")
        end,
    },
}
