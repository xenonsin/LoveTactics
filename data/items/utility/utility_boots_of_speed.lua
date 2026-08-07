-- A flat +1 to movement, folded into the wearer at battle setup exactly like a piece of armor's
-- bonus (Combat.applyPassives -> unit.bonus -> flatStat -> Combat.moveBudget), so it widens the
-- blue reachable set with no code of its own.
return {
    name = "Boots of Speed",
    description = "Grants bonus Movement.",
    flavor = "Every road needs a faster boot, and no guild ever managed to keep them to itself.",
    sprite = "assets/items/boots_of_speed.png",
    type = "utility",
    tags = { "boots" },
    -- The Undercroft's, along with every other boot in the catalog that buys a square: Feather Boots,
    -- Sidelong Greaves and the Zephyr Striders are all greed's, and this is the plain first rung of
    -- that ladder rather than a thing apart from it. Guile is mostly a question of being somewhere
    -- else by the time the blow lands, and the cheapest answer to that is a better boot.
    class = "rogue",
    unlockQuests = 0, -- opening shelf: the plainest rung of the Undercroft's movement ladder
    price = 80,
    -- Movement is a per-level table (levels 0..10): the boots carry more speed the higher they go.
    --                   level:  0  1  2  3  4  5  6  7  8  9  10
    bonus = { movement = { 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 3 } },
}
