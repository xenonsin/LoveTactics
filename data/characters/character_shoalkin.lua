-- THE MERE, rung 1 (docs/nagas.md, docs/bestiary.md): the chaff a naga pack is made of.
--
-- BODIED CHAFF, which is the half of the bestiary's outfitting rule that makes a faction read as an
-- army rather than a spawn list. It carries a priced, lootable knife off a shelf and drops it; the
-- creature half of the rule -- natural weapons only -- belongs to the wolves and the maws, and a naga
-- is somebody. What it does NOT carry is its own legs: data/races/naga.lua grants the coils, so this
-- blueprint never mentions swimming and the fifth naga anybody writes cannot forget to.
--
-- ITS WHOLE JOB IS TO BE ALREADY IN THE WATER when you arrive. A faction whose identity is the ground
-- it chose needs bodies standing on that ground before the fight starts, and chaff is the cheapest way
-- to say so -- five of these in a channel is a statement about the board that no elite could make
-- alone. Chaff is also the commonest hole in this bestiary; the Mere ships with its own.
--
-- `class = "rogue"` is honest and very slightly costly: the rogue table grows damage +2 a level against
-- an enemy scaling of +3, so a level-20 Shoalkin lags by one a level. That is affordable on a body with
-- 26 health that dies to a stiff breeze, and it is not affordable on a line body -- which is why the
-- Fen Lancer beside it declares `fighter` instead. See docs/nagas.md for the table.
--
-- The knife is the whole kit, and the grid is deliberately loose: the race takes a cell, and an author
-- who fills all nine on a naga will find out the hard way (tests/race_spec.lua counts).
return {
    name = "Shoalkin",
    race = "naga",
    tier = 1,
    class = "rogue",
    sprite = "assets/chars/shoalkin.png",
    stats = {
        health = 20, mana = 0, stamina = 14,
        damage = 10, magicDamage = 0,
        defense = 2, magicDefense = 2,
        -- 4, which the race takes to 3: a naga on dry stone is slower than the men it is fighting.
        movement = 4,
        speed = 4,
        skill = 5, luck = 4,
    },
    startingItems = {
        "weapon_silt_knife", false, false,
        false,               false, false,
        false,               false, false,
    },
    drops = {
        "armor_unlit_hood",
        "utility_gluttons_purse",
        "utility_skimmers_cut",
        "utility_still_hungry",
        "armor_breakers_harness",
    },
    defaultAction = "weapon_silt_knife",
    signatureWeapon = "weapon_silt_knife",
    ai = {
        -- Straight at whoever is closest to falling. A Shoalkin has no plan; the plan is that there are
        -- five of them and the Lancer behind them is working the same bank.
        { priority = "normal", act = "attack", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
