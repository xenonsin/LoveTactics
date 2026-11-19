-- PRIMED: a Goblin Brute, which opens every fight ready to burst (data/traits/trait_pent_up.lua; worn from the
-- start since 2026-11-19, when the charge stopped counting blows). The badge is the telegraph: kill it and
-- everything beside it burns. It lasts as long as the Brute does.
return {
    name = "Primed",
    abbr = "Prim",
    description = "Bursts into fire when it dies, harming everything beside it.",
    color = { 0.930, 0.450, 0.160 }, -- badge tint (fuse-spark)
    duration = math.huge,
    hideDuration = true,
}
