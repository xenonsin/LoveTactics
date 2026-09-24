-- KEPT SUITORS: one of the Velvet Queen's own (data/characters/character_velvet_queen.lua). She wore
-- everybody's clothes; this wears your admirers' -- while a foe is Charmed by you, its armour's Defense
-- is added to yours (trait_kept_suitors). It asks the company to bring a charm to use it, which is
-- Lust's own verb.
--
-- `unstocked`: visible on the Cathedral's rack and never sold (docs/drops.md).
return {
    name = "Kept Suitors",
    description = "While a foe is Charmed by you, add its armour's Defense to your own.",
    flavor = "They would give you the coats off their backs. So you let them.",
    sprite = "assets/items/utility_kept_suitors.png",
    type = "utility",
    tags = { "protective" },
    class = "priest",
    unlockLevel = 4,
    unstocked = true,
    traits = { "trait_kept_suitors" },
}
