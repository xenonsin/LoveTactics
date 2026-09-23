-- Gallows Seed: planted by the Alraune, and every heal its host receives is drawn off to her.
--
-- THE TRAP'S THIRD FILE. The honey heals whoever stands in it (data/status/status_honeyed.lua), the
-- Mandrake holds them there (weapon_taproot), and the seed decides who that healing was for. A company
-- that walks into her ground with a seed in its anvil is feeding her, and so is its own priest.
--
-- WHOLE, AND THROUGH THE ONE FUNNEL. Combat.applyHeal sends the entire heal on to the planter through
-- itself, so everything that shapes a heal still shapes it on the way -- the planter's own wounds that
-- refuse healing refuse this too. The host gets nothing. The planter is stamped on this status as
-- `seeder` when it lands, and a seed whose planter has died feeds nobody (Status.healThief asks after
-- her): cut the one doing it and the seed is only a badge.
--
-- A DEBUFF, and the counterplay is exactly that: a Cure pulls it. It is the second place in the chain a
-- company can cut, beside the root.
return {
    name = "Gallows Seed",
    abbr = "Sd",
    description = "Every heal it receives goes to whoever planted the seed.",
    color = { 0.478, 0.365, 0.231 }, -- badge tint (seed husk)
    duration = 30,                -- about five turns: it outlasts a fight's worth of honey
    debuff = true,                -- Cure pulls it
    resistible = "magical",
    stealsHealing = true,         -- Status.healThief, read by Combat.applyHeal
    onApply = function(ctx)
        -- A re-seed keeps the first planter: a refresh extends the badge, it does not change whose it is.
        if ctx.status.seeder == nil then ctx.status.seeder = ctx.applier end
    end,
}
