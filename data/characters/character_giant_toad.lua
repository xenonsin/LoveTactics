-- THE GIANT TOAD: Gluttony's seat-floor ambusher, and the one animal in the wood that EATS YOU ALIVE.
-- Designed on review 2026-09-25 ("The Giant Toad" artifact), to widen floor two's own stock, which was
-- two wyvern fights, the manticores, the spiders and the moss slimes.
--
-- THE LOOP, and every rule below is one the review settled:
--   Toad Legs     it never walks: every move is a hop of up to 3 over anything, 8 stamina a hop, so it
--                 moves at 0 movement and a meal costs it no mobility
--   Tongue Pull   the knight's Pull on a tongue, and it grounds a flier -- it fetches what it means to eat
--   Tongue Lash   its basic attack: reach 2, Poison
--   Swallow       a foe beside it goes down whole; while it is inside, the toad is heavily Full
--                 (+6 damage, +6 defense, +4 magic defense) and every digestion tick heals it
--   Leaping Crash the fighter's leap, kept as its landing hit -- from the same stamina the hop spends
--   Spit          3-4 tiles, Mired: what it does when nothing is in reach, and what makes you reachable
--
-- THE COUNTERPLAY, STATED: hit it hard (a quarter of its health in one blow spits the meal back out, and
-- the Full with it), stun it, or kill it; keep a tight line so its hop has nowhere to land beside the
-- healer; stand out of its sight for the Pull; and Cure the tongue's poison. The heavy hitter's job on this
-- fight is to empty the toad, which is a different job from killing it.
--
-- ITS HIDE is soft and wet: a mace sinks in and finds nothing to break, and an edge opens it.
return {
    name = "Giant Toad",
    race = "beast",
    tier = 2,
    palate = "ability_tongue_pull", -- what Gula takes when she eats one (models/palate.lua): she fetches her meals
    sprite = "assets/chars/giant_toad.png",
    stats = {
        -- 30 at 4: a hop (8) and a lash (4) most turns, a hop or a Crash (12) but rarely both.
        health = 70, mana = 0, stamina = 30,
        staminaRegen = 4,
        damage = 13, magicDamage = 0,
        defense = 5, magicDefense = 3,
        movement = 0, -- it hops (utility_toad_legs); the walk is not how it gets anywhere
        speed = 3,
        skill = 3, luck = 4,
    },
    resist = { impact = 3, slash = -3 },
    startingItems = {
        "weapon_tongue_lash", "ability_swallow", "ability_tongue_pull",
        "ability_leaping_crash", "ability_toad_spit", "utility_toad_legs",
        false, false, false,
    },
    -- Its hop for the one who walks too much, and its swallow for the one who eats. Shallow to deep.
    drops = { "utility_bog_hopper_greaves", "ability_the_gullet" },
    defaultAction = "weapon_tongue_lash",
    archetype = "aggressive",
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
