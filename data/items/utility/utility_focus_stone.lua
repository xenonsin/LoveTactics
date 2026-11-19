-- Static Focus: the mage's Storm Vessel scaler (docs/engines.md). Each Storm spent -- on a spell beside
-- the vessel or on an Outpour -- adds 1 magic damage for the rest of the fight (trait_static_focus).
--
-- Reworked from the Focus Stone (2026-11-18), whose text was the staff's Wait-to-Focus word for word. The
-- staff keeps that bargain. "Static" stays because it is already the game's lightning word.
return {
    name = "Static Focus",
    description = "Each Storm you consume raises your magic damage by 1 for the rest of the fight.",
    flavor = "It holds a charge the way a cat holds a grudge.",
    sprite = "assets/items/focus_stone.png",
    type = "utility",
    tags = { "arcane" },
    class = "mage",
    unlockLevel = 11,
    traits = { "trait_static_focus" },
    bonus = { magicDamage = 1 },
}
