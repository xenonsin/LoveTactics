-- STATIC: the Arc's rule, and the Static Coil's (models/storm.lua; "Fire, Lightning, and Dirty Thunder",
-- 2026-09-27). Every tile the bearer walks stores a charge (Combat.stepMove -> Storm.stepped), to 5, worn as
-- status_static; its next LIGHTNING cast deals +3 per charge and spends them all. Rooted, Stunned or Grounded, the
-- charge runs into the floor and is wasted.
--
-- A body that has to keep moving to hit hard -- which casters seldom do. The Minotaur's Run pays a straight
-- approach in distance on a blow; this pays any walk in damage on a bolt.
local Storm = require("models.storm")

local WASTED = { status_root = true, status_stun = true, status_grounded = true }

local function castTags(item)
    local tags = {}
    for _, t in ipairs((item and item.tags) or {}) do tags[#tags + 1] = t end
    local ab = item and item.activeAbility
    for _, t in ipairs((ab and ab.tags) or {}) do tags[#tags + 1] = t end
    return tags
end

local function lightning(tags)
    for _, t in ipairs(tags or {}) do
        if t == "lightning" then return true end
    end
    return false
end

return {
    name = "Static",
    description = "Each tile you walk stores a charge (to 5); your next lightning cast deals +3 per charge.",
    static = true,
    per = Storm.STATIC_PER,
    damageBonusVs = function(ctx)
        if not ctx.hasTag("lightning") then return 0 end
        return Storm.charges(ctx.unit) * ctx.param("per", Storm.STATIC_PER)
    end,
    onCast = function(ctx)
        -- ctx.item is the CAST item here (the event shadows the granting one).
        if lightning(castTags(ctx.item)) and Storm.charges(ctx.unit) > 0 then
            ctx.clearStatus(ctx.unit, "status_static")
        end
    end,
    onStatusApplied = function(ctx)
        local st = ctx.status
        local id = st and (st.id or (st.def and st.def.id))
        if ctx.recipient == ctx.unit and id and WASTED[id] and Storm.charges(ctx.unit) > 0 then
            ctx.clearStatus(ctx.unit, "status_static")
        end
    end,
}
