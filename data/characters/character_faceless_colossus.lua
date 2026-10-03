-- THE FACELESS COLOSSUS, rung 2 and tier 3: a heap of the shapeless, 2x2 (reviewed 2026-10-01..03, "Envy's
-- Bestiary").
--
-- TWO FACES AT ONCE. A transform holds one shape, so the heap wears the face Reshape picks as its body -- that
-- face's name, stats and grid -- and the RUNNER-UP for the same read lends its whole kit into the cells the first
-- face leaves free (Two Faces, models/masks.lua). So it can be a troll with a naga's spells in its hands. A hand of
-- four, so there is a runner-up to lend; the heap keeps its own four tiles under every face.
--
-- It drops the Twofold Hauberk, on the bulwark's shelf.
return {
    name = "Faceless Colossus",
    race = "faceless",
    tier = 3,
    sprite = "assets/chars/faceless_colossus.png",
    footprint = { w = 2, h = 2 },
    faceHandSize = 4,
    stats = {
        health = 148, mana = 20, stamina = 26,
        staminaRegen = 3,
        damage = 14, magicDamage = 6,
        defense = 8, magicDefense = 6,
        movement = 3,
        speed = 1, -- a heap comes around the wheel slowly
        skill = 4, luck = 3,
    },
    startingItems = {
        "utility_two_faces", "weapon_iron_greatsword", "armor_twofold_hauberk",
        false,               false,                    false,
        false,               false,                    false,
    },
    drops = { "armor_twofold_hauberk" },
    defaultAction = "weapon_iron_greatsword",
    archetype = "aggressive",
    ai = {
        { priority = "normal", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "exists" } },
    },
}
