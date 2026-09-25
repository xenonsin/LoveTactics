-- The general of Greed. She holds the last stair of the Goldvein Deeps (Descent.SINS' greed `guardian`).
--
-- THE REDESIGN (settled over three rounds on 2026-09-25, artifact UtAAeXrYn5u9vGT48ejxpf, "Avaritia, the
-- Unspent"): an ELDER DRAGON on her hoard -- Smaug as the source, built as a raid fight. Aurea the debtor is
-- gone, and so is every story tie: nothing here claims she made the circle or anything in it. She is simply
-- what lies at the bottom of the deeps -- the dragon the kobolds' faith is about, and the sickness the
-- dwarves are named for.
--
-- HER FIGHT, BY HER HEALTH (her rules ride The Hoard in her centre cell; models/hoard.lua is the shared
-- machinery):
--
--   100 -> 60   ON THE HOARD. Heaps are laid round her at the bell. GILDED BELLY: +2 Defense and +2 Magic
--               Defense per heap within 2, lent to her side within 2. EVERY COIN COUNTED: each heap the
--               company takes is +2 Damage for her. DRAGONFIRE (the mage's own, the piece she drops): a
--               turn-long wind-up, a five-deep cone off her face that burns both sides and melts heaps to
--               Molten Gold -- and while it winds up she
--               rears, the belly is off, and every pierce blow is a critical (the Bare Scale). WING BUFFET
--               throws a foe beside her 2 at her turn start; TAIL SWEEP hits every foe around her.
--   60 -> 30    OVER THE DEEPS. She takes wing and STRAFES a whole row or column, telegraphed a turn ahead,
--               landing at its far end; where she lands the roof comes down on three marked tiles.
--   30 -> 0     THE MOUNTAIN BURNS. Every heap left melts at once, she stays on the ground at +25% damage,
--               and the lava spreads a tile every turn until the board runs out.
--
-- MOLTEN GOLD burns, and a body that ends a turn in it is Gilded -- and her fire goes for the gilded first.
-- Her kobolds keep walking in (a wave battle; `guardian.waves`), and her clutch of two eggs sits on the hoard.
--
-- WHAT HAPPENS BEFORE HER counts: two LEAD-INS on her floor (models/hoard.lua). The Burglary robs her
-- treasury -- every heap carried out is one fewer on her hoard, and one more stack she opens with. The
-- Shrine halves her procession and takes one of her eggs.
--
-- THE COUNTERPLAY, STATED: strip her heaps (and accept her anger for it); shoot the belly while she winds
-- up; don't crowd her; read the strafe line and the roof; stay out of the gold; and in the last third, be
-- quick.
--
-- What she hands over is Descent.DROPS.greed.general: the Gilded Belly relic, then her breath, her wings,
-- her gold, her ground and her sky.
return {
    name = "Avaritia, the Unspent",
    race = "dragon",
    tier = 4,
    -- WHAT LEVEL THESE NUMBERS WERE WRITTEN FOR. This body is authored as the fight it is at the end of its
    -- line, and models/growth.lua scales it DOWN toward the shallows rather than growing it up from a base.
    -- See Growth.spawn.
    referenceLevel = 13,
    boss = true, -- a quest objective: immune to execute (Coup de Grace) and to Charm
    sprite = "assets/chars/general_greed.png",
    portrait = "assets/portraits/general_greed.png", -- large VN portrait for conversations (falls back if missing)
    archetype = "aggressive",
    -- FOUR TILES (the Sated's footprint): she blocks all four, is struck from beside any of them, and takes
    -- one hit from an area blast rather than four.
    footprint = { w = 2, h = 2 },
    stats = {
        -- HEAVY AND SLOW, on review: the Belly is where her armour comes from, and it comes off in stages.
        health = 380, mana = 60, stamina = 40, -- mana for her breath (Dragonfire, off the mage shelf)
        staminaRegen = 4,
        damage = 20, magicDamage = 20,
        defense = 14, magicDefense = 10,
        movement = 3,
        speed = 3,
        skill = 8, luck = 4,
    },
    -- THE HIDE turns a blade and a club and lets a point through: the black arrow's weakness. Reviewed as
    -- +2 / +2 / -2; the bestiary holds a hide's physical three to a sum of zero, so the point finds -4.
    resist = { slash = 2, impact = 2, pierce = -4 },
    startingItems = {
        "weapon_tail_sweep", "ability_dragonfire", "ability_strafe",
        false,               "utility_the_hoard", false,
        false,               false,               false,
    },
    defaultAction = "weapon_tail_sweep",
    signatureWeapon = "weapon_tail_sweep",
    ai = {
        -- 1. Over the deeps, the strafe first -- through the gilded, if any of the company is.
        { priority = "high", act = "attack", item = "ability_strafe", targetPref = "gilded",
          when = { subject = "self", test = "has_status", value = "status_over_the_deeps" } },
        -- 2. The breath, whenever a foe is in reach of it -- the gilded first.
        { priority = "high", act = "attack", item = "ability_dragonfire", targetPref = "gilded",
          when = { subject = "nearest_foe", test = "within", value = 5 } },
        -- 3. Otherwise the sweep, into whatever is standing against her.
        { priority = "normal", act = "attack", item = "weapon_tail_sweep", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
