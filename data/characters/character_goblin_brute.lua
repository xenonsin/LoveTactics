-- THE GOBLIN BRUTE, rung 2: bottles up every hit, and bursts when it dies (approved 2026-09-26, "The Goblins of
-- Wrath", pitched after Keno's note that a trigger may repeat on a floor "if the payoff is unique").
--
-- Every hit it takes adds Seething -- Ira's trigger -- and the payoff is its own: dead, it bursts into fire on
-- every tile beside it, harder for each stack (Pent Up, utility_pent_up). From three stacks it wears Primed. So
-- chipping at it makes it both stronger and a bomb: kill it in one blow, from range, or among its own.
--
-- It drops Bottled Rage, the burst put under the bearer's control. A barbarian on the fighter table.
return {
    name = "Goblin Brute",
    race = "goblin",
    tier = 2,
    class = "fighter",
    discipline = "barbarian",
    sprite = "assets/chars/goblin_brute.png",
    archetype = "aggressive",
    stats = {
        health = 64, mana = 0, stamina = 20,
        staminaRegen = 3,
        damage = 11, magicDamage = 0,
        defense = 3, magicDefense = 2,
        movement = 4,
        speed = 3,
        skill = 5, luck = 3,
    },
    startingItems = {
        "weapon_iron_hammer", "utility_pent_up", "ability_bottled_rage",
        false,                false,             false,
        false,                false,             false,
    },
    drops = { "ability_bottled_rage" },
    defaultAction = "weapon_iron_hammer",
    signatureWeapon = "weapon_iron_hammer",
}
