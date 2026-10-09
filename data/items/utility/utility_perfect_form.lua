-- PERFECT FORM: the elf duelist's race item ("The Rift's Adventurers", slice D, approved 2026-10-09). While the
-- bearer is Unblemished, each blow on the same foe moves its stance two steps: the same-target streak the
-- duelist's Tempo and the Long Bout read, and En Garde's own stack (trait_perfect_form, models/race_items.lua).
--
-- Gated to elves (Character.canCarry). No price: a rift find on the duelist's shelf at the class's floor.
return {
    name = "Perfect Form",
    description = "While Unblemished, your stance builds twice as fast.",
    flavor = "The form was taught to it once, centuries ago, and it has not had a reason to adjust it since.",
    sprite = "assets/items/utility_perfect_form.png",
    type = "utility",
    tags = { "charm" },
    class = "duelist",
    race = "elf",
    unlockLevel = 10,
    traits = { "trait_perfect_form" },
}
