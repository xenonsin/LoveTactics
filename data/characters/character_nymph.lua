-- A NYMPH: the first rung of the Dryad line, and the Lust circle's MOVE half at its most slippery.
--
-- WHAT SHE IS, IN THE FICTION. The yew over the Cathedral's pit was cut, long ago, for the keep's rood
-- beam and roof timbers, and the wood kept what it had drunk. The nymphs are the small green things that
-- come out of it -- fae casters, never where you left them.
--
-- FOUR SPELLS AND NO BLOW. She plants (weapon_seedfall: a sapling, a small blocking plant), steps between
-- plants (weapon_greenstep: into the grove and out beside the plant farthest from every foe), lights a
-- foe for somebody else's shove (weapon_mistlight: the next knockback throws it a tile further), and
-- mends her own (weapon_springwater: a heal and a turn of Haste).
--
-- SHE WAS DRAFTED STEPPING BETWEEN WALLS, and a fight board is eight by eight with a few blockers on it.
-- So the line grows its own grain (models/grove.lua): what she steps between is what she planted.
--
-- ALONE SHE IS A NUISANCE; BESIDE A HARPY SHE IS A PROBLEM. That pairing is what the Dryad line is in the
-- Move half of the circle for: nothing in it roots, so it shares its fights with the flock and the
-- succubi, and never with a rooter (Descent.SINS' Lust entry).
--
-- Tier 1's band is 1-30 health (Balance.HEALTH_BANDS). Near the top of it: a caster that has to live
-- long enough to have planted something.
return {
    name = "Nymph",
    race = "demon",
    tier = 1,
    sprite = "assets/chars/nymph.png",
    archetype = "skirmish",
    stats = {
        health = 24, mana = 32, stamina = 10,
        staminaRegen = 2,
        damage = 4, magicDamage = 9,
        defense = 3, magicDefense = 7,
        movement = 5,
        speed = 4,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 8, luck = 9,
    },
    -- INNATE MITIGATION (docs/bestiary.md). Green wood turns an edge and splits under a maul; she is a
    -- spring before she is anything else, so water finds nothing to take. The blood is Luxuria's.
    resist = { slash = 2, impact = -2, water = 2, holy = -2 },
    startingItems = { "weapon_mistlight", "weapon_seedfall", "weapon_greenstep", "weapon_springwater" },
    -- WHAT SHE IS KNOWN FOR (docs/drops.md), rarest first: the light; then the planting and the step,
    -- which are the druid shelf's grove beginning.
    drops = {
        "ability_mistlight",
        "ability_seedfall",
        "ability_greenstep",
    },
    defaultAction = "weapon_mistlight",
    ai = {
        -- She plants before anything else: without a grove there is nowhere for Greenstep to go.
        { priority = "high", act = "cast", item = "weapon_seedfall",
          when = { subject = "any_foe", test = "within", value = 6 } },
        { priority = "normal", act = "attack", item = "weapon_mistlight", targetPref = "nearest",
          when = { subject = "any_foe", test = "lacks_status", value = "status_mistlit" } },
    },
}
