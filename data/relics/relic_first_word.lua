-- PRIDE · VIRTUE · combat · rare. The Arcanum's sin is the conviction that you can read a thing
-- safely, and its reward is the same conviction paying off: you go first, and going first is most of
-- what a tactics battle is.
--
-- Rare and weight 1, because opening Hasted AND warded is the strongest clean thing on the shelf. It
-- reaches only the front line, so it is a statement about the people who walked into the room first
-- rather than a company-wide buff.
return {
    name = "The First Word",
    blurb = "The front line opens every fight Hasted and warded -- whoever speaks first is answered last.",
    tier = "rare", alignment = "virtue", affinity = "combat", weight = 1,
    sin = "pride",
    battleStart = function(_, _, ctx)
        for _, c in ipairs(ctx.frontRow()) do
            ctx.grantBoon(c, "status_hasted")
            ctx.grantBoon(c, "status_magical_barrier")
        end
    end,
}
