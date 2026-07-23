-- The exit price of a Stillshade. While the rogue is hidden and carrying the shade's mark, the first
-- thing they cast is a thing they cast on the way out -- and the body it lands on is left Exposed.
--
-- Hangs on onCast rather than on the ability itself, and that is the only place it CAN hang: the spell
-- that vanishes the rogue does not know who they will step out onto, because that decision is a turn
-- away and belongs to the player. What the vanishing can do is leave a promise on its caster, and this
-- is the thing that collects it.
--
-- Spends both statuses when it fires -- the mark it read and the concealment it stepped out of -- which
-- keeps the whole exchange to a single payout. A rogue does not get to open two bodies off one shade,
-- and Combat.dealDamage would have broken the concealment anyway; clearing it here makes the rule
-- visible rather than incidental.
--
-- Deliberately NOT gated on the cast being a knife. Stepping out of the shade with a bomb, a bow or a
-- borrowed wand still opens the target -- what the shade sold was the ambush, and an ambush does not
-- care what you were holding. The ability's own `requiresAdjacent = { tag = "dagger" }` already made
-- the loadout argument; making it twice would just be a tax.
return {
    name = "Stillshade",
    description = "The strike that breaks its concealment leaves the target open to piercing hits.",
    onCast = function(ctx)
        local Status = require("models.status")
        if not Status.has(ctx.unit, "status_mark") then return end
        if not Status.has(ctx.unit, "status_invisible") then return end
        -- The body that was aimed at, read off the event's own cell rather than off any notion of a
        -- "target": a cast that hit nobody (a summon, a placed trap) breaks the shade without opening
        -- anything, which is the honest reading of stepping out for no reason.
        local victim = ctx.unitAt(ctx.tx, ctx.ty)
        ctx.clearStatus(ctx.unit, "status_mark")
        ctx.clearStatus(ctx.unit, "status_invisible")
        if not (victim and victim.alive and victim.side ~= ctx.unit.side) then return end
        ctx.applyStatus(victim, "status_exposed")
        ctx.log("status", string.format("%s steps out of the shade, and %s is wide open.",
            ctx.unit.char and ctx.unit.char.name or "Unit",
            victim.char and victim.char.name or "the target"), { ctx.unit, victim })
    end,
}
