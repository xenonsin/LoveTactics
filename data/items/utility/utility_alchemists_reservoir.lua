-- The flask-harness that carries the Alchemist's Reservoir (data/traits/alchemists_reservoir.lua): a
-- spell that outruns its caster's mana is paid for out of a Mana Potion instead.
--
-- Sold by the alchemist rather than the mage, deliberately: it is not a way of having more magic, it
-- is a way of having more SUPPLIES, and it is bought by the player who would rather solve a mana
-- problem at the shop than at the character sheet. Like the bandolier it shares a shelf with, it is
-- inert without stock -- and, like it, that is the whole build.
return {
    name = "Reagent Harness",
    description = "A spell beyond your mana is paid for out of a Mana Potion instead.",
    flavor = "Not a way of having more magic. A way of having more supplies.",
    sprite = "assets/items/alchemists_reservoir.png",
    type = "utility",
    tags = { "satchel", "arcane" },
    class = "alchemist",
    price = 300,
    repRank = 2,
    traits = { "trait_alchemists_reservoir" },
}
