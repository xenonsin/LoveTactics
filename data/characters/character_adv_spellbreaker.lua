-- SPELLBREAKER, as an adventurer ("The Rift's Adventurers", 2026-10-09; models/adventurers.lua). A
-- race-free body fielded as `character_adv_spellbreaker@<race>`; `race` names the first leaning race only
-- so the blueprint loads. Built on the generic knight (the root the exemplar walks): 15 / 4 magic.
--
-- WHAT IT DOES ON THE BOARD (The Shieldwall, Stripped Bare, The Long Invocation): it breaks a channel. A
-- Silence breaks any wind-up paid in mana (status_silenced's `interruptsChannel = "mana"`), so the turn a
-- foe starts winding up, Mana Sunder goes at it in reach and Null Field goes at it from three tiles --
-- once, on the knight's fifteen mana. The Silencing Blade Silences on every ordinary blow, and the
-- Dampening Oath doubles what a spell costs near it. Guard posture: it holds its ground, so a caster that
-- keeps back from it is out of its reach, which is the page's counter.
return {
    name = "Spellbreaker",
    race = "elf",
    tier = 2,
    adventurer = true,
    sprite = "assets/chars/spellbreaker.png",
    class = "knight",
    discipline = "spellbreaker",
    archetype = "guard",
    stats = {
        health = 68, mana = 15, stamina = 20,
        staminaRegen = 2,
        damage = 14, magicDamage = 4,
        defense = 11, magicDefense = 8,
        movement = 4,
        speed = 3,
        skill = 3, luck = 2,
    },
    startingItems = {
        "weapon_silencing_blade", "ability_mana_sunder", "ability_null_field",
        "utility_dampening_oath", "armor_chainmail",
    },
    defaultAction = "weapon_silencing_blade",
    signatureWeapon  = "weapon_silencing_blade",
    signatureAbility = "ability_mana_sunder",
    -- 1-2. A foe winding up is broken, in reach or from range. 3. Otherwise Silence what is beside it.
    ai = {
        { priority = "urgent", act = "attack", item = "ability_mana_sunder", targetPref = "channeling",
          when = { subject = "any_foe", test = "has_status", value = "status_channeling" } },
        { priority = "urgent", act = "attack", item = "ability_null_field", targetPref = "channeling",
          when = { subject = "any_foe", test = "has_status", value = "status_channeling" } },
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "nearest_foe", test = "in_reach" } },
    },
}
