-- THE DWARF GOLDSMITH, rung 2: the line's support, with a forge of its own. Reworked twice on review
-- (2026-09-24): round 1's note made it a support ("needs to act as support, think if more abilities"),
-- and round 2's gave it back its hands ("needs attacks of its own").
--
-- FOR THE LINE:
--   Gilder's Leaf  gold on a kinsman: +3 Defense for a step of movement (status_gilded) -- and, aimed the
--                  other way, gold on the company's front-liner as bait (`aimsEither`, round 3)
--   Grease Palms   spends its OWN coffer to Haste a kinsman. Whatever it spends is gone from the spoils
--   Transfusion    heals a kinsman out of its own health
-- AGAINST THE COMPANY (round 3, from the forge under the Mountain):
--   Molten Assay   a bolt of molten gold at range 4, +4 against a Gilded body
--   Gilding Brand  a thrown ingot: fire, and the target comes out Gilded -- coveted by every dwarf
-- An APOTHECARY (alchemist root), the house that treats its own with what it has.
--
-- Drops Gilder's Leaf.
return {
    name = "Dwarf Goldsmith",
    race = "dwarf",
    tier = 2,
    class = "alchemist",
    discipline = "apothecary",
    sprite = "assets/chars/dwarf_goldsmith.png",
    archetype = "support",
    coffer = 40, -- the leaf, and the float for the palms it greases
    stats = {
        health = 40, mana = 48, stamina = 14,
        staminaRegen = 2,
        damage = 6, magicDamage = 10,
        defense = 4, magicDefense = 8, -- 5 after the race
        movement = 5, -- 4 after the race
        speed = 4,
        skill = 5, luck = 4,
    },
    startingItems = {
        "weapon_iron_dagger",  "ability_gilders_leaf", "ability_grease_palms",
        "ability_transfusion", "ability_molten_assay", "ability_gilding_brand",
        false,                 false,                  false,
    },
    drops = { "ability_gilders_leaf" },
    defaultAction = "weapon_iron_dagger",
    signatureWeapon = "weapon_iron_dagger",
    ai = {
        { priority = "urgent", act = "support", item = "ability_transfusion", targetPref = "most_wounded",
          when = { subject = "any_ally", test = "hp_pct_below", value = 0.5 } },
        -- Mark the bait first: gild whoever the company has put in front, then the line goes for it.
        { priority = "high", act = "attack", item = "ability_gilding_brand", targetPref = "nearest",
          when = { subject = "any_foe", test = "lacks_status", value = "status_gilded" } },
        { priority = "high", act = "attack", item = "ability_molten_assay", targetPref = "gilded",
          when = { subject = "any_foe", test = "has_status", value = "status_gilded" } },
        { priority = "normal", act = "support", item = "ability_grease_palms", targetPref = "nearest",
          when = { subject = "any_ally", test = "lacks_status", value = "status_hasted" } },
        { priority = "normal", act = "support", item = "ability_gilders_leaf", targetPref = "nearest",
          when = { subject = "any_ally", test = "lacks_status", value = "status_gilded" } },
        { priority = "normal", act = "attack", item = "ability_gilders_leaf", targetPref = "nearest",
          when = { subject = "any_foe", test = "lacks_status", value = "status_gilded" } },
    },
}
