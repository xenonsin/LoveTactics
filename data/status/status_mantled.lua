-- MANTLED: a hawk is on you and feeding. Root's flags (review note on Mantling: "have it root") and a
-- feed every turn -- a Bleed only bites a body that walks, and a rooted body does not, so the feed ticks
-- like Poison instead.
--
-- NOT A DEBUFF, on purpose: a Cure does not lift a bird off you. What lifts it is hitting the hawk
-- (data/traits/trait_mantling.lua), which any ally can do and which the hawk cannot dodge while it eats.
--
-- THIS STATUS OWNS THE GRIP, both ends of it. Applied by the Raking Talons through fx.applyStatus, so a
-- hover preview (whose applyStatus moves nothing) can never pin anybody; onApply ties the hawk to the prey
-- and puts status_mantling on the hawk, and onExpire -- which fires on every removal path, a hit on the
-- hawk, either body falling -- unties it. `mantledBy` stays on a FALLEN prey, because the Sated reads it
-- off the corpse to eat the bird with the body (data/traits/trait_three_meals.lua).
return {
    name = "Mantled",
    abbr = "Mtd",
    description = "A hawk is feeding on it: cannot move or be moved, and bleeds each turn until the hawk is struck.",
    color = { 0.685, 0.206, 0.237 }, -- badge tint (Bleed's red)
    duration = 999,
    hideDuration = true,
    magnitude = 3, -- health a turn, spread over the clock
    blocksMove = true,
    blocksForcedMove = true,
    stopsMovement = true,
    onApply = function(ctx)
        local prey, hawk = ctx.unit, ctx.applier
        if not (hawk and hawk.alive) or prey.mantledBy then return end
        prey.mantledBy, hawk.mantlingPrey = hawk, prey
        ctx.applyStatus(hawk, "status_mantling")
    end,
    onExpire = function(ctx)
        local prey = ctx.unit
        local hawk = prey.mantledBy
        if hawk then
            hawk.mantlingPrey = nil
            require("models.status").remove(ctx.combat, hawk, "status_mantling")
        end
        if prey.alive then prey.mantledBy = nil end
    end,
    onTick = function(ctx)
        local n = ctx.accrue(ctx.magnitude)
        if n > 0 then ctx.damage(ctx.unit, n, { "bleed" }, { raw = true }) end
    end,
}
