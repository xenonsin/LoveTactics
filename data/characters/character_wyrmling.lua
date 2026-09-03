-- A wyrmling: a wyrm that has not finished being one.
--
-- The brood is the point. One of these is a manageable nuisance -- a short cone, thrown from three
-- tiles, for line damage. Three of them standing apart cover three wedges of the board, and where the
-- wedges cross is the tile a party wants to stand on least. The combo needs no trait to express, only
-- a shape and a head-count (data/items/weapon/weapon_wyrmling_breath.lua).
--
-- NOT character_wild_wyrm, which is a shape a druid WEARS (Mira's bound relic) rather than a body that
-- fights as itself. Fielding a worn shape as an enemy is the same mistake the descent already makes
-- with character_dire_bear -- a Wild Shape whose pools are placeholders, standing as Gluttony's
-- honour-guard lead with one health. A body used as both cargo and combatant has to be SPLIT, so this
-- is its own blueprint and the druid's wyrm stays hers.
--
-- Tier 2's band is 31-80 health (Balance.HEALTH_BANDS, pinned by tests/bestiary_spec.lua). Sits low in
-- it: a wyrmling should die to a committed turn, because the answer to a brood is to thin it.
return {
    name = "Wyrmling",
    kind = "beast",
    tier = 2,
    sprite = "assets/chars/wyrmling.png",
    stats = {
        health = 44, mana = 0, stamina = 20,
        staminaRegen = 2,
        damage = 8, magicDamage = 11, -- the breath is what it is for; the claws are an afterthought
        defense = 5, magicDefense = 6,
        movement = 4,
        speed = 4,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 4, luck = 5,
    },
    startingItems = { "weapon_wyrmling_breath" },
    defaultAction = "weapon_wyrmling_breath",
    -- Basic tactics (models/ai.lua): keeps its distance and breathes. `skirmish` is the archetype that
    -- holds a gap rather than closing, which is what makes the overlapping cones happen at all -- a
    -- brood that charged would stack into one wedge and stop being a geometry problem.
    archetype = "skirmish",
    ai = {
        { priority = "high", act = "attack", item = "weapon_wyrmling_breath", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
