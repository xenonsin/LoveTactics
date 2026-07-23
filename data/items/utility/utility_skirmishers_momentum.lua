-- Skirmisher's Momentum: the hunter half of the Skirmisher (fighter x hunter), and a PASSIVE -- a reflex
-- on a grid charm (docs/classes.md). The first blow struck after moving lands harder
-- (trait_skirmishers_momentum, read through the damageBonusVs hook), so a fighter who keeps moving keeps
-- hitting harder, and one who plants and trades gives the bonus up. Hit-and-run made a standing rule --
-- the reward for never being where you were.
return {
    name = "Skirmisher's Momentum",
    description = "Your first strike after moving deals extra damage. Stand still and it gives nothing.",
    flavor = "The Lodge's outriders have a saying: the arrow that matters is the one loosed at a gallop.",
    sprite = "assets/items/utility_skirmishers_momentum.png",
    type = "utility",
    tags = { "charm" },
    class = "hunter",
    discipline = "skirmisher", -- fighter x hunter; the Hit-and-run mechanic's first stock
    price = 380,
    repRank = 3,
    traits = { "trait_skirmishers_momentum" },
}
