-- The caster's order, and the single most quest-shaped thing on the menu.
--
-- Mana does not regenerate. It carries, spent, from the first node of a run to the last, so a party
-- with two casters is not really limited by its mana POOL -- it is limited by the fact that the pool is
-- the same one all afternoon. The Bottomless Pot answers that at every bell rather than once
-- (data/traits/trait_meal_bottomless_pot.lua), which is why this is worth more than its courses look.
--
-- HONESTLY A BAD ORDER FOR SOME COMPANIES, and the description says so rather than burying it: a party
-- of fighters buys a small magic-damage bump and a ceiling nobody fills. That is the platter doing its
-- job. A menu where every dish is correct for every company is a menu with one dish on it.
return {
    name = "Black Tea and Cardamom",
    description = "Deepens the company's magic, and hands mana back at the start of every battle.",
    flavor = "The cardamom is the point. She says the tea is only there to carry it up the hill.",
    price = 130,
    unlockPrestige = 3,
    bonus = { magicDamage = 2 },
    maxBonus = { mana = 10 },
    skill = "trait_meal_bottomless_pot",
}
