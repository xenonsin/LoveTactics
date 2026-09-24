-- SLOUGH: the Mosswrap's rule (data/items/armor/armor_mosswrap.lua). The first time each battle the
-- bearer is struck below half health, a piece of the moss sloughs off and stands up beside them as a
-- Moss Sloughling, carrying a fifth of their health. It fights, walks home, and Rejoins -- giving back
-- what it has left (ability_rejoin).
--
-- Once per battle on `stacks`, as Second Wind is: a coat that shed a piece on every blow would be a
-- summoner's kit, not armour.
return {
    name = "Slough",
    description = "Once per battle, when struck below half health, a moss sloughling sloughs off beside you.",
    share = 0.2,
    onDamaged = function(ctx)
        local u = ctx.unit
        if not (u and u.alive) or ctx.trait.stacks > 0 then return end
        local hp = u.char.stats.health
        if hp.current * 2 >= hp.max then return end
        local x, y = ctx.openTileNear(u.x, u.y)
        if not x then return end
        ctx.trait.stacks = 1
        local health = math.max(1, math.floor(hp.max * ctx.param("share", 0.2) + 0.5))
        ctx.summon("character_moss_sloughling", x, y, { noClaim = true, announce = false,
            stats = { health = health } })
        ctx.log("action", string.format("A piece of %s's moss sloughs off and stands up.",
            (u.char and u.char.name) or "it"), u)
    end,
}
