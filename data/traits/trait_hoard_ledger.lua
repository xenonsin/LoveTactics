-- THE HOARD-LEDGER: Every Coin Counted, for the company (reviewed 2026-09-25, round 3, "Avaritia, the
-- Unspent"). Denied as first pitched (a stack per heap looted) with the note "Make it + Damage based on how
-- much gold your company has" -- so it reads the purse, the Gilded Belly relic's shape turned to the claws:
-- +2 Damage per 100 gold the company holds, up to +10. Live, so it falls the moment the purse is spent.
local PER, STEP, CAP = 2, 100, 10

return {
    name = "Hoard-Ledger",
    description = "Increase damage by 2 per 100 gold the company holds (up to 10).",
    live = function(ctx)
        if not ctx.combat then return nil end
        local gold = require("models.combat").purseAvailable(ctx.combat, ctx.unit) or 0
        local n = math.min(CAP, PER * math.floor(gold / STEP))
        if n <= 0 then return nil end
        return { damage = n }
    end,
}
