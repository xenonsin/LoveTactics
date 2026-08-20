-- Bulwark exemplar (knight subclass). Shove-lock: knockback that also Halts the displaced. Met as a
-- mentor/ally -- the Road-Captain shows it in its unlock quest, but that body
-- (character_greywatch_captain) is a story-disguised, encounter-tuned unit, so the discipline exemplar
-- is authored here with the full Bulwark kit. Kit from data/disciplines/bulwark.lua.
return {
    name = "Bulwark",
    kind = "humanoid",
    tier = 3,
    sprite = "assets/chars/bulwark.png",
    class = "knight",
    discipline = "bulwark",
    -- Taunts, then shoves attackers off the line and Halts them (models/ai.lua `defensive`).
    archetype = "defensive",
    stats = {
        health = 112, mana = 15, stamina = 18,
        staminaRegen = 2,
        damage = 15, magicDamage = 4,
        defense = 16, magicDefense = 8,
        movement = 4,
        speed = 3,
    },
    -- ONE plate, not two. The Halting Rank and the Unyielding Harness are each `movement = -2`, and
    -- worn together on a base of 4 they left the exemplar with none at all -- a wall that moves
    -- everyone else and cannot cross the room to be shoved past. The Rank is the one that stays: Halt
    -- is the discipline's own word (data/disciplines/bulwark.lua), so the plate that says it to a
    -- whole ring is the shove-lock stated as armour. The Harness was the better cuirass and the
    -- wrong one to spend the last two tiles on.
    startingItems = {
        "weapon_iron_mace",   "ability_push",   "ability_shout",
        "ability_closed_ring", "ability_stand_down", "utility_rooted_stance",
        "armor_halting_rank", false, "consumable_healing_potion",
    },
    defaultAction = "weapon_iron_mace",
    -- The two items that ARE this unit, in one glance: its weapon and its signature verb.
    -- Draft mode strips a bought body down to exactly these (models/draft_chassis.lua), so the
    -- rest of its kit is gear the player chose and read rather than nine inherited unknowns.
    signatureWeapon  = "weapon_iron_mace",
    signatureAbility = "ability_push",
    -- Shove the nearest attacker off the line; the knockback Halts it.
    ai = {
        { priority = "high", act = "cast", item = "ability_push",
          when = { subject = "any_foe", test = "within", value = 1 } },
        { priority = "normal", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
