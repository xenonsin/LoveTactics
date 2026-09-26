-- THE REDCAP, rung 2: the goblins' assassin (round 2, 2026-09-26, "The Goblins of Wrath", on Keno's note: "needs
-- to be assassin class with different mechanic instead of rooted, crippled, shoved, etc.").
--
-- In the folklore a Redcap must keep its cap wet with blood, and if it dries, it dies. So: BLOOD SCENT -- it
-- blinks beside any foe below half health within 6, strikes, and blinks back -- and THE DRYING CAP -- every turn
-- it draws no blood costs it 10% of its health, and a kill heals it 25%. Two answers: keep the company above half
-- so it has nowhere to blink, or guard the wounded and let it dry out.
--
-- It carries both its drops: the Dipped Cap (kill, vanish, and a certain critical on the next wounded foe) and
-- its Pike (a kill heals), the second added on Keno's note. An assassin on the rogue table; elite band, so it
-- never cowers alone (trait_mob_courage).
return {
    name = "Redcap",
    race = "goblin",
    tier = 3,
    class = "rogue",
    discipline = "assassin",
    sprite = "assets/chars/redcap.png",
    archetype = "skirmish",
    stats = {
        health = 88, mana = 0, stamina = 26,
        staminaRegen = 4,
        damage = 13, magicDamage = 0,
        defense = 4, magicDefense = 4,
        movement = 5,
        speed = 5,
        skill = 9, luck = 6,
    },
    startingItems = {
        "weapon_redcaps_pike", "ability_blood_scent", "utility_drying_cap",
        "utility_dipped_cap",  false,                 false,
        false,                 false,                 false,
    },
    drops = { "utility_dipped_cap", "weapon_redcaps_pike" },
    defaultAction = "weapon_redcaps_pike",
    signatureWeapon = "weapon_redcaps_pike",
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
