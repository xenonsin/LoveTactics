-- STONE: Medusa's gaze settling into a body (models/gorgon.lua; "Envy's Bestiary", row md_body). A stack for every
-- turn a body ends in her sight within 4, and one for every foe the Gorgon's Gaze catches. AT THREE IT IS
-- PETRIFIED for 2 turns (status_petrified), and the Stone is spent doing it -- the threshold lives here, so the
-- gaze and the drop petrify by one rule.
--
-- Its own word on purpose: the Homunculus's lives are Red Stone (one word per mechanic). A debuff, so a Cure
-- takes the count off; it lasts until it petrifies or is cured, so the badge quotes no hourglass.
return {
    name = "Stone",
    abbr = "Stn",
    description = "Turning to stone. At 3 Stone, Petrified for 2 turns.",
    color = { 0.62, 0.60, 0.55 }, -- badge tint (weathered marble)
    duration = math.huge,
    hideDuration = true,
    magnitude = 1,
    stacks = 3,
    debuff = true,
    onApply = function(ctx)
        if (ctx.status.magnitude or 0) < 3 then return end
        ctx.expire()
        ctx.applyStatus(ctx.unit, "status_petrified", { applier = ctx.applier })
    end,
}
