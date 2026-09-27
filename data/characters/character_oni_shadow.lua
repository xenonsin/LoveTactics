-- THE ONI SHADOW, rung 1: the clan's spy (approved 2026-09-26/27, "The Oni of Wrath"), after Reincarnated as a
-- Slime's retainer who moves through shadow and works with thread.
--
-- It steps out beside a foe in one move (Shadow Step), plants a double and slips Invisible (Mirror Image), and its
-- Steel Thread ROOTS AND MARKS a body within 4 -- the author's own replacement for the round-1 thread. A Mark is
-- easier to crit, and a crit is what snaps a horn, so the thread cuts both ways on a board with oni on it.
--
-- It drops the Steel Thread. A ninja on the rogue table.
return {
    name = "Oni Shadow",
    race = "oni",
    tier = 2,
    class = "rogue",
    discipline = "ninja",
    sprite = "assets/chars/oni_shadow.png",
    archetype = "aggressive",
    stats = {
        health = 44, mana = 16, stamina = 22,
        staminaRegen = 3,
        damage = 9, magicDamage = 4,
        defense = 2, magicDefense = 3,
        movement = 4,
        speed = 4,
        skill = 5, luck = 5,
    },
    startingItems = {
        "weapon_iron_dagger",   "ability_steel_thread", "ability_shadow_step",
        "ability_mirror_image", false,                  false,
        false,                  false,                  false,
    },
    drops = { "ability_steel_thread" },
    defaultAction = "weapon_iron_dagger",
    signatureWeapon = "weapon_iron_dagger",
}
