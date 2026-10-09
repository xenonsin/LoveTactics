-- INQUISITOR, as an adventurer ("The Rift's Adventurers", 2026-10-09; models/adventurers.lua). A race-free
-- body: `race` is the class's first leaning race only so the blueprint loads, and a party fields it as
-- `character_adv_inquisitor@<race>`. Honest traffic built on the generic rogue (character_rogue), which is
-- the root the exemplar walks, so the magic pair is the rogue's 8 / 3.
--
-- WHAT IT DOES ON THE BOARD (The Purge, The Contract, Hit and Gone): it Marks one of yours from range,
-- takes a blessing off the Marked body with The Question, and the Confessor's Needle executes a Marked foe
-- under a third. The rogue's eight mana buys ONE Mark a fight, which is the reason Sentence (14) and The
-- Pyre (18) are not carried: a spell the pool can never pay is a dead cell. One mark, then the knife --
-- and the counter the party page names (pull the marked body back, or kill the inquisitor) stays whole.
return {
    name = "Inquisitor",
    race = "human",
    tier = 2,
    adventurer = true,
    sprite = "assets/chars/inquisitor.png",
    class = "rogue",
    discipline = "inquisitor",
    archetype = "aggressive",
    stats = {
        health = 58, mana = 8, stamina = 22,
        staminaRegen = 2,
        damage = 15, magicDamage = 3,
        defense = 7, magicDefense = 6,
        movement = 4,
        speed = 5,
        skill = 8, luck = 7,
    },
    startingItems = {
        "weapon_confessors_needle", "ability_mark_of_heresy", "ability_the_question",
        "armor_leather_armor",
    },
    defaultAction = "weapon_confessors_needle",
    signatureWeapon  = "weapon_confessors_needle",
    signatureAbility = "ability_mark_of_heresy",
    -- 1. The Needle at the Marked body (its execute line is a third). 2. Strip a blessing off it.
    -- 3. Brand one, once a fight -- the pool refuses the second.
    ai = {
        { priority = "urgent", act = "attack", item = "weapon_confessors_needle", targetPref = "marked",
          when = { subject = "any_foe", test = "has_status", value = "status_mark" } },
        { priority = "high", act = "attack", item = "ability_the_question", targetPref = "marked",
          when = { subject = "any_foe", test = "has_status", value = "status_mark" } },
        { priority = "high", act = "cast", item = "ability_mark_of_heresy", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "lacks_status", value = "status_mark" } },
    },
}
