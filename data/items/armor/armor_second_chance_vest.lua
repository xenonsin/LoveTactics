-- The Undercroft's entry armor, and the only one on the shelf anyone can walk in and buy.
--
-- Its whole extra is trait_dodge: one physical attack is simply missed, and then the reflex must
-- cool down before it can miss another. The rogue's answer to being hit is not to be thicker, it is to
-- not be there -- so this is the one defensive item in the catalog whose value does not scale with the
-- size of the blow. A greataxe and a dagger are both worth exactly one dodge, which makes it best
-- against the heaviest single thing on the board and nearly worthless against a swarm.
--
-- utility_duelists_reflex grants the same reflex from a charm. The trade is the slot: the charm costs
-- one of nine grid cells and gives no armour at all, this costs the armour slot and comes with a
-- (small) defense line under it. Wearing both is legal and does nothing twice -- a cooling reflex
-- is one reflex.
--
-- Cut leather rather than cloth, so no movement penalty: a rogue who is slower has already lost the
-- argument this vest is making.
local Curve = require("models.curve")

return {
    name = "Second-Chance Vest",
    description = "On a physical attack: deflect it, then go on cooldown.",
    flavor = "The Undercroft sells it to first-timers. Nobody there has ever called it generosity.",
    sprite = "assets/items/armor_second_chance_vest.png",
    type = "armor",
    tags = { "leather" },
    class = "rogue",
    price = 560,
    unlockQuests = 8,
    traits = { "trait_dodge" },
    bonus = { defense = Curve.ramp(3, 13), movement = -1 },
    resist = { physical = 1 },
}
