-- BROOD STING: an egg laid in a body (ability_brood_sting, the Brood Queen's trophy). In two turns it
-- hatches: the host takes the damage the sting was cast with, and two Gilded Scarabs crawl out on the
-- STINGER's side (Scarab.hatch), sustained by whoever laid them.
--
-- A debuff, and that is the counterplay: Cure takes the egg out before it hatches. Status fires onExpire
-- on every removal path, so the hatch is read only on a NATURAL expiry -- a cured egg is just gone.
return {
    name = "Brood",
    abbr = "Egg",
    description = "An egg in the wound: when the time runs out, it hatches two scarabs for the one who laid it.",
    color = { 0.70, 0.58, 0.28 },
    duration = 10, -- two turns
    magnitude = 10,
    debuff = true,
    onApply = function(ctx)
        if ctx.status.layer == nil then ctx.status.layer = ctx.applier end
    end,
    onExpire = function(ctx)
        local host = ctx.unit
        if not (ctx.combat and host and host.alive) or (ctx.status.remaining or 0) > 0 then return end
        local layer = ctx.status.layer
        ctx.damage(host, ctx.magnitude or 10, { "pierce" }, { raw = true })
        local side = (layer and layer.side) or "party"
        local level = layer and layer.char and layer.char.level
        require("models.scarab").hatch(ctx.combat, host.x, host.y, side, 2, level,
            (layer and layer.alive) and layer or nil)
    end,
}
