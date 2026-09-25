-- THE HOARD-THANE, rung 2 elite: the dwarves' lord, in the Counting Hall. Reviewed 2026-09-24 with a note
-- that rewrote his class -- "be a barbarian, don't be afraid to use more advanced classes" -- and with the
-- Hoard (guard the heap) and Wages (a toll per turn) rows denied, so he no longer sits a hoard and bills
-- the purse. What is left is the race, made into an office:
--
--   HEIR OF ALL (utility_the_thanes_seal)  every fallen dwarf's Share and coffer come to HIM, wherever he
--                                          stands. Kill the line and he grows, to three Shares.
--   HIRE A HAND (ability_hire_hand)        at 30 gold from his coffer a Delver surfaces beside him; it
--                                          leaves when he falls. Kill the line early and he stays poor.
--   GREASE PALMS                           gold is speed: he hastes himself or a kinsman out of the same
--                                          coffer. Everything he spends is gone from the spoils.
--   A BARBARIAN (fighter root)             Desperate Strike and the Reckless Stance: he hits harder the
--                                          worse he is hurt, and the Butcher's Tally counts every body
--                                          that falls -- his own line's included. The Shares and the tally
--                                          are the same deaths paid twice.
--
--   THE KING'S JEWEL (round 3)             when he falls, his office drops on his tile, and the first
--                                          dwarf to reach it is the new heir of all (hazard_kings_jewel).
--
-- So the fight is a race with no clean answer: every kill feeds him, and every turn he is left alone he
-- buys another body. The one lever that is not a trade is the heaps -- loot them, and every dwarf on
-- the board, the Thane included, comes for you with Gold Fever and its open guard.
return {
    name = "The Hoard-Thane",
    race = "dwarf",
    tier = 3,
    boss = true, -- off the execute and Charm tables, as an elite is
    class = "fighter",
    discipline = "barbarian",
    sprite = "assets/chars/the_hoard_thane.png",
    archetype = "aggressive",
    coffer = 60,
    stats = {
        health = 118, mana = 5, stamina = 26,
        staminaRegen = 2,
        damage = 20, magicDamage = 4,
        defense = 8, magicDefense = 6, -- 9 after the race
        movement = 5, -- 4 after the race; three Shares take him to 1
        speed = 3,
        skill = 6, luck = 4,
    },
    startingItems = {
        "weapon_iron_axe",          "ability_desperate_strike", "ability_reckless_stance",
        "utility_the_thanes_seal",  "ability_hire_hand",        "ability_grease_palms",
        "utility_butchers_tally",   false,                      false,
    },
    -- His own trophy is the Mithril Shirt (round 3); the rest is his line's, and the Butcher's Tally.
    drops = { "armor_mithril_shirt", "ability_gilders_leaf", "ability_delve", "utility_butchers_tally" },
    defaultAction = "weapon_iron_axe",
    signatureWeapon = "weapon_iron_axe",
    ai = {
        { priority = "urgent", act = "cast", item = "ability_hire_hand",
          when = { subject = "any_foe", test = "exists" } },
        { priority = "high", act = "support", item = "ability_grease_palms", targetPref = "self",
          when = { subject = "self", test = "lacks_status", value = "status_hasted" } },
        { priority = "high", act = "attack", targetPref = "gilded",
          when = { subject = "any_foe", test = "has_status", value = "status_gilded" } },
        { priority = "normal", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
