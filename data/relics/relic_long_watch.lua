-- SLOTH · VIRTUE · combat · common. The Bastion's sin is the post abandoned, so its virtue is the
-- post kept: the company opens every fight already dug in, mending as it stands.
--
-- Regeneration rather than a barrier on purpose. A ward is spent by the first blow that lands and says
-- nothing about staying; a regen pays out for as long as the line holds, which is the only thing this
-- circle has ever been about.
return {
    name = "The Long Watch",
    blurb = "The whole company opens every fight recovering -- the post kept, and kept, and kept.",
    tier = "common", alignment = "virtue", affinity = "combat", weight = 2,
    sin = "sloth",
    battleStart = function(_, _, ctx)
        for _, c in ipairs(ctx.party) do ctx.grantBoon(c, "status_regen") end
    end,
}
