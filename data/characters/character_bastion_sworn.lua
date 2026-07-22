-- A knight of the Bastion in good standing, and the enemy at slot 8 of the knight line
-- (data/quests/what_the_bastion_knows.lua). Not forsworn, not corrupted -- loyal, decorated, and
-- standing between the player and the order's own record.
--
-- Deliberately a SEPARATE blueprint from Rowan (data/characters/character_knight.lua), who is the
-- companion and whose display name is a proper one. A quest that spawned her blueprint as an enemy
-- would put a squad of Rowans on the board.
--
-- They fight the way the Bastion sells: sword, shield, and the Defend brace. The player has bought
-- this exact kit off their shelf, which is the point -- the wall the order taught you is the wall it
-- puts in front of the thing it does not want read.
return {
    name = "Sworn of the Bastion",
    sprite = "assets/chars/bastion_sworn.png",
    class = "knight",
    stats = {
        health = 74, mana = 0, stamina = 13,
        staminaRegen = 2,
        damage = 14, magicDamage = 0,
        defense = 16, magicDefense = 8,
        movement = 3,
        speed = 3,
    },
    startingItems = {
        "weapon_iron_sword", "armor_buckler", false,
        false,               false,           false,
        false,               false,           false,
    },
    defaultAction = "weapon_iron_sword",
    -- Basic tactics (models/ai.lua): press the wounded -- finish the foe already closest to falling,
    -- ahead of the posture's ordinary "hit whatever is in reach".
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
