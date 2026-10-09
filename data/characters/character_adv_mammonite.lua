-- ADVENTURER: the race-free Mammonite a party fields ("The Rift's Adventurers", 2026-10-09). Fielded as
-- `character_adv_mammonite@<race>` (models/adventurers.lua); `race` below is only the class's first
-- leaning race, so the base blueprint loads. The rogue template with a point more armour.
--
-- HE BANKS COIN ON EVERY BLOW AND SPENDS IT (the Collectors). The Cutpurse's Coat pays him for each blow
-- he lands; The Open Account pays his wounds out of the purse; The Gilded Wound and Blood Money pour it
-- into damage; Grease Palms buys an ally tempo. An enemy spends its own `coffer`
-- (Combat.purseAvailable), and this one walks in with a small one -- traffic, not Aurea -- so the
-- purse he spends is mostly the purse he banked, which is why killing him early is the counter.
return {
    name = "Mammonite",
    race = "dwarf",
    tier = 2,
    adventurer = true,
    sprite = "assets/chars/mammonite.png",
    class = "rogue",
    discipline = "mammonite",
    archetype = "defensive",
    coffer = 60,
    stats = {
        health = 60, mana = 8, stamina = 24,
        staminaRegen = 2,
        damage = 14, magicDamage = 3,
        defense = 7, magicDefense = 6,
        movement = 4,
        speed = 5,
        skill = 7, luck = 7,
    },
    startingItems = {
        "weapon_iron_dagger",   "armor_cutpurse_coat", "ability_blood_money",
        "ability_gilded_wound", "ability_open_account", "ability_grease_palms",
    },
    defaultAction = "weapon_iron_dagger",
    signatureWeapon  = "weapon_iron_dagger",
    signatureAbility = "ability_open_account",
    -- The exemplar's three, in its order: open the books once, bill what is in reach, then the swing.
    ai = {
        { priority = "urgent", act = "cast", item = "ability_open_account",
          when = { subject = "self", test = "lacks_status", value = "status_open_account" } },
        { priority = "high", act = "attack", item = "ability_gilded_wound",
          when = { subject = "any_foe", test = "in_reach" } },
        { priority = "normal", act = "attack", item = "ability_blood_money",
          when = { subject = "nearest_foe", test = "within", value = 1 } },
    },
}
