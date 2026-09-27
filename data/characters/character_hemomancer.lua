-- THE HEMOMANCER, rung 2 (Wrath's vampires, 2026-09-26). A human mage, and a vampire, whose spells cost blood: it
-- carries the Overdraft (`rules.manaToHealth`), so every cast is paid in health -- which it gets back by drinking.
--
--   OPEN VEINS     every foe in a 3x3 within 4 Bleeds, and every wound is the Hemomancer's to drink from
--   BOILING BLOOD  a bleeding foe within 4: its Bleed ends, and it takes 5 x the wound's magnitude as fire
--
-- A spell draws no blood, so a Hemomancer that only casts goes thirsty like any vampire -- until the ticks of the
-- veins it opened come back to it (Running Feeds It). It drops both spells.
return {
    name = "Hemomancer",
    race = "human",
    tier = 2,
    class = "mage",
    vampire = true,
    sprite = "assets/chars/hemomancer.png",
    archetype = "skirmish",
    stats = {
        health = 42, mana = 40, stamina = 10,
        staminaRegen = 2,
        damage = 4, magicDamage = 10,
        defense = 1, magicDefense = 6,
        movement = 4,
        speed = 4,
        skill = 6, luck = 5,
    },
    startingItems = {
        "weapon_staff",      "ability_open_veins", "ability_boiling_blood",
        "utility_overdraft", "ability_wing_swap",  "ability_feed",
        false,               false,                false,
    },
    drops = { "ability_open_veins", "ability_boiling_blood" },
    defaultAction = "weapon_staff",
    signatureWeapon = "weapon_staff",
}
