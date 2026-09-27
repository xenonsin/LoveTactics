-- THE HORNLESS SISTER (utility_the_hornless_sister). She wears Borrowed Horn from the opening (the mana draw runs
-- on its onTurnStart), and a blow on her brings her sister's horn out, aimed at whoever struck her.
local Status = require("models.status")

local function sister(combat, u)
    local Trait = require("models.trait")
    for _, other in ipairs((combat and combat.units) or {}) do
        if other ~= u and other.alive and other.side == u.side and Trait.flag(other, "hornedSister") then
            return other
        end
    end
    return nil
end

return {
    name = "The Hornless Sister",
    description = "Draw your mana from your sister each turn. When you are struck, her horn comes out.",
    hornlessSister = true,
    notAReaction = true,
    sister = sister,
    onCombatStart = function(ctx)
        if ctx.unit and ctx.unit.alive then
            ctx.applyStatus(ctx.unit, "status_borrowed_horn", { applier = ctx.unit })
        end
    end,
    onDamaged = function(ctx)
        local s = sister(ctx.combat, ctx.unit)
        if not s or Status.has(s, "status_horn_snapped") then return end
        local a = ctx.attacker
        if a and a.alive and a.side ~= s.side then s.hornTarget = a end
        if Status.has(s, "status_horn_out") or Status.has(s, "status_full_horn_out") then return end
        ctx.applyStatus(s, "status_horn_out", { applier = s })
        ctx.log("action", string.format("%s's horn comes out for her sister.", (s.char and s.char.name) or "She"), s)
    end,
}
