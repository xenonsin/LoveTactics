-- Arcanum rank-4, and the Silk Robes' real successor: a single-target spell aimed at the wearer is
-- unravelled entirely, for mana (trait_counter_magic).
--
-- The distinction from every other magic defense in the catalog is that this one is not mitigation at
-- all. Runed Plate and the Skeptic's Harness make a spell land for less; this makes it not land. A
-- Fireball aimed at the wearer costs the enemy their entire turn and costs the wearer some mana, which
-- is the best exchange rate in the game and is priced accordingly -- both in gold and in the pool.
--
-- Paid from MANA, which is the whole of the balance and the reason it belongs to pride rather than to
-- the Bastion. The mage's own casting and the mage's own defense draw on the same bar, so every spell
-- turned aside is a spell not cast, and a mirrorsilk wearer who spends the fight countering has
-- successfully defended themselves into irrelevance. Pride's item is one that punishes you for using
-- it on anything less than a spell worth your turn.
--
-- Single-target only, and deliberately: an AoE goes straight through, so the Arcanum's counter to the
-- Arcanum is to stop aiming. utility_counter_magic is the charm form, for a grid with a cell spare.
--
-- Cloth: a square of pace, as all silk now is.
return {
    name = "Mirrorsilk",
    description = "A single-target spell aimed at you is unravelled entirely, for mana.",
    flavor = "The Arcanum weaves it on a loom that must be watched. Nobody has explained what happens if it is not.",
    sprite = "assets/items/armor_mirrorsilk.png",
    type = "armor",
    tags = { "cloth", "arcane" },
    class = "mage",
    price = 560,
    repRank = 4,
    traits = { "trait_counter_magic" },
    bonus = { magicDefense = { 6, 7, 7, 8, 9, 9, 10, 11, 11, 12, 13 }, movement = -1 },
    resist = { magical = { 3, 3, 4, 4, 4, 5, 5, 5, 5, 6, 6 } },
}
