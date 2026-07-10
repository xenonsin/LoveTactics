-- Lift an item off an adjacent foe. Combat.steal picks it: never something the blueprint marks
-- `noSteal` (you cannot take a wolf's fangs off it), and always the highest `stealPriority` first --
-- which is exactly how a Decoy tricks a thief into grabbing the bait.
--
-- The item goes into the thief's own 3x3 grid. If that grid is full, it goes to the player's stash
-- instead (unbounded), so a successful theft is never wasted.
return {
    name = "Pickpocket",
    description = "Steal an item from an adjacent foe. If your grid is full, it goes to your stash.",
    sprite = "assets/items/ability_pickpocket.png",
    type = "ability",
    tags = { "thievery", "utility" },
    class = "rogue",
    price = 95,
    repRank = 1,
    activeAbility = {
        name = "Pickpocket",
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 6 },
        effect = function(fx)
            fx.steal(fx.target)
        end,
    },
}
