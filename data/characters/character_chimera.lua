-- THE CHIMERA: Gluttony's third seat-floor elite, and the first body in the game that takes more than one
-- turn. Pitched and reviewed in two rounds (2026-09-23, "The Chimera" artifact); every rule below is one a
-- line of that review approved.
--
-- ONE BODY, THREE MOUTHS, THREE CARDS ON THE STRIP. The lion is this 2x2 body. The goat and the serpent
-- are HEADS (Combat.spawnHeads): units of their own with their own turn, their own health and their own
-- one-item AI, grown at the bell by the two head items in this grid, standing on no tile and reading
-- their position through the body's. Asked for on review in so many words -- "can each head be
-- represented individually in the turn order?" -- and it is what lets one body keep pace with four: a
-- lone boss loses on action count, three mouths do not.
--
--   the lion     this body. Lion's Maw bites what is beside it, +4 on anything Burning.
--   the goat     a slow head. Goat's Breath: a cone of fire that sets Burn -- the lion's setup.
--   the serpent  a fast head. Coil: until its next turn, the first foe to strike the body in melee is
--                bitten and Poisoned (trait_serpents_strike).
--
-- A HEAD IS BROKEN BY KILLING IT, and it is aimed at, not found: a single-target blow on the body offers
-- Body / Goat / Serpent, a blow on a head does not touch the body, and an area blast covering the body
-- hits the body alone. A Stun on the body stops the lion only -- the heads are stunned by aiming at them.
-- When a head breaks the lion EATS IT (trait_eats_what_is_cut): it heals and is Gorged for a couple of
-- turns. And a mouth that finds nothing to do comes round sooner (status_starving).
--
-- THE COUNTERPLAY, STATED: spread out (the cone is 1-3-5 wide); Cure the Burn (the bite's +4 goes with
-- it); let the body that can best take a poison bite go in first (the tail answers once per coil); break
-- the goat and there is nothing burning; bring ice (-3), and not arrows (+3).
--
-- WHAT IT HANDS OVER is the fight rebuilt for a person: the lion's appetite as a Battlemage charm, and
-- the two heads themselves as the Beastmaster's -- a head you wear, with its own turn and its own mind.
-- A head's piece drops ONLY if that head was broken in the fight (Spoils, `onlyWhenBroken`): Monster
-- Hunter's part break, approved on review. Ordered shallow to deep, which within one list IS the rarity.
return {
    name = "Chimera",
    race = "beast",
    tier = 3,
    boss = true, -- off the execute and Charm tables, as every elite of the wood is
    sprite = "assets/chars/chimera.png",
    footprint = { w = 2, h = 2 },
    stats = {
        -- 128 against the White Wolf's 120 and the Larder Mother's 134. Damage 14, down from the pitched
        -- 16 on review, because three mouths take three turns.
        health = 128, mana = 0, stamina = 26,
        staminaRegen = 4,
        damage = 14, magicDamage = 0,
        defense = 8, magicDefense = 6,
        movement = 4, -- it does not chase; it holds the glade
        speed = 5,
        skill = 5, luck = 4, -- big, and easy to hit
    },
    -- A lion's mane turns an arrow; a fire in the belly turns a fire. Ice is the one element it fears.
    -- IMPACT -3 IS THE CONTRACT'S, not the review's: a hide is a redistribution (the physical lines sum to
    -- zero, docs/bestiary.md), so the arrow it turns is paid for by the hammer it does not.
    resist = { pierce = 3, impact = -3, fire = 4, ice = -3 },
    startingItems = {
        "weapon_lions_maw", "utility_chimera_goat", "utility_chimera_serpent",
        "utility_eats_what_is_cut", "utility_unfed_mouth", false,
        false, false, false,
    },
    drops = { "utility_hearth_hunger", "utility_serpent_head", "utility_goat_head" },
    defaultAction = "weapon_lions_maw",
    archetype = "aggressive",
    -- The lion presses whatever is burning or failing; the goat's cone and the serpent's coil are the
    -- heads' own turns, and their own items carry the rules that drive them.
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
