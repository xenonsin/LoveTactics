-- Ansel, the Apothecary the Hiring Hall offers. A version of the apothecary exemplar
-- (data/characters/character_apothecary.lua), which stays put.
--
-- The Open Ward (data/items/utility/utility_open_ward.lua) pays off what he ALREADY does rather than
-- giving him a new verb: from the moment it lands, every heal he casts also lends its number back as a
-- ward. Transfusion and The Shared Ledger are what put lent guard on three bodies to open it.
return {
    name = "Ansel",
    kind = "humanoid",
    tier = 3,
    sprite = "assets/chars/ansel.png",
    class = "priest",
    discipline = "apothecary",
    archetype = "support",
    stats = {
        health = 82, mana = 70, stamina = 12,
        staminaRegen = 2,
        damage = 6, magicDamage = 12,
        defense = 8, magicDefense = 12,
        movement = 4,
        speed = 3,
    },
    startingItems = {
        "weapon_apothecarys_lancet", "ability_transfusion", "utility_shared_ledger",
        "consumable_the_tithe",      "utility_open_ward",   "utility_coveted_blood",
        "consumable_borrowed_hands", "consumable_healing_potion", false,
    },
    defaultAction = "ability_transfusion",
    signatureWeapon  = "weapon_apothecarys_lancet",
    signatureAbility = "utility_open_ward",
    ai = {
        { priority = "high", act = "support", item = "ability_transfusion", targetPref = "most_wounded",
          when = { subject = "any_ally", test = "hp_pct_below", value = 0.6 } },
    },
}
