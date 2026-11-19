-- A gilded page: the Pride circle's swarm, and worth nothing whatsoever alone.
--
-- That is the lesson, stated at the cheapest rung. Both halves of the rank rule read adjacency LIVE
-- (data/items/utility/utility_rank_and_file.lua), so a page standing with five others is armoured and
-- hitting properly, and the same page pulled into a doorway is a suit of armour with opinions.
--
-- ITS OWN JOB (the creature identity pass, 2026-11-19). The audit found the page and the sworn were one body at two
-- tiers -- the same pike, the same hide, the same nearest-foe rule -- and asked for two roles or one body. Two roles,
-- because eleven encounters and the Titan's chain field them apart. The sworn HOLDS: the pike, the plate, the line.
-- The page FETCHES: the Gilded Hook drags a foe within 2 in beside it, which is where the sworn's pikes reach, so
-- the place not to stand is two tiles off a page with a sworn at its back. And it is tin where the sworn is plate,
-- so the bring is different too -- a hammer for the pages, a spear for the line.
--
-- Tier 1's band is 1-30 health (Balance.HEALTH_BANDS).
return {
    name = "Gilded Page",
    race = "construct",
    tier = 1,
    sprite = "assets/chars/gilded_page.png",
    stats = {
        health = 22, mana = 0, stamina = 14,
        staminaRegen = 2,
        damage = 4, magicDamage = 0, -- almost nothing, until it is standing next to three of itself
        defense = 3, magicDefense = 2,
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
    --   Gilt over tin: an edge skates off the leaf.
    --   A hammer stoves it in like a pail. (Was the sworn's slash/pierce line until 2026-11-19. A pierce-proof page
    --   was tried first and measured a round longer on every gilded road fight -- tests/skirmish_spec.lua -- because
    --   the company's archer is its pierce. So the page keeps its turn against the blade and pays on the hammer.)
    resist = { slash = 2, impact = -2 },
    startingItems = { "weapon_gilded_hook", "utility_rank_and_file" },
    defaultAction = "weapon_gilded_hook",
    -- Basic tactics (models/ai.lua): `defensive` keeps it from breaking its own rank to chase, which is
    -- the one thing that would make the formation stop being a formation.
    archetype = "defensive",
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
