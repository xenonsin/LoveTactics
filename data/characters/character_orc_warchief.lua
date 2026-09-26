-- THE ORC WARCHIEF, rung 3: the orcs' elite, and the strongest leads (approved as pitched, 2026-09-26, "The Orcs
-- of Wrath"; Keno's reversal made the Warchief the elite).
--
-- His Presence (utility_warchiefs_presence): allies within 3 deal +2 Damage. The Strongest Leads: when he falls,
-- the most-Proven orc on the board (ties: most health) takes his place -- it heals half and takes up the Presence
-- and the rule. Killing the head promotes the veteran; kill him before anyone is Proven, or cut the scarred down
-- first. He wears his own Heir's Torc, so every orc that falls around him makes him worse.
--
-- TIER 3, NOT 4, where the review page said 4: the Goblin King set the elite's rung at 3 (150 health), and 4 is the
-- boss rung, a quest's ending. No discipline, as the King has none: a claimed discipline must be carried. He drops
-- the Heir's Torc and The Strongest Leads.
return {
    name = "Orc Warchief",
    race = "orc",
    tier = 3,
    class = "fighter",
    sprite = "assets/chars/orc_warchief.png",
    archetype = "aggressive",
    stats = {
        health = 150, mana = 0, stamina = 32,
        staminaRegen = 5,
        damage = 15, magicDamage = 0,
        defense = 6, magicDefense = 5,
        movement = 4,
        speed = 3,
        skill = 7, luck = 6,
    },
    startingItems = {
        "weapon_crimson_greataxe", "utility_warchiefs_presence", "utility_heirs_torc",
        false,                     false,                        false,
        false,                     false,                        false,
    },
    drops = { "utility_heirs_torc", "ability_the_strongest_leads" },
    defaultAction = "weapon_crimson_greataxe",
    signatureWeapon = "weapon_crimson_greataxe",
}
