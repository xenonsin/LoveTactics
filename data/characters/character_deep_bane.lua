-- THE THING UNDER THE SEAM: Greed's seat-floor elite, and the answer to the question the whole circle asks.
-- Approved over review rounds on 2026-09-26. The pitch, in so many words: "They dug too greedily and too
-- deep." Durin's Bane under Moria -- the dwarves struck something that was sleeping under the gold, and it
-- woke. A Balrog in all but name; nothing here names it, because the dwarves never did either.
--
-- ONE BODY, TWO BY TWO, AND ALONE. No escort: it is the fight, the way the Chimera is the fight in the
-- wood (encounter_greed_the_deep_bane). A demon, so what it swings burns -- every blow it lands carries
-- `fire` on a physical channel (docs/bestiary.md, "...and a demon's blows burn") -- and it takes holy the
-- harder, as every demon does.
--
--   Lash of Flame     its reach: three tiles, and it hauls what it catches the whole way to its side,
--                     Burning. Across ground nobody can walk, the lash carries the body over it.
--   Shadow and Flame  its heavy blow: a cone of fire three deep off the face of its body, wound up a turn
--                     ahead and marked on the board. A body left standing in it goes down.
--   What Was Sleeping its rules. Every tile it steps off burns for three turns; fire does not touch it
--                     (Emberwalk). And at HALF ITS HEALTH THE FLOOR FALLS AWAY: every tile exactly two
--                     from its body becomes a pit of fire, and it stands on an island.
--
-- THE COUNTERPLAY, STATED: bring ice (it is weak to it) and not fire; do not stand in the marked cone, and
-- do not stand anywhere its trail has been; do the melee work BEFORE half, because after the break a
-- blade has to leap the gap or be dragged across it -- and past that point the lash is how you get to it,
-- so a company with nothing that shoots can still finish the fight by letting it pull them in. Range and
-- reach work across the gap in both directions.
--
-- WHAT IT HANDS OVER is the fight rebuilt for a person: its lash as the Whip of Flame (a mace that drags a
-- body a tile and Burns it) and its shadow as the Shadow Mantle (nothing farther than three tiles can aim
-- at the bearer). Both unstocked trophies.
--
-- SLOW, on review: movement 2 and a late turn. It does not chase anyone; it walks toward you and the
-- ground behind it closes.
return {
    name = "The Thing Under the Seam",
    race = "demon",
    tier = 3,
    boss = true, -- off the execute and Charm tables, as every elite of the deeps is
    revivable = false, -- a demon does not go down and get up
    sprite = "assets/chars/deep_bane.png",
    -- FOUR TILES (the Chimera's and Avaritia's footprint): it blocks all four, is struck from beside any of
    -- them, takes one hit from an area blast rather than four -- and leaves two tiles burning every step.
    footprint = { w = 2, h = 2 },
    stats = {
        -- The top of the elite band, because it is the only body on its board: the Chimera carries three
        -- health bars into the glade and this carries one.
        health = 154, mana = 0, stamina = 34,
        staminaRegen = 5,
        damage = 18, magicDamage = 0,
        defense = 9, magicDefense = 7,
        movement = 2, -- slow; the lash is how it closes, not its feet
        speed = 4,
        skill = 6, luck = 3,
    },
    -- It came up out of the fire under the mountain: fire barely warms it, and the one thing it has never
    -- met is cold. The physical three are left at zero -- a hide of flame turns no blade in particular.
    resist = { fire = 4, ice = -4 },
    startingItems = {
        "weapon_lash_of_flame", "ability_shadow_and_flame", false,
        false,                  "utility_what_was_sleeping", false,
        false,                  false,                      false,
    },
    -- Its lash, rebuilt for a person (a mace: it displaces, and it displaces TOWARD you, as the Gathering
    -- Bell does); and its shadow, which nothing farther than three tiles can aim past (round 5). Shallow
    -- to deep, which within one list is the rarity.
    drops = { "weapon_whip_of_flame", "utility_shadow_mantle" },
    defaultAction = "weapon_lash_of_flame",
    archetype = "aggressive",
    ai = {
        -- 1. The heavy blow, whenever anybody is within the cone's three.
        { priority = "high", act = "attack", item = "ability_shadow_and_flame", targetPref = "nearest",
          when = { subject = "nearest_foe", test = "within", value = 3 } },
        -- 2. Otherwise the lash, into the weakest body it can reach.
        { priority = "normal", act = "attack", item = "weapon_lash_of_flame", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
