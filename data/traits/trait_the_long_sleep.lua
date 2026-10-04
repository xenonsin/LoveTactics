-- THE LONG SLEEP: Desidia's relic, for a knight ("Sloth's Bestiary", slice G, approved word for word). Each round you
-- use nothing banks a turn, up to 3. When you are struck, take every banked turn at once.
--
-- THE BANK IS HERS (status_banked through models/bank.lua, held to this piece's own cap of 3). A round here is the
-- bearer's own turn: one that ends with no item used since it opened banks one.
--
-- "AT ONCE" IS ORDER, the engine's one currency for it (Combat.grantExtraAction). A blow that lands with turns in
-- the bank empties it, brings the bearer's turn round next, and hands it the rest as extra actions: three banked
-- turns are three actions in a row, with nothing from the other side between them. A reflex, so a stunned or
-- sleeping bearer keeps its bank for the next blow; and a bearer already winding something up is left to it.
local function Bank() return require("models.bank") end

local CAP = 3

return {
    name = "The Long Sleep",
    description = "Each round you use nothing banks a turn, up to 3. When you are struck, take every banked turn at once.",
    onTurnStart = function(ctx)
        ctx.unit.longSleepCasts = ctx.tally("cast")
    end,
    onTurnEnd = function(ctx)
        local u = ctx.unit
        if u.longSleepCasts ~= nil and ctx.tally("cast") == u.longSleepCasts then
            Bank().add(ctx.combat, u, 1, ctx.param("cap", CAP))
        end
        u.longSleepCasts = nil
    end,
    onDamaged = function(ctx)
        local u = ctx.unit
        if (ctx.amount or 0) <= 0 or u.channel or not u.alive then return end
        local n = Bank().spend(ctx.combat, u)
        if n <= 0 then return end
        local Combat = require("models.combat")
        u.initiative = 0
        if n > 1 then Combat.grantExtraAction(u, n - 1) end
        ctx.log("action", string.format("%s wakes all at once: %d turns, back to back.",
            (u.char and u.char.name) or "Unit", n), u)
    end,
}
