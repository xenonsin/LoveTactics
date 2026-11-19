-- Censer Chain: the priest's Overflow grid piece (docs/engines.md). A heal cast from an item beside it
-- also lands on everyone standing next to the patient, for half (`healSplash`, applied by the cast's
-- fx.heal). More bodies healed is more bodies healed past full, and so more Radiance banked.
--
-- Quest-only: `class` with no `price` (docs/classes.md).
--
-- Reworked from the Censer-Cloth Habit (2026-11-18), which walked Sacred Ground about with its wearer --
-- the Censer weapon's own verb. It stays a vestment. The Censer itself is untouched.
local Curve = require("models.curve")

return {
    name = "Censer Chain",
    description = "Heals from items next to it also heal everyone next to the target for half.",
    flavor = "Woven from the strips they wrap a censer's chain in, once the chain has been retired.",
    sprite = "assets/items/armor_censer_cloth_habit.png",
    type = "armor",
    tags = { "cloth", "holy" },
    class = "priest",
    unlockLevel = 12,
    aura = {
        appliesTo = { "ability", "weapon", "consumable" },
        healSplash = 0.5,
    },
    bonus = { magicDefense = Curve.ramp(3, 13), defense = Curve.ramp(2, 12), movement = -1 },
}
