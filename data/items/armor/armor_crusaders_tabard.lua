-- Crusader's Tabard: the Crusader (fighter x priest) declaring its pool. Zeal banks on KILLS and on
-- HEALS -- the discipline's two halves, either one of them -- and the tabard turns what is banked into
-- the thing a crusade actually runs on: every kill heals the wearer, harder the more Zeal is standing
-- behind it.
--
-- The `from` list is rule R2 made concrete (docs/classes.md). The first draft of this shelf banked Zeal
-- off a particular holy hammer, which meant the discipline's mechanic was really a weapon's mechanic and
-- a Crusader who spent the fight healing arrived at the payoff with nothing. A pool that fills from
-- "kill" OR "healDone" belongs to the discipline instead: the field medic and the executioner reach the
-- same place by opposite roads, which is the only reading of fighter x priest worth having.
--
-- Medium armour, so it pays the tier (-1 movement, docs/classes.md) and never pays it back: no armour in
-- the game grants a square, and this one is where the rule was first written down.
local Curve = require("models.curve")

return {
    name = "Crusader's Tabard",
    description = "On kill: heal, more for the Zeal held. Banks Zeal on every kill and heal.",
    flavor = "Two hands' work, the same colours on both. One of them closes wounds and one of them opens them.",
    sprite = "assets/items/armor_crusaders_tabard.png",
    type = "armor",
    tags = { "medium", "holy" },
    class = "crusader",
    price = 410,
    unlockQuests = 4,
    charge = { key = "zeal", from = { "kill", "healDone" }, max = 8 },
    bonus = { defense = Curve.ramp(4, 14), movement = -1 },
    traits = { "trait_zealots_mercy" },
}
