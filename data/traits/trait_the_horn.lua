-- THE HORN: the oni's racial rule, carried on its grant (data/items/utility/utility_oni_blood.lua) and on the
-- Oni Horn a company can take off a body (utility_oni_horn). Reviewed 2026-09-26/27 ("The Oni of Wrath").
--
-- HORN OUT (status_horn_out) comes on two triggers, and both are about anger rather than arithmetic:
--   * the bearer is wounded to half its health or below;
--   * an oni of the bearer's side is felled, anywhere on the board -- the clan avenges its own. The oni goes for
--     whoever felled it (`unit.hornTarget`, read by AI.preempt).
-- A HORN OUT is once and for the fight. A second trigger only re-aims it at the newer killer.
--
-- SNAPPED (status_horn_snapped): a critical hit on the bearer breaks the horn. Horn Out comes off, the -1 goes on,
-- and nothing brings either back. Two things keep a horn whole against a crit, both approved in review: an ally
-- beside the bearer that keeps horns (the Oni Priestess, `keepsHorn`), and a share of the General's power
-- (status_bestowed) while the General who gave it stands.
--
-- NOT A REACTION: a stunned oni still loses its temper, and a stunned oni's horn still breaks.
local Status = require("models.status")

local function snapped(u) return Status.has(u, "status_horn_snapped") end

-- Is `u`'s horn kept whole against a crit right now?
local function kept(combat, u)
    local gift = Status.get(u, "status_bestowed")
    if gift and gift.giver and gift.giver.alive then return true end
    local Combat = require("models.combat")
    local Trait = require("models.trait")
    for _, other in ipairs(combat.units or {}) do
        if other ~= u and other.alive and other.side == u.side and Trait.flag(other, "keepsHorn")
            and Combat.unitGap(u, other) <= 1 then
            return true
        end
    end
    return false
end

-- Bring the horn out, aimed at `target` when there is one.
local function hornOut(ctx, u, target)
    if not (u and u.alive) or snapped(u) then return end
    if target and target.alive and target.side ~= u.side then u.hornTarget = target end
    if Status.has(u, "status_horn_out") or Status.has(u, "status_full_horn_out") then return end
    ctx.applyStatus(u, "status_horn_out", { applier = u })
    ctx.log("action", string.format("%s's horn comes out.", (u.char and u.char.name) or "The oni"), u)
end

return {
    name = "The Horn",
    description = "Below half health, or when an oni of your side falls: Horn Out. A critical hit snaps the horn.",
    oniHorn = true,
    notAReaction = true,
    onDamaged = function(ctx)
        local u = ctx.unit
        if not (u and u.alive) or snapped(u) then return end
        if ctx.critical and not kept(ctx.combat, u) then
            Status.remove(ctx.combat, u, "status_horn_out")
            Status.remove(ctx.combat, u, "status_full_horn_out")
            u.hornTarget = nil
            ctx.applyStatus(u, "status_horn_snapped", { applier = ctx.attacker })
            ctx.log("action", string.format("%s's horn snaps.", (u.char and u.char.name) or "The oni"), u)
            return
        end
        local Combat = require("models.combat")
        local hp = u.char and u.char.stats and u.char.stats.health
        local max = Combat.unreservedMax(u.char, "health")
        if hp and max > 0 and (hp.current or 0) * 2 <= max then hornOut(ctx, u, ctx.attacker) end
    end,
    onAnyDeath = function(ctx)
        local u, fallen = ctx.unit, ctx.fallen
        if not (u and u.alive and fallen and fallen ~= u and fallen.side == u.side) then return end
        local Trait = require("models.trait")
        if not Trait.flag(fallen, "oniHorn") then return end
        hornOut(ctx, u, fallen.lastAttacker)
    end,
}
