-- THE ONI PRIESTESS, rung 1: the clan's shrine maiden (approved 2026-09-26, "The Oni of Wrath"), after
-- Reincarnated as a Slime's priestess, whose work is to purify.
--
-- Her bell cleanses every ally within 2 (Purifying Bell), she strips a blessing off a foe (Unblessing), and an oni
-- standing beside her cannot have its horn snapped (Keeper of Horns). She is the body a company must answer before
-- any plan to snap horns can work -- the kill-first support.
--
-- She drops the Purifying Bell. On the priest table.
return {
    name = "Oni Priestess",
    race = "oni",
    tier = 2,
    class = "priest",
    sprite = "assets/chars/oni_priestess.png",
    archetype = "support",
    stats = {
        health = 42, mana = 34, stamina = 14,
        staminaRegen = 2, manaRegen = 3,
        damage = 5, magicDamage = 9,
        defense = 2, magicDefense = 5,
        movement = 4,
        speed = 3,
        skill = 3, luck = 4,
    },
    startingItems = {
        "weapon_staff",            "ability_purifying_bell", "ability_unblessing",
        "utility_keeper_of_horns", false,                    false,
        false,                     false,                    false,
    },
    drops = { "ability_purifying_bell" },
    defaultAction = "weapon_staff",
    signatureWeapon = "weapon_staff",
}
