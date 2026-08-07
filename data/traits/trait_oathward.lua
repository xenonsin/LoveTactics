-- The Knight's innate, and the counterweight to Sloth ("the oath abandoned" -- the Knight keeps
-- theirs). The Knight stands as a guardian: the first attack each turn against an ally standing
-- adjacent is taken by the Knight instead (Combat.tryRedirect reads `unit.guard`). A cooldown gates
-- it to one intercept per turn's worth of ticks, so a wall of blows still gets through -- the Knight
-- is a shield, not an aegis.
--
-- The redirect is set up once, at combat start; the interception itself, and its cooldown, live in
-- the damage core (models/combat.lua), so any relic that grants this trait guards exactly the same way.
return {
    name = "Oathward",
    description = "The first hit each turn on an adjacent ally is taken by you instead.",
    onCombatStart = function(ctx)
        -- How long the guard needs before it can cover the next blow. Six for a knight who swore it;
        -- the Crucible golem's hands name nine, because a wall that is always up is not a wall, it is
        -- a rule. That used to be a second trait (Bulwark) identical to this one but for the number.
        ctx.unit.guard = { kind = "oathward", cooldown = ctx.param("guardCooldown", 6) }
    end,
}
