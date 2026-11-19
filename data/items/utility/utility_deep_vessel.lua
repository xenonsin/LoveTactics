-- Deep Vessel: the mage's Storm Vessel multiplier (docs/engines.md). Beside a Storm Vessel it lets the
-- storm pool hold five instead of three (`deepens`, read by Combat.chargeDef off the vessel's
-- neighbours); anywhere else it holds nothing. Two more turns of patience, and a spell beside the vessel lands at three and a half times.
--
-- Named in round 3 to follow the vessel (the working name was Leyden Jar).
return {
    name = "Deep Vessel",
    description = "A Storm Vessel next to it holds up to 5 Storm.",
    flavor = "Older than the vessel it is set beside, and it has never once been full.",
    sprite = "assets/items/utility_deep_vessel.png",
    type = "utility",
    tags = { "arcane" },
    class = "mage",
    unlockLevel = 9,
    deepens = { key = "storm", max = 5, id = "utility_resonance_prism" },
    bonus = { magicDefense = 1 },
}
