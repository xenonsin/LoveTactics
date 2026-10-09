-- ADVENTURER: the race-free Barbarian a party fields ("The Rift's Adventurers", 2026-10-09). Fielded as
-- `character_adv_barbarian@<race>` (models/adventurers.lua); `race` below is only the class's first
-- leaning race, so the base blueprint loads. Traffic, not the exemplar's arena boss: the fighter
-- template leaned toward Rage -- a little more health to spend and a little less armour.
--
-- THE LAST STAND IS HIS PARTY. He hits harder the more hurt he is, and a Sentinel stands beside him
-- taking the blows meant for him, so he can sit at low health without dying. So he does not drink:
-- no potion in the kit, because healing him back up is the one thing his own shelf argues against.
return {
    name = "Barbarian",
    race = "orc",
    tier = 2,
    adventurer = true,
    sprite = "assets/chars/barbarian.png",
    class = "fighter",
    discipline = "barbarian",
    archetype = "aggressive",
    stats = {
        health = 76, mana = 5, stamina = 26,
        staminaRegen = 2,
        damage = 19, magicDamage = 3,
        defense = 8, magicDefense = 5,
        movement = 4,
        speed = 3,
        skill = 5, luck = 3,
    },
    startingItems = {
        "weapon_iron_axe",         "ability_desperate_strike", "ability_fury",
        "ability_reckless_stance", "utility_butchers_tally",   "armor_leather_armor",
    },
    defaultAction = "weapon_iron_axe",
    signatureWeapon  = "weapon_iron_axe",
    signatureAbility = "ability_fury",
    -- Low on health is where he wants to be: Fury once he is deep in it, the Desperate Strike while he
    -- is getting there, and the wounded foe otherwise.
    ai = {
        { priority = "urgent", act = "cast", item = "ability_fury",
          when = { subject = "self", test = "hp_pct_below", value = 0.35 } },
        { priority = "high", act = "attack", item = "ability_desperate_strike", targetPref = "lowest_hp",
          when = { subject = "self", test = "hp_pct_below", value = 0.6 } },
        { priority = "normal", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
