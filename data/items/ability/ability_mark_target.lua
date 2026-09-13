-- Mark Target: paint a foe for the kill. Applies the Mark status (defense and magic defense cut), which
-- both softens it for the whole party and arms the hunter's Called Shot. No damage of its own -- it is
-- setup, not a strike. Requires an adjacent ranged weapon in the grid.
--
-- Its reach is the BEAST'S, not its own: `rangeFromAdjacent` hands it the longest range among the
-- ranged weapons beside it (Combat.borrowedRange), so a hand-bow marks three tiles out and a longbow
-- five. The mark is what a shot is aimed through, and a mark the hunter cannot then shoot is a wasted
-- turn -- tying the two makes the choice of bow decide both. The authored 3 below is the floor every
-- ranged weapon in the game clears (tests/tactics_ability_spec.lua holds that true), so the shelf
-- quoting it without a grid to read is never overstating the reach.
return {
    name = "Mark Target",
    description = "Inflicts Mark. Reaches as far as the ranged weapon beside it, which it needs.",
    flavor = "Setup, not a strike. The Lodge has never once confused the two.",
    sprite = "assets/items/ability_mark_target.png",
    type = "ability",
    tags = { "utility" },
    class = "hunter",
    price = 495,
    unlockQuests = 5,
    activeAbility = {
        target = "enemy",
        range = 3,
        rangeFromAdjacent = { type = "weapon", tag = "ranged" },
        requiresSight = true,
        speed = 3,
        cost = { stat = "stamina", amount = 4 },
        requiresAdjacent = { type = "weapon", tag = "ranged" },
        effect = function(fx)
            fx.applyStatus(fx.target, "status_mark")
        end,
    },
}
