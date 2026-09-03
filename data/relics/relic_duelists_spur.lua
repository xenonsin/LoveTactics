-- COMMON. The front line opens every fight a step ahead of the foe. A battleStart boon (status_hasted)
-- spent through the same opening-boons seam the companion abilities use -- so a found relic and a
-- companion's banked readiness stack onto the same unit without either knowing about the other.
--
-- Stacks as DURATION: one copy is the opening, four is most of a short fight. That is the shape every
-- opening-boon relic on this rung takes, because a status already applied cannot be applied harder.
return {
    name = "Duelist's Spur",
    blurb = "The front line opens every fight Hasted, for %d turns.",
    tier = "common", mark = "Sp",
    scale = { 3, 1 },
    battleStart = function(_, _, ctx)
        for _, c in ipairs(ctx.frontRow()) do
            ctx.grantBoon(c, "status_hasted", { duration = ctx.mag(3, 1) })
        end
    end,
}
