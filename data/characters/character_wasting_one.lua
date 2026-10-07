-- WASTING ONE: one of Envy's kind, on the Ribstone Waste's approach ("Envy's Bestiary", round 4, 2026-10-06). From
-- Ovid's Envy (Metamorphoses II), pale and wasted, who never smiles except at another's pain. They come in packs.
--
--   THE THIN SMILE   every wound a body of the company takes where a Wasting One can see it heals every Wasting
--                    One that saw it, by 2 (trait_the_thin_smile; models/envy_oneoffs.lua)
--
-- THE COUNTERPLAY, STATED, and it is the review's own: fight them behind the ridges, so they see nothing, and kill
-- them before you trade blows with anything else. Area damage on them is clean; damage on you feeds them.
--
-- NOT THE VAMPIRES' BLOODSONG: that heals off damage its bearer deals. This heals off damage ANYONE deals to you, so
-- the trigger differs and the heal repeats. A demon, so its bite burns and it takes holy the harder.
return {
    name = "Wasting One",
    race = "demon",
    tier = 2,
    sprite = "assets/chars/wasting_one.png",
    stats = {
        health = 44, mana = 0, stamina = 24,
        staminaRegen = 3,
        damage = 10, magicDamage = 0,
        defense = 3, magicDefense = 4,
        movement = 5,
        speed = 5,
        skill = 6, luck = 3,
    },
    -- Skin over bone: an edge finds nothing to cut and a point slips between the ribs, but a club finds everything to
    -- break.
    resist = { slash = 2, pierce = 1, impact = -3 },
    startingItems = {
        "weapon_viper_fed_bite", "utility_smiles_at_pain", false,
        false,                   false,                    false,
        false,                   false,                    false,
    },
    drops = { "utility_the_thin_smile" },
    defaultAction = "weapon_viper_fed_bite",
    archetype = "aggressive",
}
