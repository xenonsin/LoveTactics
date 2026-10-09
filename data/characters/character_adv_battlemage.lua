-- BATTLEMAGE, as an adventurer ("The Rift's Adventurers", 2026-10-09; models/adventurers.lua). A
-- race-free body fielded as `character_adv_battlemage@<race>`; `race` names the first leaning race only
-- so the blueprint loads. Built on the generic mage (the root the exemplar walks): 80 / 18 magic, with the
-- physical side leaned toward the front it fights on.
--
-- WHAT IT DOES ON THE BOARD (The Shieldwall, Fire and Steel): it strikes and casts in one action. The
-- Spellstrike sits beside the axe in the grid, so the axe's blow is magical and Burns; Arcane Cleave is the
-- swing it opens with; the Emberwand is the bolt for a foe it cannot reach. The axe is the default because
-- the brief wants a weapon there, and the mage's own staff would turn the swing into a feeble poke.
return {
    name = "Battlemage",
    race = "oni",
    tier = 2,
    adventurer = true,
    sprite = "assets/chars/battlemage.png",
    class = "mage",
    discipline = "battlemage",
    archetype = "aggressive",
    stats = {
        health = 54, mana = 80, stamina = 16,
        staminaRegen = 2,
        damage = 11, magicDamage = 18,
        defense = 6, magicDefense = 11,
        movement = 4,
        speed = 3,
        skill = 6, luck = 4,
    },
    startingItems = {
        "weapon_iron_axe", "utility_spellstrike", "ability_arcane_cleave",
        "utility_battle_casting", "weapon_emberwand", "armor_silk_robes",
    },
    defaultAction = "weapon_iron_axe",
    signatureWeapon  = "weapon_iron_axe",
    signatureAbility = "ability_arcane_cleave",
    -- Cleave whatever is beside it; finish the wounded with whatever reaches.
    ai = {
        { priority = "high", act = "attack", item = "ability_arcane_cleave",
          when = { subject = "any_foe", test = "within", value = 1 } },
        { priority = "normal", act = "attack", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
