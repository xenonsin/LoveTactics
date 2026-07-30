-- Shakedown: the Thief discipline's signature Larceny, all of it in one motion. The blow lands, an item
-- comes off the target and into your grid (Combat.steal, exactly as Pickpocket does it -- never a `noSteal`
-- relic, highest `stealPriority` first, into the stash when the grid is full), and the party is promised a
-- little coin on top (fx.bounty). Item AND purse in the same swing, which is what makes it the marquee of
-- the shelf rather than a costlier Pickpocket: greed does not take one thing when it can take two.
--
-- Priced and gated as the deep cut it is (rank 4). Where Pickpocket is the Undercroft's entrance exam --
-- range 1, a handful of stamina, the thing in their hand -- this is the graduation: it hurts them, robs
-- them, and bills them. Against a target carrying nothing stealable the theft simply comes up empty (steal
-- returns nil) and the blow and the bounty still land, so it is never a wasted turn, only a smaller haul.
return {
    name = "Shakedown",
    description = "Steals an item and gold from a foe.",
    flavor = "Everything a man owns is only his until someone decides otherwise. The Undercroft decides constantly.",
    sprite = "assets/items/ability_shakedown.png",
    type = "ability",
    tags = { "thievery", "guile", "utility" },
    class = "rogue",
    discipline = "thief", -- deeper cut of the shelf: buyable only once the thief gate is cleared
    price = 380,
    unlockQuests = 10,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 5,
        cost = { stat = "stamina", amount = 10 },
        damage = { 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 },
        effect = function(fx)
            fx.damage(fx.target)
            fx.steal(fx.target)      -- lift a carried item into the grid (or the stash, if it is full)
            fx.bounty(15)            -- and shake the purse: coin paid out with the spoils on a win
        end,
    },
}
