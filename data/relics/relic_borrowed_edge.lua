-- ENVY · VICE · combat · common. The Crucible's sin wants the thing's PROPERTY and would rather you
-- had neither, so this takes a keenness that is not yours and cannot hold it for long.
--
-- The front line opens Heroic; the whole company pays a little mana for the borrowing, including the
-- bodies that carry none, where it simply costs nothing -- which is the joke and also the balance: a
-- line of knights borrows free, and a caster funds them.
return {
    name = "The Borrowed Edge",
    blurb = "The front line opens Heroic, drawn out of everyone else's reserves.",
    tier = "common", alignment = "vice", affinity = "combat", weight = 2,
    sin = "envy",
    cost = "The company opens each fight with less mana.",
    battleStart = function(_, _, ctx)
        for _, c in ipairs(ctx.frontRow()) do ctx.grantBoon(c, "status_heroism") end
        for _, c in ipairs(ctx.party) do ctx.drain(c, "mana", 4) end
    end,
}
