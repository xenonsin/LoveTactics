-- WRATH · VICE · combat · common. The circle's own temptation: hit harder by refusing to guard.
--
-- Wrath is not anger here, it is the trade every Colosseum quest is about -- what you will give up to
-- land the blow. So the front line opens Heroic and opens winded: the swing is real and the wind to
-- take a second one is not there.
--
-- `sin` weights it up on a Wrath floor (models/relic.lua) and does nothing anywhere else, so this is
-- still an ordinary shelf entry on every other circle and in the campaign.
return {
    name = "The Scar That Answers",
    blurb = "The front line opens every fight Heroic -- and out of breath.",
    tier = "common", alignment = "vice", affinity = "combat", weight = 2,
    sin = "wrath",
    cost = "The party opens each fight with less stamina.",
    battleStart = function(_, _, ctx)
        for _, c in ipairs(ctx.frontRow()) do ctx.grantBoon(c, "status_heroism") end
        for _, c in ipairs(ctx.party) do ctx.drain(c, "stamina", 3) end
    end,
}
