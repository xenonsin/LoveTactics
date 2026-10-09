-- PALADIN, as an adventurer ("The Rift's Adventurers", 2026-10-09; models/adventurers.lua). A race-free
-- body fielded as `character_adv_paladin@<race>`; `race` names the first leaning race only so the
-- blueprint loads. Built on the generic knight (the root the exemplar walks): 15 / 4 magic.
--
-- WHAT IT DOES ON THE BOARD (The Shieldwall, The Purge): the Aegis of the Oath lays a Shared Bulwark on
-- the ground around it, so every ally beside it carries a barrier that swallows a blow -- and loses it the
-- moment it steps off, which is the page's counter (pull them apart). It walks to its own (`support`
-- regroups), and Lay on Hands is its one heal: twelve of the knight's fifteen mana, once a fight. A party
-- holds at most one sustain body per three, and this body's sustain is the aura, not a heal on a loop.
return {
    name = "Paladin",
    race = "human",
    tier = 2,
    adventurer = true,
    sprite = "assets/chars/paladin.png",
    class = "knight",
    discipline = "paladin",
    archetype = "support",
    stats = {
        health = 72, mana = 15, stamina = 18,
        staminaRegen = 2,
        damage = 12, magicDamage = 4,
        defense = 12, magicDefense = 7,
        movement = 4,
        speed = 3,
        skill = 3, luck = 2,
    },
    startingItems = {
        "weapon_demon_bane", "utility_aegis_of_the_oath", "ability_lay_on_hands",
        "armor_chainmail",
    },
    defaultAction = "weapon_demon_bane",
    signatureWeapon  = "weapon_demon_bane",
    signatureAbility = "utility_aegis_of_the_oath",
    -- The one heal on an ally in trouble; otherwise stand with the line and strike what reaches it.
    ai = {
        { priority = "urgent", act = "support", item = "ability_lay_on_hands", targetPref = "most_wounded",
          when = { subject = "any_ally", test = "hp_pct_below", value = 0.5 } },
        { priority = "normal", act = "attack", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
