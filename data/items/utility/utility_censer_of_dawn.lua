-- Cathedral rank-4. A passive aura, in the shape of data/items/consumable/consumable_fire_stone.lua: it sanctifies
-- the weapons and abilities adjacent to it in the 3x3 grid, lending them the holy tag. Kit that
-- already channels shadow refuses the blessing.
--
-- The Cathedral insists the censer purifies. It is never explained why it must be carried at all
-- times, nor what the smoke keeps at arm's length -- the first hint of Lust, whose general takes
-- what is not offered.
return {
    name = "Censer of Dawn",
    description = "Adjacent weapons and abilities strike as holy. Shadow kit refuses it.",
    flavor = "The Cathedral insists it purifies. It never explains why it must be carried at all times, nor what the smoke keeps at arm's length.",
    sprite = "assets/items/censer_of_dawn.png",
    type = "utility",
    tags = { "holy" },
    class = "priest",
    price = 800,
    repRank = 4,
    aura = {
        appliesTo = { "weapon", "ability" },
        exceptTags = { "shadow" },
        grantTags = { "holy" },
    },
}
