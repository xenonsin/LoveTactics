-- Quest-only: `class` with no `price` (docs/classes.md).
--
-- Sacred Ground that walks. `incense` lifts last beat's square and lays a new one around the wearer
-- (Combat.layIncense), and hazard_sacred Blesses every ALLY standing in it -- raised Damage and Magic
-- Damage (status_blessing), for as long as they stand there.
--
-- The censer family's mechanic, cut as a garment. Which is not a borrow: docs/classes.md gives the
-- censer to the Cathedral alone, so this is the one shelf that could ever have made a wearable one,
-- and it says something the swung version cannot -- a censer occupies the weapon a priest was going to
-- fight with, and the habit occupies armour they were never going to have anyway.
--
-- Note what the hazard does NOT do: it skips the owner (see hazard_sacred), so the wearer stands in
-- the middle of a blessing they do not get. The habit is worth exactly the number of allies willing to
-- crowd the priest, which is the same positional argument the Oathkeeper makes from the other shelf.
--
-- Cloth, so it costs a square of pace -- and the whole point of it is to be standing where the line is.
local Curve = require("models.curve")

return {
    name = "Censer-Cloth Habit",
    description = "Grants Blessing to adjacent allies.",
    flavor = "Woven from the strips they wrap a censer's chain in, once the chain has been retired.",
    sprite = "assets/items/armor_censer_cloth_habit.png",
    type = "armor",
    tags = { "cloth", "holy" },
    class = "priest",
    dropTier = 5,
    incense = { hazard = "hazard_sacred", radius = 1 },
    bonus = { magicDefense = Curve.ramp(3, 13), defense = Curve.ramp(2, 12), movement = -1 },
}
