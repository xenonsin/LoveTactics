-- The Warren's entry armor, and the only one on the hunter's shelf anyone can walk in and buy.
--
-- trait_keen_senses: the wearer feels the attack coming and strikes FIRST, for a swing's stamina --
-- and if that pre-emption kills, the blow never lands at all. The hunter's whole grammar, worn:
-- everything on this shelf is setup then payoff, and the pelt moves the payoff in front of the setup.
--
-- It is the only defensive item in the catalog that can produce a turn in which the wearer takes no
-- damage AND the attacker is dead, which is why it is priced at the shelf's second rung rather than
-- its first. Against anything it cannot one-shot it is simply a counter that goes early, and the
-- stamina bill escalates per answer (Trait.answerCost) exactly as every other reflex's does.
--
-- ability_keen_senses carries the same rule as a grid ability. Same trade as the rogue's vest: the
-- ability spends a cell and nothing else, the pelt spends the armour slot and brings a hide with it.
local Curve = require("models.curve")

return {
    name = "Stalker's Pelt",
    description = "On being attacked: strike first; a kill stops the blow before it lands.",
    flavor = "The Warren skins what it teaches you to hear coming. The lesson and the coat are the same animal.",
    sprite = "assets/items/armor_stalkers_pelt.png",
    type = "armor",
    tags = { "hide" },
    class = "hunter",
    discipline = "druid", -- deeper cut of the shelf: buyable only once the druid gate is cleared
    price = 290,
    unlockQuests = 4,
    traits = { "trait_keen_senses" },
    bonus = { defense = Curve.ramp(4, 14), movement = -1 },
    resist = { physical = 1 },
}
