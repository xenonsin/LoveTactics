-- BLOOD COMMUNION: the Communicant's rite (Wrath's vampires, 2026-09-26). It opens its own vein -- 15% of its max
-- health, as a toll -- and every other vampire within 2 drinks that much: its Thirst resets and it heals 30% of
-- the drink as a feeding heal (fx.feed). Distinct from Transfusion, which moves health to one ally: this is one
-- body paying to reset a whole brood's Thirst. Kill the Communicant and the brood goes thirsty.
local SHARE = 0.15

return {
    name = "Blood Communion",
    description = "Lose 15% of your max health. Every other vampire within 2 drinks it: its Thirst resets and it heals.",
    flavor = "It holds its opened wrist over the bowl, and the others kneel to it in turn.",
    sprite = "assets/items/ability_blood_communion.png",
    type = "ability",
    tags = { "natural", "blood" },
    class = "creature",
    noSteal = true,
    activeAbility = {
        target = "self",
        range = 0,
        speed = 4,
        cooldown = 10,
        support = true,
        ai = { priority = "high", act = "cast", label = "the brood drinks",
               whenFn = function(ctx)
                   local Thirst = require("models.thirst")
                   local Combat = require("models.combat")
                   for _, u in ipairs(ctx.combat.units or {}) do
                       if u.alive and u ~= ctx.unit and u.side == ctx.unit.side and Thirst.isVampire(u)
                           and Combat.unitGap(ctx.unit, u) <= 2 and Thirst.level(u) >= 1 then
                           return true
                       end
                   end
                   return false
               end },
        effect = function(fx)
            local user = fx.user
            local Combat = require("models.combat")
            local Thirst = require("models.thirst")
            local pay = math.max(1, math.floor(Combat.unreservedMax(user.char, "health") * SHARE + 0.5))
            local paid = fx.drain(user, "health", pay)
            if (paid or 0) <= 0 then return end
            for _, u in ipairs(fx.unitsNear(user.x, user.y, 2)) do
                if u ~= user and u.side == user.side and Thirst.isVampire(u) then fx.feed(u, paid) end
            end
        end,
    },
}
