-- GULA, THE APEX: the beast the huntress turns into at half her health (data/traits/trait_turning_hunger.lua).
--
-- The same unit in a different body (models/transform.lua): her health, her place in the turn order and
-- everything she had eaten carry across; her kit and flat stats are this blueprint's. Health below is
-- ignored on transform, as Ira's second body documents.
--
-- WHAT CHANGES IS HOW SHE EATS. The huntress holds one power and loses it to a hard blow; the beast
-- declares no `palateCapacity`, so it KEEPS everything it eats, eating a kind it already holds raises that
-- power a forge level, and nothing knocks any of it out (models/palate.lua). Settled on review
-- 2026-09-23: "she can constantly devour to heal and upgrade her obtained items. They can't be knocked
-- out." So the second half of the fight is a race against the beasts still walking in to feed her.
--
-- AND IT DRAWS BREATH (ability_the_breath): too slow to walk to its food, it pulls the food to it, and
-- swallows what arrives already beaten -- which is the part of the fight the company can read a turn ahead
-- and answer by leaving the band, standing behind a body, or standing Rooted in the web on purpose.
--
-- ONE TILE, NOT TWO BY TWO. The review page drew it as a 2x2 body; a transform exchanges the character
-- but not the board footprint the unit was placed with (Combat.addUnit stamps w/h once), and growing a
-- body into occupied cells mid-fight is a collision problem nothing in the engine answers yet. At one tile
-- the Breath's band is the three-wide, four-deep one first pitched.
return {
    name = "Gula, the Apex",
    race = "beast",
    tier = 4,
    referenceLevel = 13,
    eats = true, -- takes the power of what it eats, and keeps all of it (no `palateCapacity`)
    boss = true, -- still the stair's mark past the swap: immune to execute and to Charm
    revivable = false,
    archetype = "aggressive",
    sprite = "assets/chars/gula_the_apex.png",
    portrait = "assets/portraits/general_gluttony.png",
    stats = {
        health = 240, mana = 0, stamina = 30, -- health is ignored on transform (the pool carries across)
        staminaRegen = 4,
        damage = 22, magicDamage = 0,
        defense = 13, magicDefense = 5, -- thinner against magic than she has ever been: bring a caster
        movement = 3, -- slow; the Breath brings you to her
        speed = 3,
        skill = 6, luck = 3,
    },
    -- What it wears instead of armour (docs/bestiary.md), and a hide is a trade: every beast in the wood has
    -- tried its teeth and claws on it, and not one of them ever brought a club. Fire is the one thing a beast
    -- that never learned magic still fears.
    resist = { slash = 2, pierce = 2, impact = -4, fire = -3 },
    startingItems = {
        "weapon_rending_maw",   "ability_devour", "ability_the_breath",
        "utility_hunters_read", false,            false,
        false,                  false,            false,
    },
    defaultAction = "weapon_rending_maw",
    ai = {
        { priority = "normal", act = "attack", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "exists" } },
    },
}
