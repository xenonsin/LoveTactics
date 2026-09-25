-- PACK: the kobold's racial rule, carried on Underfoot (data/items/utility/utility_underfoot.lua).
-- Approved as pitched (2026-09-24, "The Kobolds of Greed"): +2 damage for every OTHER kobold standing
-- beside the foe it strikes, to +6.
--
-- Closed Ranks turned round. That charm counts the allies beside YOU; this counts the kin beside the
-- body being hit, so a kobold alone is a nuisance and three round your mage are a problem. The counter
-- is where the company stands -- a corridor, or a wall at your back, leaves room for one.
--
-- Read at blow time (Trait.outgoingDamageBonus), and pure: the forecast asks it on every hover. Only
-- devout kin count (models/devotion.lua) -- a dwarf standing beside the target is no kobold's packmate.
local MAX_KIN = 3
local PER_KIN = 2

return {
    name = "Pack",
    description = "Increase damage by 2 for every other kobold beside the foe you strike, to +6.",
    damageBonusVs = function(ctx)
        local combat, unit, target = ctx.combat, ctx.unit, ctx.target
        if not (combat and unit and target) then return 0 end
        local Combat = require("models.combat")
        local Devotion = require("models.devotion")
        local kin = 0
        for _, u in ipairs(combat.units or {}) do
            if u ~= unit and u ~= target and u.alive and u.side == unit.side
                and Devotion.isDevout(u) and Combat.unitGap(u, target) == 1 then
                kin = kin + 1
            end
        end
        return PER_KIN * math.min(kin, MAX_KIN)
    end,
}
