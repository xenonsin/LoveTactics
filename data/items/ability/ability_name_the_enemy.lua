-- NAME THE ENEMY: the Hobgoblin's order (approved as pitched, 2026-09-26, "The Goblins of Wrath"). The warband's
-- Feud goes to whoever hits them; the Hobgoblin PICKS it. It marks any foe within 5 as its side's Feud
-- (status_blood_feud, clearing the old one), and every goblin that can reach that body goes for it.
--
-- The alpha escalates in KIND, not in size: while it stands the company loses the Feud lever. Kill it and the
-- warband goes back to chasing whoever hurts it. A body's own, never shelved -- the Hobgoblin drops its Lash.
--
-- THE NAME HOLDS (2026-11-19, the creature identity pass; models/feud.lua's Feud.named). The paragraph above made
-- the Hobgoblin a kill-the-head alpha, the shape six Wrath races shared. A named Feud is not moved by a blow on a
-- goblin and does not end when the Hobgoblin falls; it runs out, or a Cure lifts it (Blood Feud is a debuff). So
-- killing the Hobgoblin no longer frees the named body: the lever is to BRING a cleanse for whoever it names.
--
-- Written through fx verbs only (clearStatus / applyStatus), so the forecast's dry run moves nothing.
return {
    name = "Name the Enemy",
    description = "Marks a foe as the goblins' Feud. Blows on goblins do not move it, and it lasts after the caster falls.",
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
            -- NAMED (models/feud.lua's Feud.named): no blow on a goblin moves it, and it outlives the Hobgoblin.
            -- Stamped only on a status that really landed -- a dry run's applyStatus returns nil.
            local landed = fx.applyStatus(target, "status_blood_feud", { applier = user })
            if type(landed) == "table" then landed.named = true end
        end,
    },
}
