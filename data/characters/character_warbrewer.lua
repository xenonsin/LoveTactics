-- Warbrewer exemplar (fighter x alchemist multiclass). Combat draught: chug an elixir as a free action
-- mid-fight, then brawl. Met as a berserker-draught brawler, a boss. Home shelf is fighter. Kit from
-- data/disciplines/warbrewer.lua.
return {
    name = "Warbrewer",
    sprite = "assets/chars/warbrewer.png",
    boss = true,
    class = "fighter",
    -- Drinks, then brawls; the still refreshes the brew each turn (models/ai.lua `aggressive`).
    archetype = "aggressive",
    stats = {
        health = 120, mana = 20, stamina = 24,
        staminaRegen = 2,
        damage = 22, magicDamage = 6,
        defense = 11, magicDefense = 7,
        movement = 4,
        speed = 3,
    },
    startingItems = {
        "weapon_iron_axe",       "consumable_berserkers_brew", "consumable_battle_tonic",
        "utility_brawlers_bandolier", "utility_field_still",   "utility_round_for_the_house",
        "consumable_healing_potion", false,                  false,
    },
    defaultAction = "weapon_iron_axe",
    -- Press the wounded; the draughts do the rest between swings.
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
