-- CALL TO VENGEANCE: the Oni General's second verb. Approved 2026-09-27 ("The Oni of Wrath", round 2): "the General
-- points the clan's anger."
--
-- It marks one foe within 5, and every oni of its side whose horn is whole goes Horn Out now, aimed at that foe --
-- whether or not any of them is hurt. The Horn is the race's anger; the General decides when it fires. Once every
-- three turns. Kill the General, and the clan's anger answers to its own wounds again.
return {
    name = "Call to Vengeance",
    description = "Choose a foe within 5. Every oni of your side with its horn whole goes Horn Out at that foe.",
    flavor = "It does not raise its voice. It points, and the horns come out.",
    sprite = "assets/items/ability_call_to_vengeance.png",
    type = "ability",
    tags = { "command" },
    class = "creature",
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 5,
        speed = 3,
        cooldown = 15,
        cost = { stat = "stamina", amount = 6 },
        ai = { priority = "urgent", act = "cast" },
        effect = function(fx)
            local foe, user = fx.target, fx.user
            if not (foe and foe.alive) then return end
            local Trait = require("models.trait")
            local Status = require("models.status")
            for _, u in ipairs(fx.combat.units or {}) do
                if u.alive and u.side == user.side and Trait.flag(u, "oniHorn")
                    and not Status.has(u, "status_horn_snapped") then
                    u.hornTarget = foe
                    if not (Status.has(u, "status_horn_out") or Status.has(u, "status_full_horn_out")) then
                        fx.applyStatus(u, "status_horn_out")
                    end
                end
            end
            fx.log("action", string.format("The General points at %s, and the horns come out.",
                (foe.char and foe.char.name) or "a foe"))
        end,
    },
}
