-- Devotion at its edge: when a would-be-lethal blow lands on an adjacent ally, the bearer takes it
-- instead -- once per battle (Combat.tryRedirect reads `unit.guard` and its `used` latch). The
-- redirected hit runs through the bearer's own armor and barriers, so a well-defended martyr may
-- survive the blow it stepped into; a fragile one buys the ally's life with its own.
return {
    name = "Martyr's Vow",
    description = "Once per battle, take a lethal blow meant for an adjacent ally.",
    onCombatStart = function(ctx)
        ctx.unit.guard = { kind = "martyr" }
    end,
}
