-- Enemy boss blueprint (quest objective). See data/characters/bandit.lua.
--
-- Dead, and so GRAVE-COLD (data/items/utility/utility_grave_cold.lua) like the raised: mending does not
-- reach it, and a heal aimed at it wounds it instead. Nothing on its own side heals, so this changes no
-- fight it currently appears in -- it is here because the rule is about what a thing IS, and a rule that
-- only holds for the undead somebody remembered is not a rule.
return {
    name = "The Miller's Ghost",
    kind = "undead",
    tier = 3,
    boss = true, -- a quest objective: immune to execute (Coup de Grace) and to Charm
    sprite = "assets/chars/miller_ghost.png",
    -- A spellcaster with a full mana pool and no armor to speak of: it keeps its distance and throws
    -- fire, rather than drifting into a swordsman's reach (`skirmish`, models/ai.lua).
    archetype = "skirmish",
    stats = {
        health = 98, mana = 60, stamina = 13,
        damage = 8, magicDamage = 22,
        defense = 7, magicDefense = 14,
        movement = 4,
        speed = 4,
    },
    startingItems = { "ability_fireball", "utility_grave_cold" },
    -- Basic tactics (models/ai.lua): press the wounded -- throw fire at the foe already closest to
    -- falling. (Fireball's own rule still handles aiming the blast off a cluster.)
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
