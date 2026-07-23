-- The Pale Vesture: a thin grey robe that makes its wearer thin as well. Steel barely finds them --
-- and everything else finds them far too easily (data/status/status_hollowed.lua).
--
-- A TRADE RATHER THAN A BUFF, and the only item on the shelf whose downside can kill you faster than
-- its upside saves you. Physical blows land for the floor of 1; magic bites for a great deal more than
-- it would have. So going hollow is a sentence with two halves, and the second half is decided
-- entirely by what the enemy line has in it.
--
--   * Against a fighting line it is an ESCAPE. A knight surrounded by three swords walks out through
--     them taking three points, and nobody can do anything about it.
--   * Against a casting line it is a way of dying faster than you otherwise would have, and the
--     tooltip is honest about the number.
--
-- Which makes it the rare item whose correct use is decided at the START of a battle, by looking at
-- the enemy, rather than at the shop by looking at a stat. That is a kind of decision this catalog is
-- short of.
--
-- The defense is a big number rather than an immunity flag, and the status's own comment explains why
-- at length: damage in this game floors at 1 and never at 0, and that floor is load-bearing -- a
-- scratch still provokes counters, still feeds Rimebitten, still wakes a sleeper, still advances a
-- boss phase. Rendering it as armour rather than as immunity means none of those rules needed a new
-- case, and it reads at the table as exactly what the player wanted to buy.
return {
    name = "The Pale Vesture",
    description = "Turns its wearer thin: physical blows barely land, and magic bites far deeper.",
    flavor = "Worn once by a man who walked out of a siege. He is not recorded as having survived the walk.",
    sprite = "assets/items/utility_pale_vesture.png",
    type = "utility",
    tags = { "arcane" },
    class = "mage",
    price = 340,
    repRank = 3,
    activeAbility = {
        target = "self",
        range = 0,
        speed = 2, -- fast: it answers a melee that has already closed, and a slow one answers nothing
        cost = { stat = "mana", amount = 10 },
        support = true,
        effect = function(fx)
            fx.applyStatus(fx.user, "status_hollowed", { duration = 10 + fx.level })
        end,
    },
}
