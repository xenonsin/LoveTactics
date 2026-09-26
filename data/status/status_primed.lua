-- PRIMED: a Goblin Brute that has taken enough to burst (data/traits/trait_pent_up.lua). The badge is the
-- telegraph: kill it now and everything beside it burns. It lasts as long as the Brute does.
return {
    name = "Primed",
    abbr = "Prim",
    description = "Bursts into fire when it dies, harming everything beside it.",
    color = { 0.930, 0.450, 0.160 }, -- badge tint (fuse-spark)
    duration = math.huge,
    hideDuration = true,
}
