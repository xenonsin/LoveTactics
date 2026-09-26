-- BLOOD OFFERING: the orc Blood-Caller's cast, and its drop (2026-09-26, "The Orcs of Wrath"). Pay 15% of your
-- max health; an ally within 4 heals by what you paid and becomes Proven by one stack without a kill
-- (status_proven). Round 2 added the heal on Keno's note, "Have it heal", and the enemy Blood-Caller casts the same
-- thing -- so it heals the orcs it blesses, and is worth killing first.
local SHARE = 0.15

return {
    name = "Blood Offering",
    description = "Pay 15% of your max health. The target heals that much and is Proven.",
    flavor = "It opens its own arm and holds it out. The orcs do not thank it. They drink.",
    sprite = "assets/items/ability_blood_offering.png",
    type = "ability",
    tags = { "blood", "magical" },
    class = "shaman",
    unlockLevel = 8,
    unstocked = true,
    activeAbility = {
        target = "ally",
        excludeSelf = true,
        range = 4,
        speed = 3,
        cooldown = 10,
        support = true,
        cost = { stat = "mana", amount = 8 },
        ai = { priority = "high", act = "cast", targetPref = "lowest_hp" },
        effect = function(fx)
            local target, user = fx.target, fx.user
            if not (target and target.alive and user) or target == user or target.side ~= user.side then return end
            local Combat = require("models.combat")
            local pay = math.max(1, math.floor(Combat.unreservedMax(user.char, "health") * SHARE + 0.5))
            fx.flatDamage(user, pay, { "bleed" })
            fx.heal(target, pay)
            fx.applyStatus(target, "status_proven")
        end,
    },
}
