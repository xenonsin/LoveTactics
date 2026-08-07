-- Stripped Plate: the rogue half of the Vanguard (knight x rogue). Armour you break off somebody else,
-- you keep -- a permanent lift to your own defense for every body you Sunder.
--
-- The discipline in one object. A knight opens the line; a rogue helps itself to what came off it. That
-- is what knight x rogue is FOR, and it is why this sits on the Undercroft's shelf rather than the
-- Bastion's: the breach is the knight's idea, the profit is greed's.
--
-- It pairs with Breaker's Wedge by design and neither needs the other. The Wedge makes Sunder common
-- (every shove in the game); this makes each one worth something after the fact. A Vanguard carrying
-- only this still collects on Shieldbreak and Pry Open, which the shelf already sells.
--
-- It replaced a blink -- an ability that teleported behind a Sundered foe -- turned down for a reason
-- worth keeping: the Vanguard's whole idea is opening a line by force, and a discipline that can simply
-- appear on the far side of it has no use for the breach it just made.
return {
    name = "Stripped Plate",
    description = "Every foe you Sunder leaves armour behind; you wear it this battle.",
    flavor = "Plate is expensive. Someone was always going to pick it up, and he was always going to be closest.",
    sprite = "assets/items/utility_stripped_plate.png",
    type = "utility",
    tags = { "charm" },
    class = "rogue",
    discipline = "vanguard",
    price = 320,
    unlockQuests = 4,
    traits = { "trait_stripped_plate" },
}
