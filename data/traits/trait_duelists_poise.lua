-- Duelist's Poise: the Duelist's passive (fighter x rogue). When only ONE foe stands adjacent to the
-- bearer -- a true one-on-one -- every blow the bearer lands bites deeper. Reads the strike through the
-- damageBonusVs hook (models/trait.lua -> Combat.dealDamage), a pure query summed into the pre-mitigation
-- base, so the bonus rides the hover preview and armour still softens it. Counts foes adjacent to the
-- bearer via Combat.unitsNear (lazy-required to avoid a load cycle); exactly one means a duel.
return {
    name = "Duelist's Poise",
    description = "When you face exactly one adjacent foe, your blows deal extra damage.",
    bonus = 6, -- flat, pre-mitigation, while it is a true 1v1
    damageBonusVs = function(ctx)
        local Combat = require("models.combat")
        local n = 0
        for _, u in ipairs(Combat.unitsNear(ctx.combat, ctx.unit.x, ctx.unit.y, 1)) do
            if u.alive and u.side ~= ctx.unit.side then n = n + 1 end
        end
        if n == 1 then return ctx.def.bonus or 6 end
        return 0
    end,
}
