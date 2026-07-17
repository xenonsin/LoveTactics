-- Swap: trade tiles with a foe within reach (Combat.swapUnits). A rogue's escape and disruption tool
-- both -- yank a fragile backline enemy into the party's teeth, or trade places with a distant foe to
-- slip a corner. Both units spring whatever waits on the tile they land on, so swapping onto a trap is
-- as real as walking onto one.
return {
    name = "Swap",
    description = "Trades places with a foe within range. Both spring whatever waits on the tile.",
    flavor = "An escape and a disruption at once, and the Undercroft charges for only one of them.",
    sprite = "assets/items/ability_swap.png",
    type = "ability",
    tags = { "guile", "utility" },
    class = "rogue",
    price = 160,
    repRank = 1,
    activeAbility = {
        target = "enemy",
        range = 3,
        requiresSight = true,
        speed = 3,
        cost = { stat = "stamina", amount = 4 },
        effect = function(fx)
            fx.swap(fx.target)
        end,
    },
}
