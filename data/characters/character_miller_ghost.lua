-- Enemy boss blueprint (quest objective). See data/characters/bandit.lua.
return {
    name = "The Miller's Ghost",
    boss = true, -- a quest objective: immune to execute (Coup de Grace) and to Charm
    sprite = "assets/chars/miller_ghost.png",
    -- A spellcaster with a full mana pool and no armor to speak of: it keeps its distance and throws
    -- fire, rather than drifting into a swordsman's reach (`skirmish`, models/ai.lua).
    archetype = "skirmish",
    stats = {
        health = 98, mana = 60, stamina = 50,
        damage = 8, magicDamage = 22,
        defense = 8, magicDefense = 14,
        movement = 4,
        speed = 4,
    },
    startingItems = { "ability_fireball" },
    -- Basic tactics (models/ai.lua): press the wounded -- throw fire at the foe already closest to
    -- falling. (Fireball's own rule still handles aiming the blast off a cluster.)
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
