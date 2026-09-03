-- COMMON. Sloth's circle read as the post KEPT rather than abandoned: the company opens every fight
-- already dug in, mending as it stands.
--
-- Regeneration rather than a barrier on purpose. A ward is spent by the first blow that lands and says
-- nothing about staying; a regen pays out for as long as the line holds, which is the only thing this
-- circle has ever been about.
--
-- IT ABSORBED THE OLD RELIQUARY DRAUGHT, which was this relic exactly -- the same loop over the same
-- party granting the same status -- filed one tier up because it wore a different badge. That is the
-- clearest thing the moral axis was hiding, and the merge is why it is worth a note here.
return {
    name = "The Long Watch",
    blurb = "The whole company opens every fight regenerating, for %d turns.",
    tier = "common", mark = "Wa",
    sin = "sloth",
    scale = { 3, 1 },
    battleStart = function(_, _, ctx)
        for _, c in ipairs(ctx.party) do
            ctx.grantBoon(c, "status_regen", { duration = ctx.mag(3, 1) })
        end
    end,
}
