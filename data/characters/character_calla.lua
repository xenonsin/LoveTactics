-- Calla, the Inquisitor the Hiring Hall offers. A version of the inquisitor exemplar
-- (data/characters/character_inquisitor.lua, the witch-finder), which stays put.
--
-- The Written Charge (data/items/utility/utility_written_charge.lua) judges every Marked foe at once and
-- each blow grows with how many are accused. Sentence and The Question each spend a single mark, so
-- they compete with it for the same bodies -- which is the decision the discipline is built on.
return {
    name = "Calla",
    kind = "humanoid",
    tier = 3,
    sprite = "assets/chars/calla.png",
    class = "priest",
    discipline = "inquisitor",
    archetype = "aggressive",
    stats = {
        health = 98, mana = 70, stamina = 20,
        staminaRegen = 2,
        damage = 18, magicDamage = 12,
        defense = 9, magicDefense = 10,
        movement = 4,
        speed = 4,
    },
    startingItems = {
        "weapon_confessors_needle", "ability_mark_of_heresy", "ability_anathema",
        "ability_sentence",         "utility_written_charge", "ability_the_question",
        "ability_the_pyre",         "consumable_healing_potion", false,
    },
    defaultAction = "weapon_confessors_needle",
    signatureWeapon  = "weapon_confessors_needle",
    signatureAbility = "utility_written_charge",
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
