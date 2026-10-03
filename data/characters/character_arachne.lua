-- ARACHNE: one of Envy's one-off families, on the waste's seat ("Envy's Bestiary", 2026-10-03, slice C). The weaver
-- who out-wove a goddess and was made into what she is for it.
--
--   THE TAPESTRY  every ability the company casts in her sight is woven, one thread on her tapestry (Woven). When
--                 one ability has 3 threads, she casts it back at whoever cast it, once (trait_the_tapestry)
--
-- THE COUNTERPLAY, STATED: vary your casts. A company that repeats its best spell is teaching it to her.
--
-- Gluttony has giant spiders, and she is not one of them: she is the weaver, not a beast of the pack. But her body
-- is a spider's below the waist, and of the races that exist the beast's is the honest one for it -- a creature,
-- whose kit is her own. Chitin turns a point; a club cracks it.
return {
    name = "Arachne",
    race = "beast",
    tier = 3,
    sprite = "assets/chars/arachne.png",
    stats = {
        health = 92, mana = 0, stamina = 28,
        staminaRegen = 4,
        damage = 11, magicDamage = 0,
        defense = 5, magicDefense = 6,
        movement = 4,
        speed = 4,
        skill = 7, luck = 4,
    },
    resist = { pierce = 3, impact = -3, poison = 2 },
    startingItems = {
        false,               false,                  false,
        "weapon_spinnerets", "utility_the_tapestry", false,
        false,               false,                  false,
    },
    defaultAction = "weapon_spinnerets",
    -- ITS OWN PIECE (docs/drops.md): a pattern, learned from a foe who repeats it.
    drops = { "utility_weavers_shuttle" },
    archetype = "aggressive",
}
