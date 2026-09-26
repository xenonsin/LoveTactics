-- THE ORC SPEAR-HURLER, rung 1 (approved as pitched, 2026-09-26, "The Orcs of Wrath"). Its Hooked Spear drags a
-- body in beside it, into the warband's reach -- it feeds kills to the line, and a body at the back is not safe
-- from Proven. It drops nothing new: it carries a stock spear. A hunter, no discipline.
return {
    name = "Orc Spear-Hurler",
    race = "orc",
    tier = 1,
    class = "hunter",
    sprite = "assets/chars/orc_spear_hurler.png",
    archetype = "skirmish",
    stats = {
        health = 22, mana = 0, stamina = 20,
        staminaRegen = 3,
        damage = 7, magicDamage = 0,
        defense = 2, magicDefense = 1,
        movement = 4,
        speed = 3,
        skill = 6, luck = 3,
    },
    startingItems = {
        "weapon_iron_spear", "ability_hooked_spear", false,
        false,               false,                  false,
        false,               false,                  false,
    },
    defaultAction = "weapon_iron_spear",
    signatureWeapon = "weapon_iron_spear",
}
