-- CINDERFALL: the tile a Wrath creature dies on catches fire.
--
-- The volcanic circle's ground is `rifts` -- open country with a road through it -- and its signature
-- hazard is fire (data/biomes/volcanic.lua). This is what makes the circle's chaff worth thinking about:
-- every body you kill takes a tile away from you, so a fight against enough of them slowly removes the
-- room you were going to fight it in.
--
-- Which sets up the two things standing behind the chaff. The Unquenched is HEALED by fire tiles, so
-- clearing the line feeds it; the Anvil grows on blows taken, so being unable to kite means trading, and
-- trading is what pays it. One rule on the cheapest body creates both problems.
--
-- Fires on onDeath (the bearer's own), not onAnyDeath: this is what the body leaves behind, not
-- something it does to others.
return {
    name = "Cinderfall",
    description = "Leaves fire on the tile it falls on.",
    onDeath = function(ctx)
        local u = ctx.unit
        if not (u and u.x and u.y) then return end
        ctx.placeHazard(u.x, u.y, "hazard_fire")
    end,
}
