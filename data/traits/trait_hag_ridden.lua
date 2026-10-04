-- HAG-RIDDEN: the Mare's end of the ride ("Sloth's Bestiary", 2026-10-04, approved). Carried on its Hag's Weight
-- (data/items/weapon/weapon_hags_weight.lua), which is what climbs on: a blow on a body that is Asleep puts
-- status_hag_ridden on the sleeper, and that status ties the two bodies together.
--
-- AT THE TOP OF EACH OF THE MARE'S TURNS the sleeper it rides takes the Mare's damage, and does not wake
-- (Combat.sparesSleep). The ride ENDS when:
--   * anything strikes the Mare -- the counterplay the review names, "strike or shove the Mare off";
--   * the Mare is moved off the sleeper's side (it is checked at the top of its turn, and Combat.sparesSleep already
--     stops sparing the moment the two are apart);
--   * the sleeper wakes some other way, or falls; or the Mare falls.
--
-- THE DEPARTURE FROM THE PAGE: the review had the Mare share the sleeper's tile. No two bodies share a tile in this
-- engine, so it sits BESIDE the sleeper and pins itself there (status_riding), as the hawk does over its prey.
--
-- `notAReaction`: being knocked off is not an answer the Mare throws.
local Status = require("models.status")

local function unseat(combat, mare)
    local body = mare.ridingBody
    if body then Status.remove(combat, body, "status_hag_ridden") end
    mare.ridingBody = nil
    Status.remove(combat, mare, "status_riding")
end

local function name(u) return (u and u.char and u.char.name) or "it" end

return {
    name = "Hag-Ridden",
    description = "Rides a sleeping foe it strikes: blows do not wake it, and it takes this body's damage each turn.",
    notAReaction = true,
    unseat = unseat,
    onTurnStart = function(ctx)
        local combat, mare = ctx.combat, ctx.unit
        local body = mare.ridingBody
        if not body then return end
        local Combat = require("models.combat")
        if not body.alive or not Status.has(body, "status_sleep") or Combat.unitGap(mare, body) > 1 then
            unseat(combat, mare)
            return
        end
        ctx.log("action", string.format("%s sits heavier on %s.", name(mare), name(body)), { mare, body })
        Combat.dealFlatDamage(combat, body, Combat.flatStat(mare, "damage"), { "dark", "magical" }, "Hag-Ridden", mare)
    end,
    onDamaged = function(ctx)
        if not ctx.unit.ridingBody then return end
        unseat(ctx.combat, ctx.unit)
        ctx.log("action", string.format("%s is thrown off.", name(ctx.unit)), ctx.unit)
    end,
    onDeath = function(ctx)
        if ctx.unit.ridingBody then unseat(ctx.combat, ctx.unit) end
    end,
    onAnyDeath = function(ctx)
        if ctx.fallen and ctx.fallen == ctx.unit.ridingBody then unseat(ctx.combat, ctx.unit) end
    end,
}
