-- FROST WORM: one body, on Sloth's approach ("Sloth's Bestiary", 2026-10-04, slice C; from the D&D frost worm).
-- A white worm the length of a wagon train.
--
--   THE TRILL        every other turn it rears and trills: a wind-up shown as a ring of radius 4, and every body
--                    inside the ring when it lands, on either side, is Frozen (ability_the_trill)
--   ITS BITE         a plain bite (weapon_frost_worm_bite)
--   DEATH THROES     when it dies it bursts, and every body within 2 is Frozen (utility_rime_gut)
--
-- THE COUNTER, STATED, and it is the review's own: break the wind-up with hard control or a shove, or be outside
-- the ring when it lands. When it is low, finish it from 3 tiles away.
--
-- OFF SLEEP, ONTO THE ICE (the creature identity pass, 2026-11-19). The Trill used to put the ring to Sleep and
-- the bite Froze a sleeper; seven Sloth bodies laid or fed on Sleep, and this one did nothing with it the
-- Sandman does not. Now both its rules are Frozen, which has a second edge the company can use: Frozen bodies
-- take extra from impact and fire, and the Trill freezes the worm's own line too. Step out of the ring, then
-- bring the hammer down on whatever it iced beside it.
--
-- One tile, though the page calls it the length of a wagon train: a footprint would cost the lanes it fights in
-- and buy nothing the ring does not already say. A beast of the cold: it shrugs ice, the hide turns a club and
-- opens under an edge. It answered fire too until the identity pass varied the tundra's ice hides: the edge is
-- its answer now, where the Ice Elemental asks for the hammer.
return {
    name = "Frost Worm",
    race = "beast",
    tier = 3,
    sprite = "assets/chars/frost_worm.png",
    stats = {
        health = 118, mana = 0, stamina = 28,
        staminaRegen = 3,
        damage = 14, magicDamage = 8,
        defense = 6, magicDefense = 4,
        movement = 4,
        speed = 3,
        skill = 4, luck = 2,
    },
    resist = { ice = 4, impact = 3, slash = -3 },
    startingItems = {
        "weapon_frost_worm_bite", "ability_the_trill", "utility_rime_gut",
        false,                    false,               false,
        false,                    false,               false,
    },
    drops = { "ability_worms_trill" },
    defaultAction = "weapon_frost_worm_bite",
    archetype = "aggressive",
    -- A brute's appetite: it bites whatever is closest, and the ring does the choosing for everyone else.
    ai = {
        { priority = "normal", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "exists" } },
    },
}
