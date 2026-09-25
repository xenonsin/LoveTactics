-- THE GILT WYRM: what a dwarf becomes when the gold wins. Reviewed 2026-09-25 ("Dragon-Sickness", after
-- Fafnir, who was a dwarf before the hoard made him a dragon). Nothing fields this body directly: a dwarf
-- reaches it through its own race, at the third stack of Dragon-Sickness
-- (data/status/status_dragon_sickness.lua), and wears it for the rest of the fight. So every number
-- below is the SHAPE's -- the kit and the flat stats -- and never the pools: the dwarf's own health, its
-- wounds and its stacks come with it (models/transform.lua), and it is minted at the dwarf's own level.
--
-- The name is the one a deleted body held (the Gilt Wyrm of 2026-09-22's cut, a hoard-beast on four
-- tiles). Its maw survived that cut unclaimed, and this wyrm wears it.
--
-- WHAT IT DOES, and why each piece is not Avaritia's (she is born a dragon and burns):
--   GILT MAW (weapon_gilt_maw)        a 3-wide bite that banks gold, standing in for the tail as well
--   VENOM BREATH (ability_venom_breath) poison, not fire: a cone that poisons and leaves Choking Fumes
--                                     behind for three turns -- the existing ground, which spares its own
--                                     side as it spares a censer-bearer's
--   DREAD (utility_wyrm_dread)        the Helm of Terror: foes within 2 of it move 2 fewer squares
--   STOUT (utility_stout)             still a dwarf's organ: it cannot be moved or robbed, it still goes for
--                                     loose gold (and its stacks still grow), and its Share still passes on
--
-- Its drops are the saga's (Gram, the Helm, the heart, the leaf) plus the breath and the gold-covered
-- skin. A turned dwarf pays from this list AND its own (models/spoils.lua), so turning costs the company
-- nothing it would have been paid.
return {
    name = "Gilt Wyrm",
    race = "dragon",
    tier = 2,
    sprite = "assets/chars/gilt_wyrm.png",
    archetype = "aggressive",
    stats = {
        health = 70, mana = 10, stamina = 24,
        staminaRegen = 3,
        damage = 15, magicDamage = 10,
        defense = 5, magicDefense = 4,
        movement = 4,
        speed = 4,
        skill = 5, luck = 4,
    },
    resist = { slash = 1, pierce = -2, impact = 1 },
    startingItems = {
        "weapon_gilt_maw", "ability_venom_breath", false,
        "utility_wyrm_dread", "utility_stout",   false,
        false,               false,             false,
    },
    drops = {
        "weapon_gram", "armor_aegishjalmur", "ability_wyrms_venom",
        "utility_lindworm_heart", "utility_linden_leaf", "utility_every_hair_covered",
    },
    defaultAction = "weapon_gilt_maw",
    signatureWeapon = "weapon_gilt_maw",
    ai = {
        { priority = "high", act = "attack", item = "ability_venom_breath",
          when = { subject = "nearest_foe", test = "within", value = 3 } },
        { priority = "normal", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
