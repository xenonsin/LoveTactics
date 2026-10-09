-- THEURGE, as an adventurer ("The Rift's Adventurers", 2026-10-09; models/adventurers.lua). A race-free
-- body fielded as `character_adv_theurge@<race>`; `race` names the first leaning race only so the
-- blueprint loads. Built on the generic mage (the root the exemplar walks): 80 / 18 magic.
--
-- WHAT IT DOES ON THE BOARD (The Long Invocation, The Shieldwall, The Sigil Choir): it keeps channelling.
-- Invocation winds up four ticks and sears an area, and the Second Utterance lets the next channel go
-- with no wind-up once one resolves, so a theurge left alone casts back to back. Every turn you wait,
-- the spell lands. Deliberately NOT carried: the Vigil Beads, which make a channel impossible to break --
-- that would delete the counter a spellbreaker is in the game to be -- and Benediction, a channelled
-- party heal four times over on eighty mana, which is the sustain the parties are capped against.
return {
    name = "Theurge",
    race = "human",
    tier = 2,
    adventurer = true,
    sprite = "assets/chars/theurge.png",
    class = "mage",
    discipline = "theurge",
    archetype = "support",
    stats = {
        health = 46, mana = 80, stamina = 10,
        staminaRegen = 1,
        damage = 5, magicDamage = 18,
        defense = 4, magicDefense = 13,
        movement = 4,
        speed = 3,
        skill = 6, luck = 4,
    },
    startingItems = {
        "weapon_litany_staff", "ability_invocation", "utility_second_utterance",
        "armor_silk_robes",
    },
    defaultAction = "weapon_litany_staff",
    signatureWeapon  = "weapon_litany_staff",
    signatureAbility = "ability_invocation",
    -- Wind the Invocation up whenever a foe stands within its reach.
    ai = {
        { priority = "high", act = "cast", item = "ability_invocation",
          when = { subject = "any_foe", test = "within", value = 5 } },
    },
}
