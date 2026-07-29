-- Inquisitor exemplar (rogue x priest multiclass). Judgment: mark a heretic, then execute for holy
-- damage that also dispels. Met as a witch-finder, a boss. Home shelf is rogue (Confessor's Needle).
-- Kit from data/disciplines/inquisitor.lua.
return {
    name = "Witch-Finder",
    sprite = "assets/chars/priest.png",
    boss = true,
    class = "rogue",
    -- Marks, strips the buff, then sentences the marked (models/ai.lua `aggressive`).
    archetype = "aggressive",
    stats = {
        health = 98, mana = 40, stamina = 20,
        staminaRegen = 2,
        damage = 18, magicDamage = 12,
        defense = 9, magicDefense = 10,
        movement = 4,
        speed = 4,
    },
    startingItems = {
        "weapon_confessors_needle", "ability_mark_of_heresy", "ability_sentence",
        "ability_the_question",     "ability_the_pyre",       "armor_leather_armor",
        "consumable_healing_potion", false,                  false,
    },
    defaultAction = "weapon_confessors_needle",
    -- 1. Sentence a foe already Marked. 2. Otherwise brand a fresh one.
    ai = {
        { priority = "urgent", act = "attack", item = "ability_sentence", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "has_status", value = "status_mark" } },
        { priority = "high", act = "cast", item = "ability_mark_of_heresy",
          when = { subject = "any_foe", test = "lacks_status", value = "status_mark" } },
    },
}
