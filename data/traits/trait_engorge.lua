-- ENGORGE: Gluttony's rule, one rank down, and the mechanic the whole swamp circle is built on.
--
-- Gula's Ravenous heals her on EVERY blow she lands (data/traits/trait_ravenous.lua), so a long trade
-- only fattens her and the counterplay is to starve her -- burst, kill clean, never grind. That is a
-- fine rule for the thing at the bottom of a circle and a terrible one to meet cold: a player who has
-- never seen it reads a boss that will not go down and has no idea why.
--
-- So this is the same appetite taught the cheap way: it feeds on the KILL rather than on the hit.
-- Finishing something is legible, it is infrequent, and it is a consequence the player can watch happen
-- and reason backwards from. Then Gula does it every swing, and the lesson is already paid for.
--
-- Fires on onAnyDeath rather than onCast, which is what makes it a kill rather than a hit -- and it
-- reads the FALLEN body's side, so the bearer is fed by its own chaff dying as readily as by yours. A
-- Tallow Hound standing behind three Gorge-Flies is being fed by the flies you are killing, which is
-- the pack's combo and not an accident.
--
-- `heal` is flat rather than a fraction of the body eaten. A fraction would make the swarm worthless to
-- eat and the party enormous, which is exactly backwards: the point is that clearing the chaff in front
-- of the hound is what makes the hound a problem.
return {
    name = "Engorge",
    description = "Whenever anything falls nearby, it feeds and heals.",
    heal = 12,
    range = 3, -- it has to be close enough to get to the body, not merely on the same board
    onAnyDeath = function(ctx)
        local fallen = ctx.fallen
        local u = ctx.unit
        if not (fallen and u and u.alive) then return end
        if fallen == u then return end -- it does not feed on itself
        local dx, dy = math.abs((fallen.x or 0) - u.x), math.abs((fallen.y or 0) - u.y)
        if math.max(dx, dy) > (ctx.def.range or 3) then return end
        ctx.heal(u, ctx.def.heal)
        ctx.log("action", string.format("%s feeds.", (u.char and u.char.name) or "It"))
    end,
}
