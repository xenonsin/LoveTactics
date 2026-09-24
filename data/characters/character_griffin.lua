-- THE GRIFFIN: the hawk's elite, Keno's suggestion on the first round ("maybe introduce griffins as elite
-- versions"), reviewed over two rounds on 2026-09-23 ("The Sated and the Flight"). Its first pitch was
-- built on the flight's stealing and went with it; the second round drew five candidates from other
-- games, and three were approved:
--
--   ON THE WING          (Slay the Spire's Byrd) three stacks that halve every blow; each blow strips
--                        one; the last grounds it -- Stunned, and taking full damage for two turns --
--                        and then it takes wing again
--   ANSWERS EVERY BLOW   (Heroes of Might and Magic) it bites back at every melee blow, however many,
--                        for half its damage, and never pays for it
--   MATED FOR LIFE       (the legend) the Eyrie holds a pair; when one falls the other eats it and is
--                        Gorged for the rest of the fight
--
-- THE COUNTERPLAY, STATED: flurries ground it faster than one heavy swing, and the grounding is the
-- window to spend everything in. Reach it with a polearm, a bow or a spell rather than surrounding it --
-- every sword that closes gets bitten. And split the damage across the pair so they fall close together.
--
-- Sized under the wood's other elites (the White Wolf 120, the Chimera 128), since the Eyrie stands on the
-- first floor. A griffin's feathers turn an edge as the hawk's do, and a point finds it the same way.
return {
    name = "Griffin",
    race = "beast",
    tier = 3,
    boss = true, -- off the execute and Charm tables, as every elite of the wood is
    sprite = "assets/chars/griffin.png",
    stats = {
        health = 112, mana = 0, stamina = 24,
        staminaRegen = 3,
        damage = 15, magicDamage = 0,
        defense = 7, magicDefense = 5,
        movement = 6,
        speed = 5,
        skill = 5, luck = 5,
    },
    resist = { slash = 3, pierce = -3, wind = 3 },
    startingItems = {
        "weapon_beak_and_claw", "utility_griffin_wings", "utility_griffin_temper",
        false,                  false,                   false,
        false,                  false,                   false,
    },
    drops = { "utility_gorgers_beak", "utility_tithe_feather" },
    defaultAction = "weapon_beak_and_claw",
    archetype = "aggressive",
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
