-- WARBREWER, as an adventurer ("The Rift's Adventurers", 2026-10-09; models/adventurers.lua). A
-- race-free body fielded as `character_adv_warbrewer@<race>`; `race` names the first leaning race only so
-- the blueprint loads. Built on the generic fighter (the root the exemplar walks): 5 / 3 magic.
--
-- WHAT IT DOES ON THE BOARD (Bottom of the Cup, Open the Line): it drinks mid-swing. The Berserker's Brew
-- is FREE -- an extra action, not the turn's -- so with a foe beside it the warbrewer drinks and swings
-- twice; the Bandolier hastes it on every draught, and the Battle Tonic tops its stamina back up for the
-- next Rend. The draughts are finite: no Field Still, whose reagent a turn would be a heal on a loop, and
-- no Survivor's Reflex. Kill it before the draughts stack.
return {
    name = "Warbrewer",
    race = "dwarf",
    tier = 2,
    adventurer = true,
    sprite = "assets/chars/warbrewer.png",
    class = "fighter",
    discipline = "warbrewer",
    archetype = "aggressive",
    stats = {
        health = 74, mana = 5, stamina = 25,
        staminaRegen = 2,
        damage = 18, magicDamage = 3,
        defense = 9, magicDefense = 5,
        movement = 4,
        speed = 3,
        skill = 5, luck = 3,
    },
    startingItems = {
        "weapon_iron_axe", "consumable_berserkers_brew", "consumable_battle_tonic",
        "utility_brawlers_bandolier", "ability_rend",
    },
    defaultAction = "weapon_iron_axe",
    signatureWeapon  = "weapon_iron_axe",
    signatureAbility = "consumable_berserkers_brew",
    -- Drink the brew with a foe in reach (it bills no action), then the swing.
    ai = {
        { priority = "urgent", act = "cast", item = "consumable_berserkers_brew",
          when = { subject = "nearest_foe", test = "within", value = 1 } },
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
