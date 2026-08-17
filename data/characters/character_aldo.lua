-- Aldo, the Champion the Hiring Hall offers. A version of the champion exemplar
-- (data/characters/character_champion.lua), which stays where it is as the Colosseum's own boss.
--
-- The Crowd's Due (data/items/armor/armor_crowds_due.lua) binds the whole field to him and braces for
-- what comes -- the same hitTaken tally the Sworn Aegis uses, spent on the opposite idea. Rowan
-- weathers to shove the ring off her charge; Aldo weathers to be swung at again.
return {
    name = "Aldo",
    kind = "humanoid",
    tier = 3,
    sprite = "assets/chars/aldo.png",
    class = "knight",
    discipline = "champion",
    archetype = "defensive",
    stats = {
        health = 110, mana = 15, stamina = 20,
        staminaRegen = 2,
        damage = 20, magicDamage = 4,
        defense = 10, magicDefense = 8,
        movement = 4,
        speed = 3,
    },
    startingItems = {
        "weapon_iron_sword", "ability_provoke",     "ability_defiant_stand",
        "ability_answering_blow", "armor_crowds_due", "utility_reprisal",
        "utility_odds_against", "consumable_healing_potion", false,
    },
    defaultAction = "weapon_iron_sword",
    signatureWeapon  = "weapon_iron_sword",
    signatureAbility = "armor_crowds_due",
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
