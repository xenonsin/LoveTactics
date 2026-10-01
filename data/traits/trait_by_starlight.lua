-- BY STARLIGHT: the Elf Starcaller's (data/items/utility/utility_by_starlight.lua). Reworked 2026-10-01 off Born to
-- the Height, which hung the Starcaller on the spire's Exposure -- a zone the arena places with no owner, so it read
-- every body as an ally and did nothing to anyone. The author picked Witchlight over a Starfield of its own and over
-- Darkness.
--
-- So the Starcaller brings its own light (ability_starlight lays Witchlight around a foe) and reads by it:
--   * its spells strike a Limned foe for 3 more (damageBonusVs, a pure query, so the hover shows it);
--   * while any foe on the board is Limned, it casts a tile further out (a live bonus, so the planner and the
--     range highlight move with it). Board-wide rather than per target: reach is read once per cast by
--     Combat.abilityRange, before there is a target to ask about.
local function limnedFoe(combat, u)
    local Status = require("models.status")
    for _, other in ipairs(combat.units or {}) do
        if other.alive and other.side ~= u.side and Status.has(other, "status_limned") then return true end
    end
    return false
end

return {
    name = "By Starlight",
    description = "Your spells deal 3 more damage to a Limned foe. While any foe is Limned, your reach grows by 1.",
    bonus = 3,
    damageBonusVs = function(ctx)
        if ctx.hasTag("magical") and ctx.hasStatus(ctx.target, "status_limned") then return ctx.def.bonus or 3 end
        return 0
    end,
    live = function(ctx)
        local u, combat = ctx.unit, ctx.combat
        if not (u and combat) then return nil end
        if limnedFoe(combat, u) then return { range = 1 } end
        return nil
    end,
}
