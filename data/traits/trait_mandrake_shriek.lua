-- The Shriek: a mandrake screams when it comes up, and everything near enough to hear it goes down.
--
-- THE LEGEND, KEPT. Whoever pulls a mandrake up is struck down by the scream, which is why the old herbals
-- tie a dog to it and walk away. Here it fires on death -- the one way a planted thing ever leaves its
-- tile -- and it Stuns every body within `radius`, on BOTH sides, the bearer's own line included. The
-- blast shape is trait_volatile's, the death hook is trait_volatile's, and the payload is the
-- difference: a Volatile body burns what is near it, this one takes their turn.
--
-- WHICH TWISTS THE LUST CIRCLE'S STANDING LAW. "Cut the one doing it" holds -- the root it was holding
-- lets go -- but cutting it in melee stuns your own front line. Shoot it, or do what the herbals did and
-- let something else pull it up: a charmed body, a summon, a thrall. The Alraune Anchoress's Compline
-- fires the same scream WITHOUT the death (weapon_compline), reading `radius` off this file so the two
-- cannot drift apart.
return {
    name = "The Shriek",
    description = "On death, Stuns every body within 2 tiles, both sides.",
    radius = 2,
    onDeath = function(ctx)
        ctx.burst(ctx.unit.x, ctx.unit.y, { "nature" })
        ctx.log("status", string.format("%s shrieks as it comes up.",
            (ctx.unit.char and ctx.unit.char.name) or "The mandrake"))
        for _, u in ipairs(ctx.unitsNear(ctx.unit.x, ctx.unit.y, ctx.def.radius or 2)) do
            if u ~= ctx.unit and u.alive then
                ctx.applyStatus(u, "status_stun", { applier = ctx.unit })
            end
        end
    end,
}
