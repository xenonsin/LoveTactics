-- Undercroft rank-4. Fast and vicious: it costs almost nothing to swing, so it swings often. The
-- Undercroft never says whose blood named it, only what the name is worth.
--
-- It is sold, resold, and stolen back. The guild takes a cut each time -- the first hint of Greed,
-- whose general lifts the kit out of your hands mid-fight.
return {
    name = "Kingsblood Dagger",
    description = "A slender blade that has changed hands more often than it has been cleaned.",
    sprite = "assets/items/kingsblood_dagger.png",
    type = "weapon",
    tags = { "dagger", "pierce", "physical" },
    class = "rogue",
    price = 800,
    repRank = 4,
    stealPriority = 2, -- a thief covets it above ordinary kit (below a Decoy's bait)
    activeAbility = {
        name = "Slip",
        target = "enemy",
        range = 1,
        speed = 1, -- the fastest strike in the game: you act again almost at once
        cost = { stat = "stamina", amount = 4 },
        power = 9,
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
