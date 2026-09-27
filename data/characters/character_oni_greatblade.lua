-- THE ONI GREATBLADE, rung 1 (approved 2026-09-26, "The Oni of Wrath", round 1), after Reincarnated as a Slime's
-- retainer who is stronger than any plan.
--
-- UNMOVED: no Stun, Cripple or Torpid lands on her, and nothing shoves, pulls or throws her (utility_unmoved). Her
-- Odachi winds up and falls down a line of three, and a miss is rolled again once. Every control effect the company
-- brought is wasted on her, so the fight is a damage race around a body that cannot be put off.
--
-- She drops the Odachi and the Questionable Stew. A barbarian on the fighter table.
return {
    name = "Oni Greatblade",
    race = "oni",
    tier = 2,
    class = "fighter",
    discipline = "barbarian",
    sprite = "assets/chars/oni_greatblade.png",
    archetype = "aggressive",
    stats = {
        health = 70, mana = 0, stamina = 26,
        staminaRegen = 4,
        damage = 11, magicDamage = 0,
        defense = 4, magicDefense = 2,
        movement = 3,
        speed = 2,
        skill = 3, luck = 3,
    },
    startingItems = {
        "weapon_odachi", "utility_unmoved", false,
        false,           false,             false,
        false,           false,             false,
    },
    drops = { "weapon_odachi", "consumable_questionable_stew" },
    defaultAction = "weapon_odachi",
    signatureWeapon = "weapon_odachi",
}
