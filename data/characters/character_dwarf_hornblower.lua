-- THE DWARF HORNBLOWER, rung 1: the horn of Erebor, "the dwarves came out". Picked on review in round 3
-- (2026-09-24) over an Iron Hills Shieldbearer, in the slot the Porter held until its strongbox was cut
-- ("I don't like the strong box idea").
--
-- A WARLORD (fighter root) -- the Warlord's is the house a banner belongs to. It plants the Banner of the
-- Mountain (dwarves within 2 tiles of it gain +2 Damage while it stands) and, once a fight, sounds the
-- horn (every dwarf on its side moves 1 more tile next turn). The banner decides where the line wants to
-- fight, and it is a priority kill. It wears the warlord's own Closed Ranks (+1 Damage per ally beside
-- it), the shelf piece a body claiming the discipline has to show (tests/bestiary_spec.lua).
--
-- Drops Fool's Gold (the drop round 2 approved for this slot).
return {
    name = "Dwarf Hornblower",
    race = "dwarf",
    tier = 1,
    class = "fighter",
    discipline = "warlord",
    sprite = "assets/chars/dwarf_hornblower.png",
    archetype = "aggressive",
    coffer = 20,
    stats = {
        health = 28, mana = 0, stamina = 22,
        staminaRegen = 3,
        damage = 9, magicDamage = 0,
        defense = 3, magicDefense = 3, -- 4 after the race
        movement = 5, -- 4 after the race
        speed = 3,
        skill = 5, luck = 4,
    },
    startingItems = {
        "weapon_iron_axe",        "ability_banner_of_the_mountain", "ability_sound_the_horn",
        "utility_closed_ranks",   false,                             false,
        false,                    false,                             false,
    },
    drops = { "ability_fools_gold" },
    defaultAction = "weapon_iron_axe",
    signatureWeapon = "weapon_iron_axe",
    ai = {
        { priority = "urgent", act = "cast", item = "ability_sound_the_horn",
          when = { subject = "any_foe", test = "exists" } },
        { priority = "high", act = "cast", item = "ability_banner_of_the_mountain",
          when = { subject = "any_foe", test = "exists" } },
        { priority = "high", act = "attack", targetPref = "gilded",
          when = { subject = "any_foe", test = "has_status", value = "status_gilded" } },
    },
}
