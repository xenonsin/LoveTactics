-- THE SIREN: Lust's fen (floors 3-4), and the one body on it whose threat is a SONG (2026-09-25, pitched
-- and approved over two review rounds).
--
-- SHE SINGS LONGING. Siren Song puts her into Singing (data/status/status_singing.lua): everyone who
-- hears her -- within four tiles, or Wet anywhere on the board, since sound carries over water -- is
-- filled with Longing (data/status/status_longing.lua), and every step they take away from her costs
-- them health. Lust owns four other ways to take a body (taunt, charm, drag, and the Fire Elemental's
-- bill for reaching); this one leaves the turn alone and prices RETREAT.
--
-- THE NAGA SET HER UP WITHOUT A LINE OF NEW AI. The Fen Lancer's spear and the Tidecaller's bolt soak,
-- and a soaked body hears her from across the mere -- so the lancer soaks, she sings to the soaked, and
-- the cheap way out is to walk in toward the channel the naga are standing in. She soaks as well (Brine
-- Bolt), which is what she does with a turn once the song is up.
--
-- THE ANSWERS, which is what makes it a mechanic rather than a tax: hit her (the song BREAKS on any
-- damage), kill her (the song ends with its singer), stay dry, or plug your ears (Beeswax, her own drop).
-- A company with a bow ends it from range; one made only of blades has to walk in -- toward her, which
-- is free.
--
-- FRAGILE, AND ON PURPOSE. A back-line caster at 34 health. UNCLASSED: she is a demon, and a demon has
-- no shelf (tests/bestiary_spec.lua), so she grows on the classless fallback that outpaces armour. She
-- swims -- her Tail is the Coils in a singer's body -- so the channels are her road. She neither roots
-- nor shoves, so she can stand in either half of Lust's rosters (tests/greed_lust_circle_spec.lua).
--
-- WHAT SHE IS MADE OF, as an innate table (she wears no armour): the water runs off her, and the storm
-- that runs through it is the thing she dies to -- the naga's own trade, so the Tidecaller's answer is
-- hers too -- and a demon takes holy the harder.
return {
    name = "Siren",
    race = "demon",
    tier = 2,
    sprite = "assets/chars/siren.png",
    resist = { water = 3, lightning = -6, holy = -6 },
    stats = {
        health = 34, mana = 30, stamina = 12,
        damage = 4, magicDamage = 12,
        defense = 2, magicDefense = 6,
        movement = 4,
        speed = 4,
        skill = 7, luck = 6,
    },
    startingItems = {
        "ability_siren_song",  "ability_brine_bolt", false,
        "utility_sirens_tail", false,                false,
        false,                 false,                false,
    },
    -- WHAT SHE IS KNOWN FOR (docs/drops.md): the wax that answers her, the comb that carries her voice,
    -- the rope a crew is lashed with, and the echo the mere gives back.
    drops = { "utility_beeswax", "utility_sirens_comb", "utility_mast_rope", "utility_echo" },
    defaultAction = "ability_brine_bolt",
    signatureAbility = "ability_siren_song",
    archetype = "skirmish",
    ai = {
        -- 1. Sing, whenever she is not. Everything else she does is worth less than the song, and a blow
        --    breaks it, so she is re-raising it after every hit that lands on her.
        { priority = "high", act = "cast", item = "ability_siren_song",
          when = { subject = "self", test = "lacks_status", value = "status_singing" } },
        -- 2. Soak somebody dry, so they hear her from anywhere.
        { priority = "normal", act = "attack", item = "ability_brine_bolt",
          when = { subject = "any_foe", test = "lacks_status", value = "status_wet" } },
        -- 3. And a bolt at whoever is closest to falling.
        { priority = "normal", act = "attack", item = "ability_brine_bolt", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
