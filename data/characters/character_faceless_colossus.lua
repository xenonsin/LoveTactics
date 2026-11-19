-- THE FACELESS COLOSSUS, rung 2 and tier 3: a heap of the shapeless, 2x2 (reviewed 2026-10-01..03, "Envy's
-- Bestiary").
--
-- TWO FACES AT ONCE. A transform holds one shape, so the heap wears the face Reshape picks as its body -- that
-- face's name, stats and grid -- and the RUNNER-UP for the same read lends its whole kit into the cells the first
-- face leaves free (Two Faces, models/masks.lua). So it can be a troll with a naga's spells in its hands. A hand of
-- four, so there is a runner-up to lend; the heap keeps its own four tiles under every face.
--
-- IDENTITY LEVER (creature identity pass, 2026-11-19): ORDER, in time. Two random kits and no counter, said the
-- audit. Now reaching for the lent kit opens the seam between its faces (status_seam_open, until its next turn),
-- and the next blow that lands through it tears the second face off for the rest of the fight (trait_two_faces).
-- Hold a blow for the turn after it uses what it borrowed. And as every Faceless, an impact blow knocks its first
-- face off for a turn (Faces.knockOff) -- which takes the lent kit with it until it reads again.
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
    -- TARGETING: nearest, as the whole line does in its own body -- its faces were read off the nearest of the
    -- company, so the body they answer is the body it strikes when a blow has knocked them off.
    ai = {
        { priority = "normal", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "exists" } },
    },
}
