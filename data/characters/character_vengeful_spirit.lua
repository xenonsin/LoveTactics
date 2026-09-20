-- THE VENGEFUL SPIRIT: what the stag becomes at half its blood, and the answer to the ground the party
-- let it lay.
--
-- Not a fight anybody enters -- no encounter fields this body. It is arrived at, once, through
-- utility_what_the_wood_owes_it's phase script (models/transform.lua: same unit, same tile, same health
-- bar, a new kit and a new sprite). The health carries across, so this half opens already spent: the
-- transform changes what it can do, never how much killing it takes.
--
-- THE INVERSION IS FLEE INTO HUNT, and it runs through the body rather than only the floor. The
-- Meandering Stag would not let you near it; this comes to you.
--
--   * `archetype` quarry -> aggressive. It presses whatever is closest to falling.
--   * movement 7 -> 6, speed 8 -> 6. It KEPT THE LEGS. That is the whole point and it is what makes
--     this different from the Unseeing's turning, which trades a wall for a walker; this trades a
--     runner for a hunter and the speed barely moves.
--   * a weapon, for the first time in the fight (weapon_deadfall), on a body whose damage stat was
--     literally zero ten seconds ago.
--   * Swailing, which is where the first half is spent (ability_swailing.lua).
--
-- AND THE POISONED BOARD IS ITS ROAD, WHICH NOBODY HAD TO DESIGN. It is immune to Blight (the hide
-- carries the immunity) and Blight is everywhere the stag ran -- so it crosses the board freely while
-- the party goes around. The trail laid running away from the company is the road it hunts them down
-- on. That falls out of two decisions made separately and is the best thing in the fight.
--
-- THE NUMBERS ARE THE SAME BODY WHERE THEY CAN BE. Health matches the stag's to the point, so the bar
-- does not jump when the animal does (the Turning's rule, and it is only a ceiling here -- the current
-- value is carried). The resist line is untouched for a stronger reason than convention: this is not a
-- second creature, it is the same lean animal with something else looking out of it, and a player who
-- had learned to answer it with a mace should not be told that lesson was about a body that no longer
-- exists.
--
-- MANA IS CARRIED, NOT DECLARED FRESH -- see character_meandering_stag.lua. The stag spends none of
-- its 60, so this opens with all of it: five Swailings, and nothing in this game gives mana back. The
-- pool is the hard ceiling on the detonations; the tiles the stag laid are the usual one.
--
-- 20 STAMINA AT 4, against Deadfall's 6: it swings most turns. Swailing costs mana rather than stamina
-- precisely so the two do not compete -- a spirit that had to choose between hitting and detonating
-- would spend the second half standing still, and the arrangement wanted is that it walks at you AND
-- sets the floor off while it comes.
--
-- `boss = true` as every centrepiece is.
return {
    name = "Vengeful Spirit",
    kind = "beast", -- the same animal. See the header on the resist line: nothing under it changed.
    tier = 3,
    boss = true, -- off the execute and Charm tables (tests/charm_balance_spec.lua)
    sprite = "assets/chars/vengeful_spirit.png",
    footprint = { w = 2, h = 2 },
    stats = {
        -- Carried across by the transform and never read off this line, so this figure only decides
        -- the ceiling the bar is drawn against. It matches the stag's exactly, which is the point.
        health = 130, mana = 60, stamina = 20,
        staminaRegen = 4,
        damage = 20, magicDamage = 0, -- a weapon it did not have, priced for a party that has only outlasted
        defense = 6, magicDefense = 8,
        movement = 6, -- it kept the legs
        speed = 6,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        --
        -- Skill 0 -> 4: it has something to hit with now, and it is not especially good at it. Luck
        -- drops from 7 to 5 for the reason the movement did -- it has stopped running, so it has
        -- stopped being hard to touch, and a party that could not land a blow all fight gets one.
        skill = 4, luck = 5,
    },
    -- INNATE MITIGATION (models/character.lua `resist`). Identical to the stag's, deliberately --
    -- see the header. The same lean frame, answered the same way.
    resist = { pierce = 3, slash = 1, impact = -4, ice = 4, fire = -4 },
    startingItems = { "weapon_deadfall", "ability_swailing", "utility_the_turned_year" },
    defaultAction = "weapon_deadfall",
    archetype = "aggressive", -- it comes to you, and the floor is on its side
    -- Basic tactics (models/ai.lua). Swailing's own `ai` block rides on the item and fires it; the rule
    -- here is the ordinary one every beast in this game carries. Nothing steers the detonation toward
    -- a particular tile and nothing should -- AI.scoreCandidate dry-runs the effect, sees zero on clean
    -- ground and a heal on any green that somehow survived, and picks the blight itself.
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
