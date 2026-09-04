-- Enemy boss blueprint (quest objective). See data/characters/bandit.lua.
--
-- Dead, and so GRAVE-COLD (data/items/utility/utility_grave_cold.lua) like the raised: healing does not
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
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 4, luck = 0,
    },
    -- INNATE MITIGATION (models/character.lua `resist`), in the same unit an armour's resist
    -- table is written in and summed into the same total. This body wears nothing, so this is
    -- what it has instead of a coat -- and the negative line is not an oversight, it is the
    -- price. See docs/bestiary.md, "What a creature wears instead of armour".
    --   Only half here. A blade and a point both go through the half that is not.
    --   A hammer carries the weight of the arm behind it, and weight is what the mill remembers.
    resist = { slash = 4, pierce = 4, impact = -8 },
    startingItems = { "ability_fireball", "utility_grave_cold" },
    -- Basic tactics (models/ai.lua): press the wounded -- throw fire at the foe already closest to
    -- falling. (Fireball's own rule still handles aiming the blast off a cluster.)
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
