-- A flat +1 to movement, folded into the wearer at battle setup exactly like a piece of armor's
-- bonus (Combat.applyPassives -> unit.bonus -> flatStat -> Combat.moveBudget), so it widens the
-- blue reachable set with no code of its own.
return {
    name = "Boots of Speed",
    description = "Light on the feet: move one extra space each turn.",
    sprite = "assets/items/boots_of_speed.png",
    type = "utility",
    tags = { "boots" },
    class = "rogue",
    price = 200,
    repRank = 2,
    -- Movement is a per-level table (levels 0..10): the boots carry more speed the higher they go.
    --                   level:  0  1  2  3  4  5  6  7  8  9  10
    bonus = { movement = { 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 3 } },
}
