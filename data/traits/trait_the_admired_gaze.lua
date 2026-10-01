-- THE GAZE THAT IS ADMIRED: the Peacock-Basilisk's rule (data/items/utility/utility_the_admired_gaze.lua).
-- Approved 2026-09-30 on Pride's bestiary review. A reverse taunt: a taunt makes you strike the taunter; this
-- punishes you for not having done so. Any foe within 3 that ENDS its turn without having attacked the bird is
-- Stunned.
--
-- "ATTACKED IT" is either of two things, and both are needed. A wound that reached it (onDamaged, which carries
-- the attacker -- `notAReaction`, so a stunned bird still keeps count), or an offensive cast whose footprint
-- covered it (onAnyCast), so a swing that missed still counts as having looked at it. Each is stamped with
-- combat.turnCount, which only advances once the actor's turn is over (Combat.endTurn / Combat.wait), so the
-- mark can only answer for the turn it was made in.
--
-- The drop, the Peacock's Train, wears this same rule at radius 2 with Rattled in place of Stun (`traitParams`).
local function covers(ctx, ab)
    local u = ctx.unit
    if not (ab and ctx.tx and ctx.ty) then return false end
    if ctx.tx == u.x and ctx.ty == u.y then return true end
    if not ab.aoe then return false end
    local Combat = require("models.combat")
    for _, c in ipairs(Combat.aoeCells(ctx.combat, ab, ctx.tx, ctx.ty, ctx.caster)) do
        if c.x == u.x and c.y == u.y then return true end
    end
    return false
end

local function mark(ctx, who)
    if not (who and who.side ~= ctx.unit.side) then return end
    ctx.unit._admiredBy = ctx.unit._admiredBy or {}
    ctx.unit._admiredBy[who] = ctx.combat.turnCount or 0
end

return {
    name = "The Gaze That Is Admired",
    description = "A foe within 3 that ends its turn without attacking it is Stunned.",
    notAReaction = true,
    radius = 3,
    status = "status_stun",
    onDamaged = function(ctx) mark(ctx, ctx.attacker) end,
    onAnyCast = function(ctx)
        local ab = ctx.castAbility
        if not ab or ab.support then return end
        if ab.target == "enemy" or ab.damage ~= nil then
            if covers(ctx, ab) then mark(ctx, ctx.caster) end
        end
    end,
    onAnyTurnEnd = function(ctx)
        local u, a = ctx.unit, ctx.actor
        if not (u.alive and a and a.alive and a.side ~= u.side) then return end
        local marks = u._admiredBy or {}
        local looked = marks[a] == (ctx.combat.turnCount or 0)
        marks[a] = nil
        if looked then return end
        local Combat = require("models.combat")
        if Combat.unitGap(u, a) > ctx.param("radius", 3) then return end
        ctx.applyStatus(a, ctx.param("status", "status_stun"), { applier = u, duration = ctx.param("duration") })
    end,
}
