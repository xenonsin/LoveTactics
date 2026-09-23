-- CAST THE NET: the Larder Mother's own web, and the one play that can catch a whole company. Web on
-- every tile around a foe, three by three -- laid onto an occupied tile it takes effect at once
-- (Hazard.place treats the occupant as an entry), so whoever stands in it is caught where they stand.
-- Her other spiders' Silk Shots will not be spent on them afterwards (`notOn`).
--
-- Fire answers it the way it answers every strand: a fire cast over the net burns the whole of it off.
return {
    name = "Cast the Net",
    description = "Lays Web over every tile around a foe, catching whoever stands there.",
    flavor = "The wood has a floor, a canopy and, over the part of it you are standing in, a lid.",
    sprite = "assets/items/ability_cast_the_net.png",
    type = "ability",
    class = "creature",
    tags = { "silk" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 4,
        requiresSight = true,
        speed = 5,
        cost = { stat = "stamina", amount = 12 },
        aoe = { shape = "square", radius = 1 },
        ai = { priority = "high", act = "cast" },
        effect = function(fx)
            for _, c in ipairs(fx.aoeCells()) do fx.placeHazard(c.x, c.y, "hazard_web") end
        end,
    },
}
