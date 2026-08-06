-- Crucible rank-2. Passive armor: a lead-lined coat the alchemists wear over everything else, because
-- what they work with does not care how brave you are. Poor against a blade, excellent against fire
-- and lightning -- the inverse of the Bastion's steel, and the reason a caster-heavy party buys here.
--
-- Lead is heavy. The movement penalty is the price of the resists.
local Curve = require("models.curve")

return {
    name = "Leaden Ward",
    description = "Drinks fire and lightning; does little against a blade.",
    flavor = "The alchemists wear it over everything else. What they work with does not care how brave you are.",
    sprite = "assets/items/leaden_ward.png",
    type = "armor",
    class = "alchemist",
    price = 240,
    unlockQuests = 6,
    bonus = { magicDefense = Curve.ramp(4, 14), defense = Curve.ramp(2, 12), movement = -1 },
    resist = { fire = 5, lightning = 5, magical = 2 },
}
