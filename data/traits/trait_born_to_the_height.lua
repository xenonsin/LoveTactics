-- BORN TO THE HEIGHT: the Elf Starcaller's (data/items/utility/utility_born_to_the_height.lua). Approved 2026-09-30
-- ("Pride's Bestiary"). The spire's Exposure (data/hazards/hazard_exposure.lua) does nothing to it (`groundproof`,
-- Hazard.shrugs), and standing on it, it casts the harder and the further: +3 Magic Damage and +1 reach, a live
-- bonus (Trait.liveBonus), so the forecast moves with the ground under it.
local Hazard = require("models.hazard")

return {
    name = "Born to the Height",
    description = "Immune to Exposure. On it, increase magic damage by 3 and reach by 1.",
    groundproof = { hazard_exposure = true },
    live = function(ctx)
        local u, combat = ctx.unit, ctx.combat
        if not (u and combat) then return nil end
        if Hazard.at(combat, u.x, u.y, "hazard_exposure") then return { magicDamage = 3, range = 1 } end
        return nil
    end,
}
