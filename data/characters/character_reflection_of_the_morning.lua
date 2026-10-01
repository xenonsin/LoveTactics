-- REFLECTION OF THE MORNING: what Superbia calls when the Host descends (reviewed over three rounds, "Pride's
-- Generals"). Two a turn from two-thirds of her health until the Fall, when every one shatters.
--
-- Summoned only, never rolled: it is in no encounter and adds no traffic. Any blow fells it (it is called
-- `fragile`, models/morning_star.lua), and it carries her Light-Bearer, so a company that looks at the Host goes
-- blind -- the answer is to cut them down fast, or to fight her from where none of them can be seen. An angel,
-- so it is Incorruptible as every angel is. It strikes with her spear.
--
-- No drops: a reflection has nothing of its own to give.
return {
    name = "Reflection of the Morning",
    race = "angel",
    tier = 1,
    sprite = "assets/chars/reflection_of_the_morning.png",
    archetype = "aggressive",
    stats = {
        health = 6, mana = 0, stamina = 15,
        staminaRegen = 3,
        damage = 6, magicDamage = 0,
        defense = 0, magicDefense = 0,
        movement = 4,
        speed = 4,
        skill = 5, luck = 0,
    },
    startingItems = {
        "weapon_spear_of_the_morning", "utility_light_bearer", false,
        false,                          false,                  false,
        false,                          false,                  false,
    },
    defaultAction = "weapon_spear_of_the_morning",
}
