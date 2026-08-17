-- Nix, the Saboteur the Hiring Hall offers. A version of the saboteur exemplar
-- (data/characters/character_saboteur.lua, the demolitions ghost), which stays put.
--
-- The Signal (data/items/utility/utility_the_signal.lua) sets off everything she planted AND leaves the
-- ground ruined -- which is what separates it from the Bombardier's Short Fuse. Pol is having a moment;
-- Nix is removing a building.
return {
    name = "Nix",
    kind = "humanoid",
    tier = 3,
    sprite = "assets/chars/nix.png",
    class = "rogue",
    discipline = "saboteur",
    archetype = "skirmish",
    stats = {
        health = 84, mana = 8, stamina = 20,
        staminaRegen = 2,
        damage = 14, magicDamage = 3,
        defense = 6, magicDefense = 7,
        movement = 4,
        speed = 5,
    },
    startingItems = {
        "weapon_iron_dagger",  "ability_set_charge",   "ability_detonator",
        "ability_bring_it_down", "utility_the_signal", "ability_ghost_kit",
        "consumable_sappers_line", "consumable_healing_potion", false,
    },
    defaultAction = "weapon_iron_dagger",
    signatureWeapon  = "weapon_iron_dagger",
    signatureAbility = "utility_the_signal",
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
