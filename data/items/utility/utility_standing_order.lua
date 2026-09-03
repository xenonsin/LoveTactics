-- Wick's bound relic (Artificer). He builds the second half of his party during the fight, and this is
-- what he does with it.
--
-- THE UPGRADES STACK, which is the one place the repeatable-versus-once decision has teeth rather than
-- feel: pressed three times across a long fight, he ends it with three machines nothing on the board
-- can answer. So this is deliberately REPEATABLE, and the census re-locking whenever a construct falls
-- is the pressure that stops it being free.
--
-- THE CENSUS IS THREE STANDING. Emplace Sentry and Field Assembly are how it gets there; Salvage Rig
-- and Recall Construct recover the ones that drop, and both matter far more once the count is what he
-- is protecting -- an investment that compounds is an investment worth insuring.
--
-- Overcharge is the one-body version and stays worth buying: it hastens a single construct NOW, where
-- this makes all of them permanently harder to remove.
return {
    name = "The Standing Order",
    description = "Grants Giant's Vigour and Empowered to every construct you field, and heals them. Stacks.",
    flavor = "He does not repair them. He revises them, which is a different relationship.",
    sprite = "assets/items/sig_standing_order.png",
    type = "utility",
    tags = { "signature", "artifice" },
    class = "artificer",
    activeAbility = {
        target = "self",
        range = 0,
        speed = 5,
        cost = { stat = "mana", amount = 12 },
        description = "Upgrades every construct standing: more damage, health and defense. Stacks.",
        unlock = {
            field = { of = "unit", summoned = true, count = 3 },
            text = "3 constructs standing",
        },
        effect = function(fx)
            for _, u in ipairs((fx.combat and fx.combat.units) or {}) do
                if u.alive and u.summoner == fx.user then
                    -- Giant's Vigour raises the body, Empowered the blow. Both stack by re-application
                    -- rather than by a bespoke counter, which is what makes "press it again" mean
                    -- something without a second bookkeeping system to keep in step.
                    fx.applyStatus(u, "status_giants_vigour")
                    fx.applyStatus(u, "status_empowered", { magnitude = 5 })
                    fx.heal(u, (fx.amount or 0) + 8)
                end
            end
        end,
    },
    -- an order that arms everything you built
    bonus = { magicDamage = 1 },
}
