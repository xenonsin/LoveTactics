-- NAME THE ENEMY: the Hobgoblin's order (approved as pitched, 2026-09-26, "The Goblins of Wrath"). The warband's
-- Feud goes to whoever hits them; the Hobgoblin PICKS it. It marks any foe within 5 as its side's Feud
-- (status_blood_feud, clearing the old one), and every goblin that can reach that body goes for it.
--
-- The alpha escalates in KIND, not in size: while it stands the company loses the Feud lever. Kill it and the
-- warband goes back to chasing whoever hurts it. A body's own, never shelved -- the Hobgoblin drops its Lash.
--
-- Written through fx verbs only (clearStatus / applyStatus), so the forecast's dry run moves nothing.
return {
    name = "Name the Enemy",
    description = "Marks a foe as the goblins' Feud.",
    flavor = "It is the only goblin that is not angry. That is why the others listen.",
    sprite = "assets/items/ability_name_the_enemy.png",
    type = "ability",
    tags = { "command" },
    class = "creature",
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 5,
        speed = 3,
        cooldown = 15,
        cost = { stat = "stamina", amount = 4 },
        notOn = { "status_blood_feud" },
        ai = { priority = "high", act = "cast", targetPref = "lowest_hp" },
        effect = function(fx)
            local target, user = fx.target, fx.user
            if not (target and target.alive) then return end
            local old = require("models.feud").of(fx.combat, user.side)
            if old and old ~= target then fx.clearStatus(old, "status_blood_feud") end
            fx.applyStatus(target, "status_blood_feud", { applier = user })
        end,
    },
}
