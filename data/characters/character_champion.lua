-- Champion exemplar (fighter x knight multiclass), and the tough foe behind an `elite` encounter.
-- Riposte-wall: taunt the crowd, then counter every striker; Defiance banks per hit taken. Home shelf
-- is knight for the taunt, fighter for the reprisal. Kit from data/disciplines/champion.lua.
-- (Tests that use this body bare() its grid first, so the enriched kit below is safe.)
return {
    name = "Champion",
    kind = "humanoid",
    tier = 3,
    sprite = "assets/chars/champion.png",
    boss = true,
    class = "fighter",
    discipline = "champion",
    -- Holds the middle, provokes the crowd, and punishes each attacker (models/ai.lua `defensive`).
    archetype = "defensive",
    stats = {
        health = 96, mana = 20, stamina = 20,
        damage = 20, magicDamage = 6,
        defense = 0, magicDefense = 8,
        movement = 4,
        speed = 3,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 5, luck = 3,
    },
    startingItems = {
        "weapon_iron_greatsword", "ability_provoke",     "ability_defiant_stand",
        "ability_answering_blow", "utility_reprisal",    "utility_crowds_favour",
        "armor_bulwark_shield",   "consumable_healing_potion", "armor_crowds_due",
    },
    defaultAction = "weapon_iron_greatsword",
    -- The two items that ARE this unit, in one glance: its weapon and its signature verb.
    -- Draft mode strips a bought body down to exactly these (models/draft_chassis.lua), so the
    -- rest of its kit is gear the player chose and read rather than nine inherited unknowns.
    signatureWeapon  = "weapon_iron_greatsword",
    signatureAbility = "ability_provoke",
    -- Provoke the crowd onto itself, then let the reprisal answer every striker.
    ai = {
        { priority = "high", act = "cast", item = "ability_provoke",
          when = { subject = "any_foe", test = "within", value = 1 } },
        { priority = "normal", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
