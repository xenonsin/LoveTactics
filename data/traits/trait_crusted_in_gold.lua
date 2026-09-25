-- CRUSTED IN GOLD: the Gilded Belly relic, worn (data/items/utility/utility_gilded_belly.lua). Reviewed
-- 2026-09-25 ("Avaritia, the Unspent"): her armour and her weak spot in one piece.
--
-- +2 Defense and +2 Magic Defense for every 100 gold the company holds, up to +10 each -- read live off the
-- purse, so a rich company is hard to hurt and one that has just spent is not. While the wearer winds
-- anything up, the bonus is gone and every pierce blow into it is a critical (the same `bareWhileChanneling`
-- flag she wears, Combat.forcesCrit): it is hard to hurt until it commits.
local PER, STEP, CAP = 2, 100, 10

return {
    name = "Crusted in Gold",
    description = "Increase defense and magic defense by 2 per 100 gold held (up to 10). Winding up, lose it and take pierce as critical.",
    bareWhileChanneling = true,
    live = function(ctx)
        if not ctx.combat or ctx.unit.channel then return nil end
        local gold = require("models.combat").purseAvailable(ctx.combat, ctx.unit) or 0
        local n = math.min(CAP, PER * math.floor(gold / STEP))
        if n <= 0 then return nil end
        return { defense = n, magicDefense = n }
    end,
}
