-- TROLL BLOOD: what the Troll's draught leaves in the one who drank it (data/items/consumable/
-- consumable_troll_blood.lua). Approved 2026-10-04 ("Sloth's Bestiary", slice B).
--
-- The troll race's own regrowth (data/traits/trait_indifferent.lua) for the rest of the fight: a fifth of the
-- drinker's health at the top of each of their turns, unless fire or acid reached them since their last. It takes
-- the regrowth and leaves the never-dodging behind -- that half is what a troll IS, and this is only its blood. The
-- burn mark is kept on the unit under the race's own field, so the two read one way.
--
-- A blessing, not a debuff, and it is the whole fight's: no countdown to show.
local REGROW = 0.2

local function burned(tags)
    for _, t in ipairs(tags or {}) do
        if t == "fire" or t == "acid" then return true end
    end
    return false
end

return {
    name = "Troll Blood",
    abbr = "TBld",
    description = "Troll Blood: regrows a fifth of its health each turn, unless fire or acid reached it since its last.",
    color = { 0.420, 0.600, 0.380 }, -- badge tint (troll green)
    duration = math.huge,
    hideDuration = true,
    onDamaged = function(ctx)
        if (ctx.amount or 0) > 0 and burned(ctx.tags) then ctx.unit.trollScorched = true end
    end,
    onTurnStart = function(ctx)
        local u = ctx.unit
        if not (u and u.alive) then return end
        if u.trollScorched then
            u.trollScorched = nil
            return
        end
        local Combat = require("models.combat")
        local max = Combat.unreservedMax(u.char, "health")
        if max - (u.char.stats.health.current or 0) > 0 then ctx.heal(u, math.max(1, math.floor(max * REGROW))) end
    end,
}
