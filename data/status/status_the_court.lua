-- THE COURT, as the turn-start half of Luxuria's rule (data/traits/trait_the_court.lua puts it on her at
-- the bell; models/court.lua holds the mechanics). A status rather than a trait because a status is what
-- the engine asks at the start of a turn -- traits have no such hook.
--
-- At the start of each of her turns, in this order:
--   1. she takes whoever the Procession has walked in since her last turn (bound and sworn to her);
--   2. below half her health, the Procession quickens (once);
--   3. with a foe beside her, she changes partners: trades places with one of her own anywhere on the
--      board, leaving the foe facing it.
--
-- Neither a buff nor a debuff, so no Cure and no dispel reaches it -- the rule is hers, and what
-- silences it is what silences every relic: Sunder. It wears a badge with no countdown, so the rule she is
-- running is on the board where the player can hover it.
return {
    name = "The Court",
    abbr = "Crt",
    description = "At the start of her turn she takes newcomers, and trades places with one of her own "
        .. "when a foe stands beside her.",
    color = { 0.837, 0.469, 0.755 }, -- the charm's own magenta
    duration = math.huge,
    hideDuration = true,
    hideLog = true,
    onTurnStart = function(ctx)
        local Court = require("models.court")
        local Status = require("models.status")
        local me = ctx.unit
        if not me.alive then return end
        -- A Sundered queen's court does nothing: the same gag Trait.flag applies to every relic rule.
        if Status.has(me, "status_sundered") then return end
        local took = Court.bind(ctx.combat, me)
        if took > 0 then
            ctx.log("status", string.format("%d more kneel to %s.", took,
                (me.char and me.char.name) or "her"), me)
        end
        if Court.belowHalf(me) and Court.quicken(ctx.combat) then
            ctx.log("status", "Her court comes faster now.", me)
        end
        Court.changePartners(ctx.combat, me)
    end,
}
