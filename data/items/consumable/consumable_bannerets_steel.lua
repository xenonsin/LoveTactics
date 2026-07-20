-- Quest reward, slot 6 of the Bastion's line (data/quests/muster.lua). A ration of the order's own
-- billet steel, handed out at the muster tent with the season's oath -- the same tent whose queue
-- gets shorter every year Acedia walks the Watch.
--
-- Slot 6 is `repeatable`, which is why this is a CONSUMABLE and not a charm: the payout lands on
-- every completion (models/quest.lua's double-payout guard only blocks non-repeatables), so it has
-- to be something that stacks in the stash rather than a grid passive minted over and over.
--
-- `class = "knight"` with NO `price`: unbuyable, and still tallying toward knight growth when it is
-- used (docs/classes.md, "class without price").
return {
    name = "Banneret's Steel",
    description = "Inspires an ally, raising their Damage and Defense.",
    flavor = "Issued at the muster tent with the season's oath. They cast the same number every " ..
        "year and have stopped running out.",
    sprite = "assets/items/bannerets_steel.png",
    type = "consumable",
    tags = { "charm" },
    class = "knight",
    activeAbility = {
        target = "ally", -- includes the user (a unit is its own ally)
        support = true,
        range = 1,
        speed = 3,
        consumesItem = true,
        effect = function(fx)
            fx.applyStatus(fx.target, "status_inspiration")
        end,
    },
}
