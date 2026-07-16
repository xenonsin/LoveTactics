-- The charm that carries Counter Magic (data/traits/counter_magic.lua): a single-target spell aimed at
-- the wearer is unravelled outright, for mana and a cooldown.
--
-- A passive utility whose whole effect is the trait it grants, exactly like the Duelist's Reflex or the
-- Reprisal Quiver -- the reflex is the item. Sold by the mage's vendor because it is spellcraft, and
-- because the mana price means the people who can actually run it are the people who have a mana bar:
-- put it on a knight and it fires twice a battle and then is a brooch. That is a real build decision
-- rather than an accident -- a knight who wants the same job wants a Magical Barrier, which costs a
-- priest's turn instead of its own pool.
return {
    name = "Unraveller's Sigil",
    description = "A single-target spell aimed at you is unravelled entirely -- for mana, then it recharges.",
    sprite = "assets/items/counter_magic.png",
    type = "utility",
    tags = { "arcane" },
    class = "mage",
    price = 400,
    repRank = 3,
    traits = { "counter_magic" },
}
