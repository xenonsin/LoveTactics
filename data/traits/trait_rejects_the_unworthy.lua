-- REJECTS THE UNWORTHY: the Unicorn's rule, carried on its Purity (data/items/utility/utility_purity.lua;
-- "Pride's Bestiary", 2026-09-30).
--
-- It cannot be hurt by a body carrying a debuff, a curse or an injury. The flag is read at the blow
-- (PrideElites.ward, through Status.immuneToDamage, which is handed the ATTACKER), so the hover preview shows
-- the 0 and the log names the ward "Unworthy" before anybody commits a turn to it.
--
-- ITS HORN DECIDES WHO IS UNWORTHY. The Spiral Horn's blow Blights (status_blighted, a debuff), so every body
-- it has struck is turned away until somebody Cures it. And at the end of each of its own turns the horn washes
-- its side clean -- every debuff off every body of its side, itself included -- so a company that controls its
-- escort buys a turn, not a fight.
--
-- The counterplay, stated: keep a clean body on it, Cure the ones it has struck, leave the injured on the
-- bench, and kill the escort the horn keeps washing.
return {
    name = "Rejects the Unworthy",
    description = "Can't be hurt by a body carrying a debuff, a curse or an injury. Cleanses its side at the end of its turn.",
    rejectsUnworthy = true,
    onTurnEnd = function(ctx)
        local unit = ctx.unit
        if unit and unit.alive then require("models.pride_elites").purify(ctx.combat, unit) end
    end,
}
