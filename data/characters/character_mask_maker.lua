-- THE MASK-MAKER, rung 2 and tier 3: the Faceless who builds a company (reviewed 2026-10-01..03, "Envy's
-- Bestiary"; it replaced the Captain in round 2).
--
-- A COMPANY OF ITS OWN. Its hand is four faces, one for each place in a company: a shield, a healer, an archer and
-- a caster, read off each face's own kit. At the start of its turn it hands every Faceless within 3 a face from
-- that hand, all different, nearest first, so the shield goes to whoever is already in front. A masked body wears
-- what it is given and does not Reshape; kill the Mask-Maker and every one of them goes back to reading for itself
-- (The Mask-Maker's Hand, models/masks.lua).
--
-- It drops Faceless Retinue, on the summoner's shelf.
return {
    name = "The Mask-Maker",
    race = "faceless",
    tier = 3,
    sprite = "assets/chars/mask_maker.png",
    stats = {
        health = 90, mana = 40, stamina = 18,
        staminaRegen = 2, manaRegen = 4,
        damage = 8, magicDamage = 10,
        defense = 5, magicDefense = 8,
        movement = 3,
        speed = 4,
        skill = 5, luck = 5,
    },
    startingItems = {
        "utility_mask_makers_hand", "weapon_iron_crook", "armor_leather_armor",
        false,                      false,               false,
        false,                      false,               false,
    },
    drops = { "ability_faceless_retinue" },
    defaultAction = "weapon_iron_crook",
    archetype = "defensive",
    ai = {
        { priority = "normal", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
