-- CLOSE RANKS: Pride's rule, and the mechanic the castle circle is built on.
--
-- Formation Fighter already exists and already measures adjacency continuously
-- (data/traits/trait_formation_fighter.lua): defense per ally standing beside you, gained as the line
-- forms and lost as it breaks. What it does not do is make the rank worth ATTACKING in, so a formation
-- is currently a thing that survives rather than a thing that threatens.
--
-- This is the offensive half. Damage per ally adjacent, read live off the board the same way -- so a
-- closed rank hits harder and a broken one hits like four individuals. Together the two traits make a
-- Pride body genuinely bipolar: enormous in line, ordinary out of it.
--
-- WHY IT BELONGS TO THE CASTLE. The stratum's carve is `rooms` -- a warren of chambers -- so a doorway
-- is where a formation comes apart, and the fight is about making them come through one. On open ground
-- the same bodies would simply stay in a block and the rule would be a flat bonus.
--
-- `live` rather than a hook: this is a claim about the field as it currently stands, which is exactly
-- what Trait.liveBonus is for. Nothing is banked, so a rank pulled apart loses it in the same instant.
return {
    name = "Close Ranks",
    description = "Gains damage for each ally standing beside it, as the line forms and as it breaks.",
    live = function(ctx)
        local n = ctx.count(1, "ally")
        if n == 0 then return nil end
        return { damage = 3 * n, magicDamage = 2 * n }
    end,
}
