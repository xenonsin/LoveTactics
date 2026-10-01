-- SKYWALKER: the Skywalker's Sandals (data/items/armor/armor_skywalkers_sandals.lua), the Elf Starcaller's drop.
-- Approved 2026-09-30 ("Pride's Bestiary"). The Starcaller's first rule (Born to the Height, since reworked into By
-- Starlight), widened to every ground and narrowed in what it
-- pays: no hostile zone does anything to the wearer (`groundproof`, Hazard.shrugs), and standing in one, +2 Magic
-- Damage. The spire's height is one hazard; the sandals walk on all of them.
local Hazard = require("models.hazard")

return {
    name = "Skywalker",
    description = "Immune to ground hazards. Increase magic damage by 2 while standing on one.",
    groundproof = true,
    live = function(ctx)
        local u, combat = ctx.unit, ctx.combat
        if not (u and combat) then return nil end
        for _, h in ipairs(Hazard.allAt(combat, u.x, u.y)) do
            if Hazard.shrugs(u, h) then return { magicDamage = 2 } end
        end
        return nil
    end,
}
