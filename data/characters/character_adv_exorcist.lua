-- THE ADVENTURER EXORCIST ("The Rift's Adventurers", approved 2026-10-09; models/adventurers.lua). A
-- race-free body: fielded as `character_adv_exorcist@<race>`; `race` is only the class's first leaning
-- race, so the bare blueprint loads.
--
-- Undoes what you built: Banish unmakes your summons, Dispel Illusions your hiding, Silence your caster.
-- Deliberately carries no Heal -- the exorcist is not on the sustain list, and a party that grows with
-- one must not quietly gain a second healer. Nothing on its shelf strips a foe's BUFFS or wards
-- (Stripped Bare's line), so that half of the page is reported as a gap rather than faked.
return {
    name = "Exorcist",
    race = "human",
    tier = 2,
    adventurer = true,
    class = "priest",
    discipline = "exorcist",
    sprite = "assets/chars/exorcist.png",
    archetype = "skirmish",
    stats = {
        health = 54, mana = 70, stamina = 12,
        staminaRegen = 1,
        damage = 5, magicDamage = 12,
        defense = 6, magicDefense = 13,
        movement = 4,
        speed = 3,
        skill = 3, luck = 6,
    },
    startingItems = {
        "weapon_censer", "ability_banish", "ability_silence",
        "ability_dispel_illusions", "utility_cleansing_ward", "armor_silk_robes",
        "consumable_healing_potion",
    },
    defaultAction = "weapon_censer",
    signatureWeapon = "weapon_censer",
    signatureAbility = "ability_banish",
    ai = {
        -- Banish scores nothing on a field with no summons, so this rule passes itself by.
        { priority = "high", act = "cast", item = "ability_banish",
          when = { subject = "any_foe", test = "exists" } },
        { priority = "high", act = "attack", item = "ability_silence",
          when = { subject = "any_foe", test = "lacks_status", value = "status_silenced" } },
    },
}
