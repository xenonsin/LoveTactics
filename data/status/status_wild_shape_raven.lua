-- Wild Shape (Raven): the timer that owns a hunter's bird body. The shape itself is worn by the
-- ability's effect (data/items/ability/ability_wild_shape_raven.lua) rather than by an onApply hook
-- here, exactly as the Wolf's does and for the same reason -- a self-transform is sustained like a
-- summon, and only the cast knows what reservation its own ability declared.
--
-- Not a debuff: it is something the hunter did to itself, and Cure washes away what was done TO you. So
-- a shifted hunter cannot Panacea out of it early -- the commitment is the price of the reach.
--
-- onExpire is the single reversion point and fires on EVERY removal path, so there is no way to end
-- this status and leave a hunter as a bird. See data/status/status_wild_shape_wolf.lua, which is this
-- file with one word changed.
return {
    name = "Raven Shape",
    abbr = "Ravn",
    description = "Wearing a raven's body: fast, fragile, and still shooting.",
    color = { 0.42, 0.44, 0.55 }, -- badge tint (blue-black pinion)
    duration = 30,
    -- A lie told about a body, so Dispel Illusions strips it and the reserved mana returns with it --
    -- the shape's real counterplay, and the one a hunter has to respect (Cure cannot touch it).
    illusion = true,
    onExpire = function(ctx)
        ctx.revert() -- releases the shape's reserved mana with it
    end,
}
