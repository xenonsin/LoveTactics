-- THE ADVENTURER BEASTMASTER ("The Rift's Adventurers", approved 2026-10-09; models/adventurers.lua).
-- A race-free body: fielded as `character_adv_beastmaster@<race>`; `race` is only the class's first
-- leaning race, so the bare blueprint loads.
--
-- Banner and Beast's beast is this body's wolf: one at the opening bell from the Whistle, and a second
-- called the moment there is room (Summon Wolf), kept standing by the Beastlord's Bond while the
-- beastmaster shoots from behind. The magic pair is the generic Archer's, which is what pays the wolf's
-- reservation.
return {
    name = "Beastmaster",
    race = "kobold",
    tier = 2,
    adventurer = true,
    class = "hunter",
    discipline = "beastmaster",
    sprite = "assets/chars/beastmaster.png",
    archetype = "skirmish",
    stats = {
        health = 56, mana = 15, stamina = 23,
        staminaRegen = 2,
        damage = 14, magicDamage = 3,
        defense = 5, magicDefense = 5,
        movement = 4,
        speed = 5,
        skill = 8, luck = 4,
    },
    startingItems = {
        "weapon_iron_longbow", "ability_summon_wolf", "utility_companion_whistle",
        "utility_beastlords_bond", "utility_hunting_horn", "armor_leather_armor",
        "consumable_healing_potion",
    },
    defaultAction = "weapon_iron_longbow",
    signatureWeapon = "weapon_iron_longbow",
    signatureAbility = "ability_summon_wolf",
    ai = {
        { priority = "high", act = "cast", item = "ability_summon_wolf",
          when = { subject = "self", test = "exists" } },
        { priority = "normal", act = "attack", item = "weapon_iron_longbow",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
