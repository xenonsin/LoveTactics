-- Quest reward, slot 6 of the Bastion's line (data/quests/muster.lua). A ration of the order's own
-- billet steel, handed out at the muster tent with the season's oath -- the same tent whose queue
-- gets shorter every year Acedia walks the Watch.
--
-- A CONSUMABLE rather than a charm because a ration is one: it is issued, it is carried, it is spent.
-- (It was once a consumable for a mechanical reason too -- slot 6 used to be `repeatable`, so the
-- payout landed on every completion and had to stack rather than mint a grid passive over and over.
-- Nothing is repeatable any longer; the fiction was the better half of the argument and it stands.)
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
