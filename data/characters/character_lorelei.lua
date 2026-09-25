-- THE LORELEI: the Siren's elite (tier 3), and the Siren plus exactly one sentence -- she sings THE ONLY
-- VOICE as well as Longing. Everyone who hears her gets nothing from their own side: no heal, no buff,
-- no cleanse (data/status/status_the_only_voice.lua). The Siren prices walking away from her; the
-- Lorelei prices being looked after.
--
-- SHE SINGS FROM HER ROCK and never leaves it (utility_lorelei_rock: `noMove`), and her song holds
-- through the first blow each battle (a Held Note) -- so the first arrow does not end it, the second one
-- does. The rock is where she is fought, not a ring of water the arena promises: boards are rolled, so
-- what is guaranteed is that she does not come to you.
--
-- Approved on review (2026-09-25) as "The Lorelei sings from a rock": a floor-three elite, fielded with
-- two Sirens and a Fen Lancer (encounter_the_lorelei_rock).
return {
    name = "The Lorelei",
    race = "demon",
    tier = 3,
    sprite = "assets/chars/lorelei.png",
    -- The Siren's trade at her rung: water off her, the storm through her, holy the harder.
    resist = { water = 4, lightning = -8, holy = -8 },
    stats = {
        health = 88, mana = 40, stamina = 16,
        damage = 6, magicDamage = 16,
        defense = 4, magicDefense = 8,
        movement = 0, -- she holds her rock: a sentry's 0, which is also what the rock's `noMove` says
        speed = 5,
        skill = 8, luck = 7,
    },
    startingItems = {
        "ability_siren_song",  "ability_brine_bolt",   false,
        "utility_sirens_tail", "utility_lorelei_rock", false,
        false,                 false,                  false,
    },
    -- WHAT SHE IS KNOWN FOR: her Only Voice worn as a presence, and her rock handed over.
    drops = { "utility_deaf_heart", "utility_held_note" },
    defaultAction = "ability_brine_bolt",
    signatureAbility = "ability_siren_song",
    archetype = "guard",
    ai = {
        { priority = "high", act = "cast", item = "ability_siren_song",
          when = { subject = "self", test = "lacks_status", value = "status_singing" } },
        { priority = "normal", act = "attack", item = "ability_brine_bolt",
          when = { subject = "any_foe", test = "lacks_status", value = "status_wet" } },
        { priority = "normal", act = "attack", item = "ability_brine_bolt", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
