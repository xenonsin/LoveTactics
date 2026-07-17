-- Wild Shape (Bear): the timer that owns a hunter's bear body. The twin of wild_shape_wolf -- same
-- split (the cast wears the shape so it can bind the reservation; this counts it down and reverts it),
-- same reasoning, different animal.
--
-- Shorter than the wolf's window on purpose. The bear is the stronger body by a distance -- plate-grade
-- defense and a greatsword's damage -- so what it costs is not more mana but less TIME: the wolf is a
-- stance you settle into for a stretch of the fight, the bear is a thing you become for one exchange
-- that matters. Two shapes, two prices, and the hunter picks which one the moment is asking for.
return {
    name = "Bear Shape",
    abbr = "Bear",
    description = "Wearing a bear's body: armored, heavy-handed, and holding your mana to stay that way.",
    color = { 0.55, 0.40, 0.28 }, -- badge tint (bear brown)
    duration = 20,
    illusion = true, -- dispellable, exactly as the wolf shape is; see data/status/wild_shape_wolf.lua
    onExpire = function(ctx)
        ctx.revert() -- releases the shape's reserved mana with it
    end,
}
