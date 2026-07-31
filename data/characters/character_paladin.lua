-- Paladin exemplar (knight x priest multiclass). Ward aura: a persistent damage-reduction bubble on
-- adjacent allies; pull their debuffs onto yourself. Met as a sworn holy knight, a mentor. Home shelf
-- is knight. Kit from data/disciplines/paladin.lua.
return {
    name = "Paladin",
    sprite = "assets/chars/paladin.png",
    class = "knight",
    -- Shields the line and pulls allies' debuffs onto itself (models/ai.lua `support`).
    archetype = "support",
    stats = {
        health = 104, mana = 45, stamina = 16,
        staminaRegen = 2,
        damage = 15, magicDamage = 9,
        defense = 15, magicDefense = 11,
        movement = 4,
        speed = 3,
    },
    startingItems = {
        "weapon_demon_bane",   "ability_lay_on_hands", "ability_consecrate",
        "ability_oathkeepers_litany", "utility_aegis_of_the_oath", "armor_vow_marked_plate",
        "consumable_healing_potion", false,           false,
    },
    defaultAction = "ability_lay_on_hands",
    -- Lay on hands for the most wounded ally, pulling their debuffs across.
    ai = {
        { priority = "urgent", act = "support", item = "ability_lay_on_hands", targetPref = "most_wounded",
          when = { subject = "any_ally", test = "hp_pct_below", value = 0.6 } },
        { priority = "normal", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
