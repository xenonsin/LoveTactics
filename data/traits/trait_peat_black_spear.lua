-- PEAT-BLACK SPEAR: the Bog Bodies' trophy on the Sentinel's shelf (data/items/weapon/weapon_peat_black_spear.lua;
-- "Sloth's Bestiary", 2026-10-04, slice C). A foe that ends its turn in the bearer's reach is struck.
--
-- REACH IS THE SPEAR'S OWN TWO TILES: a foe up to 2 away in a straight line, the line its thrust runs. Measured
-- here rather than through Combat.answeringWeapon, which reads a spear as the range-1 aim that sets its facing
-- and would only ever see the near tile. The blow is the spear itself (Combat.answerStrike), so armour and the
-- target's own answers apply. Heard on the foe's own turn end (Trait.onAnyTurnEnd). A REFLEX: a stunned or
-- sleeping sentinel watches nobody.
local REACH = 2

return {
    name = "Peat-Black Spear",
    description = "A foe that ends its turn in your reach is struck.",
    onAnyTurnEnd = function(ctx)
        local u, foe, spear = ctx.unit, ctx.actor, ctx.item
        if not (u and u.alive and foe and foe.alive and foe.side ~= u.side and spear) then return end
        local Combat = require("models.combat")
        if require("models.status").disablesReactions(u) or Combat.isOffTile(foe) then return end
        if not (foe.x == u.x or foe.y == u.y) or Combat.unitGap(u, foe) > REACH then return end
        ctx.log("action", string.format("%s strikes as %s settles.", (u.char and u.char.name) or "It",
            (foe.char and foe.char.name) or "the foe"), u)
        Combat.answerStrike(ctx.combat, u, foe, spear)
    end,
}
