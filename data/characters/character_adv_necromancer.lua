-- ADVENTURER: the race-free Necromancer a party fields ("The Rift's Adventurers", 2026-10-09). Fielded
-- as `character_adv_necromancer@<race>` (models/adventurers.lua); `race` below is only the class's first
-- leaning race, so the base blueprint loads. The mage template, a little sturdier.
--
-- ANY BODY THAT FALLS, HE RAISES OR BURSTS (Raise the Fallen, the Contagion). Raise Dead outranks
-- everything when there is a corpse beside one of his own; Corpse Burst when there is one beside
-- yours. With no corpse on the board both score nothing and he shoots the weakest with the staff.
return {
    name = "Necromancer",
    race = "orc",
    tier = 2,
    adventurer = true,
    sprite = "assets/chars/necromancer.png",
    class = "mage",
    discipline = "necromancer",
    archetype = "skirmish",
    stats = {
        health = 46, mana = 80, stamina = 10,
        staminaRegen = 1,
        damage = 5, magicDamage = 18,
        defense = 4, magicDefense = 12,
        movement = 4,
        speed = 3,
        skill = 6, luck = 4,
    },
    startingItems = {
        "weapon_the_unreturning",    "ability_raise_dead", "ability_corpse_burst",
        "utility_charnel_reliquary", "armor_silk_robes",   "consumable_healing_potion",
    },
    defaultAction = "weapon_the_unreturning",
    signatureWeapon  = "weapon_the_unreturning",
    signatureAbility = "ability_raise_dead",
    ai = {
        { priority = "emergency", act = "retreat", when = { subject = "self", test = "hp_pct_below", value = 0.3 } },
        { priority = "urgent", act = "cast", item = "ability_raise_dead",
          when = { subject = "any_foe", test = "exists" } },
        { priority = "high", act = "attack", item = "ability_corpse_burst",
          when = { subject = "any_foe", test = "exists" } },
        { priority = "normal", act = "attack", item = "weapon_the_unreturning", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
