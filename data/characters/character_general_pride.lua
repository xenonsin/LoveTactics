-- SUPERBIA, THE MORNING STAR: the general of Pride, on the stair at the bottom of its circle (Descent.SINS).
-- Reviewed over three rounds ("Pride's Generals"), and she replaced Sublimitas, the Unequalled, on this blueprint
-- id -- the stair, the quests and the scene all name it. Sublimitas is not gone: she is her own body now
-- (character_sublimitas.lua), Pride's mini-boss, and the Codex Unanswered, the Rain, the necromancy and the
-- double went with her.
--
-- WHO SHE IS. A fallen archangel: the first and brightest of the choir, who would not kneel. The angels on the
-- spire are the ones who never fell, and they refuse what is laid on them (Incorruptible). She does not refuse.
-- She sends it back.
--
-- HER RULES, each on an organ of her own (bound, unstealable):
--   * NON SERVIAM (utility_non_serviam): a debuff laid on her rebounds onto whoever laid it, at full length, and
--     never touches her. Her wings ride on it too.
--   * LIGHT-BEARER (utility_light_bearer): a foe whose turn opens able to see her is Blinded until it ends.
--   * FLAWLESS FORM (utility_flawless_form): no single blow takes more than a tenth of her max health.
--   * THE HOST AND THE FALL (utility_the_host_and_the_fall): at two-thirds the Host descends -- two Reflections
--     of the Morning a turn -- and at one-third she falls: the Reflections shatter, she cannot fly, and Black Ice
--     spreads a ring a turn from where she landed, +2 Damage to her for every ring. Two turns ended on the ice in
--     a row, and a body is Frozen. models/morning_star.lua holds every rule.
--
-- AN ANGEL WITHOUT INCORRUPTIBLE. `raceGrants = false` keeps the race's organ out of her grid (the Paymaster's
-- flag, models/character.lua); she keeps the race's holy and dark lines, and her wings are on Non Serviam.
--
-- 2x2, and grand: the stair's last fight before the Crown.
--
-- What she pays (Descent.DROPS, wired by the stair): the Morning Star (mage, her relic), the Halo of the Morning
-- (crusader), Perfect Plate (knight), the Mirror of the Morning (summoner) and the Cocytus Wing (elementalist) --
-- every one a real class trophy, unstocked.
return {
    name = "Superbia, the Morning Star",
    race = "angel",
    raceGrants = false,
    tier = 4,
    -- WHAT LEVEL THESE NUMBERS WERE WRITTEN FOR. Authored as the fight at the end of its circle and scaled DOWN
    -- toward the shallows by models/growth.lua (Growth.spawn), as every general is.
    referenceLevel = 13,
    boss = true, -- immune to execute (Coup de Grace) and to Charm
    sprite = "assets/chars/general_pride.png",
    portrait = "assets/portraits/general_pride.png",
    footprint = { w = 2, h = 2 },
    archetype = "aggressive",
    stats = {
        -- 240 under a 24-a-blow cap: ten clean blows at the least, and the stages land on the eighth and the
        -- sixteenth wound if every one is the cap.
        health = 240, mana = 0, stamina = 30,
        staminaRegen = 5,
        damage = 14, magicDamage = 10, -- her spear is physical, so the Fall's +2 a ring lands in it
        defense = 10, magicDefense = 12,
        movement = 5,
        speed = 5,
        skill = 8, luck = 4,
    },
    startingItems = {
        "weapon_spear_of_the_morning", "utility_non_serviam",          "utility_light_bearer",
        "utility_flawless_form",       "utility_the_host_and_the_fall", false,
        false,                          false,                          false,
    },
    defaultAction = "weapon_spear_of_the_morning",
}
