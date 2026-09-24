-- TITHE FEATHER: the flight brings its take home. When one of your summoned beasts lands a blow on a foe,
-- you recover 3 health. A Beastmaster charm off the Griffin; approved on review (2026-09-23).
--
-- Heard through Trait.onAllyStrike, which the striker's side hears when a blow lands and the foe lives --
-- so a killing blow pays nothing. That is the hook's own rule, and it keeps the charm from paying twice
-- on the swing that ends a fight.
return {
    name = "Tithe Feather",
    description = "When a beast you summoned strikes a foe, recover 3 health.",
    heal = 3,
    onAllyStrike = function(ctx)
        local beast = ctx.ally
        if not (beast and beast.summoner == ctx.unit) then return end
        ctx.heal(ctx.unit, ctx.param("heal", 3))
    end,
}
