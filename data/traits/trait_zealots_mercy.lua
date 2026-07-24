-- Zealot's Mercy: the standing rule of the Crusader's Tabard (data/items/armor/armor_crusaders_tabard.lua).
-- Fell a foe and the wound closes -- by a base amount, plus one for every point of Zeal the crusader is
-- holding at the moment the body drops.
--
-- Reads the pool WITHOUT spending it, which is what makes Zeal worth carrying rather than dumping. The
-- Reckoning is the crusade's spender; this is the interest it pays while you hold it. A crusader with a
-- full pool who never casts Reckoning is not playing wrong -- they are playing the sustain half, and the
-- tabard is what makes that a real choice instead of a mistake.
--
-- Hangs on onAnyDeath rather than on a kill hook so a foe finished by an ally still mends the crusader
-- standing over it: the crusade is not a scoreboard. It asks two questions the dividend does not --
-- whose side was it (an ally falling is not a mercy) and was it close enough to see.
return {
    name = "Zealot's Mercy",
    magnitude = 3, -- tiles: a death farther off than this is not yours to be lifted by
    onAnyDeath = function(ctx)
        local fallen = ctx.fallen
        if not (fallen and ctx.unit.alive) then return end
        if fallen.side == ctx.unit.side then return end -- an ally's death is not a mercy
        local reach = ctx.def.magnitude or 3
        local d = math.abs(ctx.unit.x - fallen.x) + math.abs(ctx.unit.y - fallen.y)
        if d > reach then return end
        local Combat = require("models.combat")
        local zeal = Combat.chargePool(ctx.unit, "zeal")
        Combat.applyHeal(ctx.combat, ctx.unit, 4 + zeal)
        ctx.log("action", string.format("%s is mended by the fall (%d Zeal).",
            (ctx.unit.char and ctx.unit.char.name) or "The crusader", zeal), ctx.unit)
    end,
}
