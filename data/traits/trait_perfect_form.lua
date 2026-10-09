-- PERFECT FORM: the elf duelist's race item (data/items/utility/utility_perfect_form.lua, "The Rift's
-- Adventurers", slice D). While the bearer is still Unblemished, every blow on the same foe moves its stance
-- two steps rather than one: the same-target streak every Tempo pool and the Long Bout read
-- (Combat.dealDamage), and En Garde's own stack (models/race_items.lua, `streakStep`).
return {
    name = "Perfect Form",
    description = "While Unblemished, your stance builds twice as fast.",
    perfectForm = true,
}
