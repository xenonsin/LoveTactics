-- Vow-Marked Plate: the knight half of the Paladin (knight x priest). Every affliction the wearer bears
-- hardens them, and every comrade who falls closes a ward over the gap.
--
-- The item that makes Lay On Hands a decision instead of a charity. Taking an ally's poison onto
-- yourself moves a problem and pays for the privilege -- unless the body doing the taking is built to
-- be carrying things. Here the paladin's own affliction list is its armour: a plate covered in the
-- marks of everything it has agreed to bear.
--
-- It never asks where a debuff came from. An enemy's poison hardens it exactly as much as one it took
-- off a friend, which keeps the vow a vow rather than a trick with a setup. And the bonus is permanent
-- for the battle rather than while-carried, because what hardens a paladin is having BORNE the thing --
-- a stat that lapsed the moment somebody cast Cure would punish the party for tending to them.
--
-- Heavy plate, paying the tier (-2 movement, docs/classes.md) and paying nothing back.
local Curve = require("models.curve")

return {
    name = "Vow-Marked Plate",
    description = "Every debuff you take hardens you for the battle. When an ally falls, a ward closes over you.",
    flavor = "The marks are not damage. The armourer files them in deliberately, one for each promise.",
    sprite = "assets/items/armor_vow_marked_plate.png",
    type = "armor",
    tags = { "heavy", "holy" },
    class = "knight",
    discipline = "paladin",
    price = 475,
    unlockQuests = 3,
    bonus = { defense = Curve.ramp(6, 16), movement = -2 },
    traits = { "trait_vow_marked" },
}
