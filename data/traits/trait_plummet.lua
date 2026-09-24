-- Plummet: the Plummet Cloak's rule, which is a wyvern's Stoop rebuilt for somebody on foot -- come a long
-- way before you strike and the strike carries it.
--
-- A blow thrown after covering THREE tiles or more this turn deals a quarter of the thrower's Damage
-- again, through the damageBonusVs hook (a pure query summed into the pre-mitigation base, so the hover
-- preview quotes it and armour still softens it). Measured as Combat.tilesMovedThisTurn -- distance from
-- where the turn opened, not steps taken -- so it pays for having GONE somewhere, the Skirmisher shelf's
-- own unit of account.
--
-- Its two neighbours on that shelf measure the same distance and buy different things: the Outrider's
-- Harness (two tiles, and the blow cannot be answered) and Running Shot (three damage a tile, a bow's).
-- This is the melee-or-anything one, and it asks for the longer run.
return {
    name = "Plummet",
    description = "A blow thrown after covering three tiles or more this turn deals a quarter of your Damage more.",
    minTiles = 3,
    share = 0.25,
    damageBonusVs = function(ctx)
        local Combat = require("models.combat")
        if Combat.tilesMovedThisTurn(ctx.unit) < (ctx.def.minTiles or 3) then return 0 end
        return math.floor(Combat.flatStat(ctx.unit, "damage") * (ctx.def.share or 0.25) + 0.5)
    end,
}
