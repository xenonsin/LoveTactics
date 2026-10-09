-- THE ARCHON DUKE: the court's elite, on the Crown's floor ("The Crown's Bestiary", slice A, 2026-10-09). Humanoid;
-- its rank is in its face and its robe.
--
--   ASCENSION     any wisp within 3 of the Duke may go to it instead of to its own body. The Duke takes it in, and
--                 that Archon stays down. At 3 wisps taken, the Duke Ascends: a new form, healed to full, with new
--                 spells (utility_ducal_ascension -> character_archon_duke_ascended)
--   COMMAND       Archons within 3 of it act before the company's bodies do (utility_ducal_command: at the end of
--                 each of its turns, the court near it is pulled ahead of the company's soonest body)
--   KILLING MAGIC the Greater Archon's beam, which it casts too (ability_killing_magic)
--   SPIRIT BODY   the race (data/races/archon.lua)
--
-- HOW YOU BEAT IT, the review's own: every wisp is now a choice the court makes, so keep the fight away from the Duke
-- and kill wisps before it can take three.
--
-- Tier 4, so the elite rung's three-item rule (a tier-3 humanoid) does not bind it; it carries four anyway. It drops
-- Ascension, a Champion's -- the same rule fed by the foes the bearer downs.
return {
    name = "Archon Duke",
    race = "archon",
    tier = 4,
    class = "priest",
    sprite = "assets/chars/archon_duke.png",
    archetype = "aggressive",
    stats = {
        health = 168, mana = 48, stamina = 26,
        staminaRegen = 4, manaRegen = 3,
        damage = 5, magicDamage = 13,
        defense = 5, magicDefense = 6, -- 8 after the race
        movement = 4,
        speed = 4,
        skill = 6, luck = 5,
    },
    startingItems = {
        "weapon_mana_cut_blade",   "ability_killing_magic", false,
        "utility_ducal_ascension", "utility_ducal_command", false,
        false,                     false,                   false,
    },
    drops = { "utility_ascension" },
    defaultAction = "weapon_mana_cut_blade",
    signatureWeapon = "weapon_mana_cut_blade",
}
