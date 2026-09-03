-- Barbarian exemplar (fighter subclass). Rage: damage climbs as its own HP falls, and some strikes
-- are paid for in blood. Met as a boss -- an arena berserker who fights harder the closer it is to
-- dying. Kit drawn from the Barbarian shelf (data/disciplines/barbarian.lua).
return {
    name = "Barbarian",
    kind = "humanoid",
    tier = 3,
    sprite = "assets/chars/barbarian.png",
    boss = true,
    class = "fighter",
    discipline = "barbarian",
    -- Walks straight at the enemy and hits the best thing it can reach (models/ai.lua `aggressive`).
    archetype = "aggressive",
    stats = {
        health = 132, mana = 5, stamina = 26,
        staminaRegen = 2,
        damage = 25, magicDamage = 4,
        defense = 10, magicDefense = 6,
        movement = 4,
        speed = 3,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 6, luck = 3,
    },
    startingItems = {
        "weapon_crimson_greataxe", "ability_fury",           "ability_desperate_strike",
        "ability_reckless_stance", "ability_culling_stroke", "utility_red_thirst",
        "utility_vampiric_strike", "armor_unspent_heart",    "utility_red_account",
    },
    defaultAction = "weapon_crimson_greataxe",
    -- The two items that ARE this unit, in one glance: its weapon and its signature verb.
    -- Draft mode strips a bought body down to exactly these (models/draft_chassis.lua), so the
    -- rest of its kit is gear the player chose and read rather than nine inherited unknowns.
    signatureWeapon  = "weapon_crimson_greataxe",
    signatureAbility = "ability_fury",
    -- The deeper the wound, the harder the swing: press the foe already closest to falling.
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
