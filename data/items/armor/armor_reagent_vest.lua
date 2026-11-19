-- The Reagent Vest: the alchemist's Reactions grid piece (docs/engines.md). Every status laid by an item
-- sitting next to it lasts a turn longer (`statusTicks`, a turn's worth of ticks added in the cast's
-- fx.applyStatus and on a coating's hit). A longer window between the setup and the payoff is the whole
-- of what a reaction needs: Oiled, Chilled and Wet all wait for somebody else to spend them.
--
-- Reworked 2026-11-18 from a vest that raised adjacent consumables' magnitude and lent them the poison
-- tag, which was Alchemic Mastery worn as armour. It stays armour.
local Curve = require("models.curve")

return {
    name = "The Reagent Vest",
    description = "Statuses from items next to it last 1 turn longer.",
    flavor = "The Crucible issues it to the ones who stopped asking what a thing does and started asking what it does next.",
    sprite = "assets/items/armor_reagent_vest.png",
    type = "armor",
    tags = { "leather" },
    class = "alchemist",
    unlockLevel = 9,
    aura = {
        appliesTo = { "consumable", "ability", "weapon" },
        statusTicks = 5, -- one turn (Status.TICKS_PER_TURN)
    },
    bonus = { defense = Curve.ramp(2, 12), movement = -1 },
}
