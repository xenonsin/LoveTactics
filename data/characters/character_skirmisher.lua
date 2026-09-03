-- Skirmisher exemplar (fighter x hunter multiclass). Hit-and-run: reposition after a strike, and the
-- shot that does not close your move. Met as a raider outrider, a boss. Home shelf is hunter
-- (Harrier's Bow). Kit from data/disciplines/skirmisher.lua.
return {
    name = "Skirmisher",
    kind = "humanoid",
    tier = 3,
    sprite = "assets/chars/skirmisher.png",
    boss = true,
    class = "hunter",
    discipline = "skirmisher",
    -- Wants distance and buys it: strike, then use the free move to break contact (models/ai.lua).
    archetype = "skirmish",
    stats = {
        health = 108, mana = 8, stamina = 24,
        staminaRegen = 2,
        damage = 20, magicDamage = 4,
        defense = 9, magicDefense = 6,
        movement = 4,
        speed = 5,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 8, luck = 4,
    },
    startingItems = {
        "weapon_harriers_bow", "ability_harrying_strike",   "ability_running_shot",
        "utility_skirmishers_momentum", "armor_outriders_harness", "consumable_healing_potion",
        "utility_ground_given",                 false,                        false,
    },
    defaultAction = "weapon_harriers_bow",
    -- Strike whatever is in reach, then let the free move carry it clear.
    ai = {
        { priority = "high", act = "attack", item = "ability_running_shot",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
