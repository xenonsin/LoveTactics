-- THE ASCENDED DUKE: what the Archon Duke becomes at the third wisp it takes in ("The Crown's Bestiary", slice A,
-- 2026-10-09). Nothing fields this body directly: the Duke reaches it through its own Ascension
-- (models/archon_court.lua's takeWisp, through Transform.apply) and wears it for the rest of the fight. So every
-- number below is the SHAPE's -- the kit and the flat stats -- and the pools are the Duke's own, which Ascending
-- then fills to the brim (the review's "healed to full").
--
-- WHAT IS NEW in the body:
--   SENTENCE OF THE COURT   magic damage to a foe within 4 and every body beside it (ability_sentence_of_the_court)
--   harder flat stats       it hits and holds like the thing three of its own court were spent to make
-- And what it keeps: the blade, the Killing Magic, and Command. Not Ascension -- it has Ascended.
--
-- Humanoid, an Archon, and still not a demon. It drops nothing of its own; the Duke's list pays for both bodies.
return {
    name = "Ascended Duke",
    race = "archon",
    tier = 4,
    class = "priest",
    sprite = "assets/chars/archon_duke_ascended.png",
    archetype = "aggressive",
    stats = {
        health = 168, mana = 48, stamina = 26,
        staminaRegen = 4, manaRegen = 4,
        damage = 7, magicDamage = 17,
        defense = 7, magicDefense = 8,
        movement = 5,
        speed = 5,
        skill = 7, luck = 5,
    },
    startingItems = {
        "weapon_mana_cut_blade", "ability_killing_magic", "ability_sentence_of_the_court",
        "utility_ducal_command", false,                   false,
        false,                   false,                   false,
    },
    defaultAction = "weapon_mana_cut_blade",
    signatureWeapon = "weapon_mana_cut_blade",
}
