-- Skimmer's Cut: Final Fantasy Tactics' Gilgame Heart and Steal Gil, folded into one honest sentence --
-- the bearer takes coin off the enemy every time it lands a blow, and keeps it. Carried by the
-- Undercroft's Skimmer's Cut (data/items/utility/utility_skimmers_cut.lua).
--
-- Greed's own rule, stated without any of the usual softening. Every other charm on the rogue's rack
-- helps you win the fight; this one does not help you win the fight at all. It converts violence you
-- were committing anyway into money, which is precisely the Undercroft's position on violence.
--
-- Fired from onCast, exactly as trait_ravenous is (data/traits/trait_ravenous.lua) -- it rides on any
-- offensive action the bearer commits rather than on a specific weapon, so a dagger, an axe and a
-- thrown bomb all pay. What it will not pay for:
--   * A cast aimed at an ally or at empty ground. There has to be somebody to pick clean.
--   * A summoned or conjured target, which has no pockets. Copying a man does not copy his purse, and
--     a party that could farm coin off its own summons would be printing it.
--
-- The gold accumulates on the combat and is handed over with the spoils on a WIN (Combat.skimGold), so
-- losing the fight loses the takings. See that function for why the payout works that way.
return {
    name = "Skimmer's Cut",
    description = "Every blow the bearer lands on a living foe lifts a little coin, paid out with the spoils.",
    gold = 4, -- coin per landed blow; small, because it is paid on a per-swing basis
    onCast = function(ctx)
        local target = ctx.unitAt(ctx.tx, ctx.ty)
        if not target or not target.alive then return end
        if target.side == ctx.unit.side then return end -- allies are not a revenue stream
        if target.summoned then return end              -- a conjuration carries no purse
        local taken = ctx.combat and require("models.combat").skimGold(ctx.combat, ctx.unit, ctx.def.gold) or 0
        if taken > 0 then
            ctx.log("action", string.format("%s lifts %d gold in the exchange.",
                (ctx.unit.char and ctx.unit.char.name) or "The rogue", taken), ctx.unit)
        end
    end,
}
