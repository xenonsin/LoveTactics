-- Wild Shape (Wolf): the timer that owns a hunter's wolf body. The shape itself is worn by the
-- ability's effect (data/items/ability/ability_wild_shape_wolf.lua) rather than by an onApply hook
-- here -- exactly the split Charm uses, and for exactly the same reason: the effect can reach things a
-- status hook cannot. Here it is the RESERVATION. A self-transform is sustained like a summon, and
-- only the cast knows what its ability declared, so the cast wears the shape and this counts it down.
--
-- Not a debuff: it is something the hunter did to itself, and Cure washes away what was done TO you.
-- The practical upshot is that a wild-shaped hunter cannot Panacea its way out early -- the commitment
-- is the cost of the power, and buying out of it would be buying the power for nothing.
--
-- onExpire is still the single reversion point, and it fires on EVERY removal path (countdown, a
-- dispel, anything future) -- so there is no way to end this status and leave a hunter as a wolf. The
-- upkeep the shape held is released by the revert itself (models/transform.lua).
return {
    name = "Wolf Shape",
    abbr = "Wolf",
    description = "Wearing a wolf's body: fast, sharp-toothed, and holding your mana to stay that way.",
    color = { 0.62, 0.66, 0.72 }, -- badge tint (wolf grey)
    duration = 30,
    -- A lie told about a body -- a hunter that says it's a wolf -- so Dispel Illusions strips it, and
    -- the shape's reserved mana comes back with it. This is the shape's real counterplay, and the one
    -- the hunter has to respect: Cure can't touch it (it isn't a debuff -- you did it to yourself), so
    -- a priest on the other side answers wild shape with a sweep, not a cleanse.
    illusion = true,
    onExpire = function(ctx)
        ctx.revert() -- releases the shape's reserved mana with it
    end,
}
