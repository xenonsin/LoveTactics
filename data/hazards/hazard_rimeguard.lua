-- Rimeguard: the cold coming off a plate of frozen mail. Enemies standing in it are Crippled -- slowed
-- to a crawl -- and allies feel nothing at all.
--
-- The purest area-denial aura the game has, and the point of it is that it deals NOTHING. A damage aura
-- makes standing near you expensive, which an enemy answers by taking the damage and killing you
-- anyway. A movement aura makes standing near you SLOW, which an enemy cannot answer at all except by
-- not being there -- and "not being there" is the entire job of the knight who wears it. It turns the
-- wearer into terrain.
--
-- Sided (`ctx.isAlly`), so your own line is never bogged down by the wall it is forming around. That
-- asymmetry is what lets a Rimeguard knight anchor a doorway with the party's skirmishers working
-- freely through the same tiles -- which is the shape of a good defensive turn in this game and was
-- previously very hard to build.
--
-- Ground that walks (Combat.layIncense): laid around the wearer each move, lifted from where they
-- were. The chill is wherever the plate is, and nowhere else.
return {
    name = "Rimeguard",
    description = "Biting cold: enemies standing in it are slowed to a crawl.",
    sprite = "assets/hazards/rimeguard.png",
    tags = { "ice" },
    duration = 6,
    disposition = "hostile", -- the enemy AI would rather go around
    onEnter = function(ctx)
        if ctx.isAlly(ctx.unit) then return end
        ctx.applyStatus(ctx.unit, "status_cripple")
    end,
}
