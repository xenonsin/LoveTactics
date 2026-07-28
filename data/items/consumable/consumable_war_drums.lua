-- War Drums: a marching cadence beaten once, hard, at the moment the line commits. Every ally standing
-- within a tile of the drummer is Inspired (data/status/status_inspiration.lua) -- courage in the swing
-- and the shield, a lift to Damage and Defense.
--
-- It is the Rally Banner's field said as a FIGHT DECISION rather than a build one. The banner plants a
-- standing zone you hold ground around; the drum spends itself for one burst of the same morale, wherever
-- the company happens to be clustered when you strike it. That is exactly the charm/coating split the
-- shelf draws everywhere else (see docs/classes.md): the permanent fixture is worth less per use than the
-- thing you spend, and the drum is the thing you spend -- so a party that has drifted out of its banner's
-- shadow can still be rallied for the turn that matters, and then the drum is gone.
--
-- Inspiration handed out this way is not zone-bound -- there is no zone -- so it runs on its own backstop
-- clock (the status's `duration`) and then fades. A rally you beat out of a drum is a rally you have to
-- beat again.
return {
    name = "War Drums",
    description = "Allies adjacent to you gain Inspiration.",
    flavor = "The Colosseum sells the cadence, not the courage. The courage was always yours; the drum only names the moment.",
    sprite = "assets/items/consumable_war_drums.png",
    type = "consumable",
    tags = { "rally" },
    class = "fighter",
    discipline = "warlord", -- deeper cut of the shelf: buyable only once the warlord gate is cleared
    price = 200,
    repRank = 3,
    activeAbility = {
        target = "self", -- struck where the drummer stands; the cadence reaches the tile around them
        speed = 4,
        support = true,
        cost = { stat = "stamina", amount = 8 },
        consumesItem = true,
        effect = function(fx)
            -- Everyone within a tile of the drummer, the drummer included -- they are beating the advance
            -- for themselves as much as for the rank beside them. Only allies take the morale; a foe caught
            -- in the same square hears a drum and nothing more.
            for _, u in ipairs(fx.unitsNear(fx.user.x, fx.user.y, 1)) do
                if u.side == fx.user.side then
                    fx.applyStatus(u, "status_inspiration")
                end
            end
        end,
    },
}
