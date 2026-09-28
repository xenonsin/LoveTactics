-- FUROR, THE THOUSAND-ARMED: the general of Wrath, on the stair at the bottom of its circle (Descent.SINS).
-- Reviewed over two rounds on 2026-09-27/28 ("The Asura of Wrath"), and he replaced Ira, the Colosseum's
-- champion, whose story and two bodies went with her. New name, new story, no tie to the Colosseum.
--
-- WHO HE IS. The greatest ascetic there ever was. He sat in austerity longer than anyone has ever sat, was
-- granted strength for it, and spent every bit of it on war. He is what every monk is one broken vow from
-- becoming -- which is why the whole asura line fights with the monk's own shelf (models/asura.lua).
--
-- HIS FIGHT is everything the line taught, in one body:
--   * THE BROKEN VOW (his blood): chi fills when he is struck as well as when he strikes, it drains on a turn
--     he is left alone, and his stillness heats him (Tapas, on the Centering Charm's Gather).
--   * THE THOUSAND ARMS: he opens with four, and a pair grows at 4 chi and another at 8 -- one more landing on
--     every bare-handed blow per pair. They are never lost. What keeps him small is keeping him cold.
--   * EVERY ARM, his signature and his Burst: at a full pool he winds up and brings every arm down on the
--     nearest foe. The wind-up breaks if he is shoved or moved -- the rule every wind-up already has.
--   * THE BURNING HALO: foes beside him burn (and cannot see far enough to shoot).
--   * KEEN SENSES: he answers first, with every arm, and every landing is chi.
-- He stands with his Adepts and nobody else -- no waves (approved): fewer bodies, fewer ways to feed him.
--
-- 1x1. His grandeur is the halo and the arms, not the footprint.
return {
    name = "Furor, the Thousand-Armed",
    race = "asura",
    tier = 4,
    -- WHAT LEVEL THESE NUMBERS WERE WRITTEN FOR. Authored as the fight at the end of its circle and scaled
    -- DOWN toward the shallows by models/growth.lua (Growth.spawn), so a descent that deals Wrath early meets
    -- a smaller version of the same thing rather than an unkillable one.
    referenceLevel = 13,
    boss = true, -- immune to execute (Coup de Grace) and to Charm
    class = "priest",
    discipline = "monk",
    sprite = "assets/chars/general_wrath.png",
    portrait = "assets/portraits/general_wrath.png",
    archetype = "aggressive",
    stats = {
        health = 220, mana = 0, stamina = 30,
        staminaRegen = 5,
        damage = 16, magicDamage = 0,
        -- A little harder to magic than Ira was: the answer to him is not a burst of spells, it is keeping
        -- him cold, and then heavy hands when he is.
        defense = 10, magicDefense = 10,
        movement = 5,
        speed = 5, -- 6 after the race
        skill = 7, luck = 3, -- skill 8 after the race
    },
    startingItems = {
        "utility_thousand_arms",   "utility_iron_fist",       "ability_every_arm",
        "ability_flurry",          "ability_asura_strike",    "utility_centering_charm",
        "ability_keen_senses",     "utility_burning_halo",    false,
    },
    signatureWeapon = "utility_iron_fist",
    signatureAbility = "ability_every_arm",
}
