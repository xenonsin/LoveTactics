-- Rime Draught: the alchemist's Reactions setup for plate (docs/engines.md). Thrown at a foe, it leaves
-- them Chilled (status_chilled), which does nothing on its own. A hammer or an axe blow on a chilled body
-- shatters its armour to nothing for two turns (Engine.afterWound). An answer to plate that is not raw
-- damage: the alchemist lays it, and the knight or the barbarian beside her spends it.
--
-- Reworked from the Elixir of the Giant (2026-11-18), one of three interchangeable stat elixirs. The id
-- stays so saves and drop lists keep their piece; the adventurer alchemist's kit drinks another elixir.
return {
    name = "Rime Draught",
    description = "Inflicts Chilled. A hammer or axe blow on a Chilled foe drops its defense to 0 for 2 turns.",
    flavor = "Do not drink it. The label says so twice, and the second time it is underlined.",
    sprite = "assets/items/consumable_elixir_of_the_giant.png",
    type = "consumable",
    tags = { "ice" }, -- no "magical": the cold is chemistry
    class = "alchemist",
    price = 140,
    unlockLevel = 6,
    activeAbility = {
        target = "enemy",
        range = 3,
        requiresSight = true,
        speed = 3,
        cost = { stat = "stamina", amount = 4 },
        consumesItem = true,
        effect = function(fx)
            fx.applyStatus(fx.target, "status_chilled")
        end,
    },
}
