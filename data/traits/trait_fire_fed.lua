-- FIRE-FED: the Goblin Firebrand's third rule, carried on Firewalker's Wraps
-- (data/items/utility/utility_firewalkers_wraps.lua). +3 Damage while the bearer stands on burning ground.
--
-- A live bonus (Trait.liveBonus), read wherever Damage is read, so the forecast, the sheet and the swing all
-- agree with the ground the bearer is on right now -- step off the fire and it is gone.
local BONUS = 3

return {
    name = "Fire-Fed",
    description = "Increase damage by 3 while standing in fire.",
    live = function(ctx)
        local u, combat = ctx.unit, ctx.combat
        if not (u and combat) then return nil end
        if require("models.hazard").at(combat, u.x, u.y, "hazard_fire") then return { damage = BONUS } end
        return nil
    end,
}
