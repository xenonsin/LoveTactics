-- Aloft: a wyvern that has taken wing and is hanging over the fight until it comes down on somebody.
--
-- It rides TAKE WING's wind-up as that ability's `channelStatus` (Combat.useItem), so it lasts exactly as
-- long as the tell does, and what ends it is the Stoop the channel resolves into -- which is why a body
-- that takes wing always dives (the review: "it has to dive after using take wing"). The company's
-- Skyward is the same wind-up worn by a person.
--
-- NOTHING REACHES IT UP THERE. `untargetable` keeps it off every aimed cast and every AI's target scan,
-- and `immune` to both channels means a blast that paints its tile lands for nothing and says so in the
-- receipt. A poison already in its blood still ticks -- a tick is flat damage with no channel on it, and
-- a wound it flew away with is still a wound. It cannot be shoved either, nor answer anything.
--
-- THE DOWNDRAFT is here rather than in the ability, because an ability's `effect` runs when a channel
-- RESOLVES and this has to happen on the beat it LEAVES: whoever stood beside it is blown a tile back
-- (Combat.knockback, so a shove into a wall is a collision like any other).
--
-- A BUFF, not a debuff: it is the bearer's own choice, so Cure does not pull it down, and nothing about
-- it can be resisted.
return {
    name = "Aloft",
    abbr = "Up",
    description = "Aloft: out of reach until it comes down. It cannot be targeted, harmed by a blow, moved or answer.",
    color = { 0.80, 0.88, 0.95 }, -- badge tint (open sky)
    duration = 10, -- a fallback; the channel sets the real length and the Stoop ends it
    untargetable = true,
    immune = { physical = true, magical = true },
    disablesReactions = true,
    blocksMove = true,
    blocksForcedMove = true,
    onApply = function(ctx)
        if not ctx.combat then return end
        local Combat = require("models.combat")
        for _, other in ipairs(Combat.unitsNear(ctx.combat, ctx.unit.x, ctx.unit.y, 1)) do
            if other ~= ctx.unit and other.alive and other.side ~= ctx.unit.side then
                Combat.knockback(ctx.combat, ctx.unit, other, 1)
            end
        end
    end,
}
