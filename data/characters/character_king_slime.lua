-- THE KING SLIME: the common body (data/characters/character_slime.lua) with more of it, and one
-- rule on top -- kill it and you have not taken it off the board, you have divided it.
--
-- Its fight is the slime's fight with a second half bolted to the end of it. The first half is the
-- rhythm the fen already taught: steel does nothing, an element lands once, and the body wears
-- whatever you last threw and throws it back. The second half is the health bar running out and
-- three more bodies standing up out of it (data/traits/trait_split.lua), each of which has never met
-- an element and will each take the first one it is shown.
--
-- WHICH MAKES THE WHOLE FIGHT ONE QUESTION: how many elements did you bring? A company with one
-- lands a single good blow on the King and then watches it become the wrong answer four times in a
-- row. A company with three walks through it. Nothing about that is a damage check -- the numbers
-- below are soft for a tier-4 body precisely because the fight must not also be a wall.
--
-- `boss = true` is the IMMUNITY MARKER, not the rung (docs/bestiary.md, tests/boss_framing_spec.lua),
-- and here it is load-bearing in a way it usually is not: Coup de Grace executes a body outright, and
-- an execution that skipped the split would delete the entire second half of the fight with one
-- button. Charm and Polymorph are the same argument -- a King that can be turned into a pig is a
-- King that never comes apart.
--
-- NOT AN `assassinate` MARK, and it must never be made one. That objective ends the fight the moment
-- the named body falls, which is exactly the moment this fight is designed to begin. It is fielded
-- under `killAll` (data/encounters/encounter_the_king_slime.lua), where the pieces have to be put
-- down too -- which is also why they are spawned as real bodies rather than conjurations, since a
-- summon would let the objective resolve over their heads (models/summon.lua).
--
-- HEALTH IS THE FIGHT'S RUNNING TIME, and here it is split across four bodies rather than banked in
-- one. 170 on the King and 24 on each of three pieces is 242 all told -- a tier-4 figure, spent so
-- that the last quarter of it arrives as a board state instead of as a bigger number. Raising the
-- King and cutting the pieces would make the split a formality; the reverse would make the boss a
-- doorway. Tier 4 claims 155+ (Balance.HEALTH_BANDS), and the King alone has to hold that band on its
-- own, because that is the body the rung is declared on.
return {
    name = "King Slime",
    race = "beast",
    tier = 4,
    boss = true,
    sprite = "assets/chars/king_slime.png",
    stats = {
        health = 170, mana = 0, stamina = 24,
        staminaRegen = 2,
        damage = 18, magicDamage = 0,
        -- As soft as the common body's, and for the same reason: the defence is categorical. A boss
        -- that was both un-cuttable AND armoured against the one answer would leave nothing to play.
        defense = 4, magicDefense = 3,
        movement = 3,
        speed = 3,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 5, luck = 2,
    },
    -- INNATE MITIGATION (models/character.lua `resist`) -- see the common body's file for why there is
    -- no physical line on a slime at all. The elemental trade is the same one, one rung deeper
    -- (Balance.INNATE_BUDGET allows 5 at tier 4).
    --   Acid is what it is FOR, and there is a great deal more of it in here.
    --   Cold still does not have to get through it. It only has to stop it moving.
    resist = { acid = 5, ice = -5 },
    -- Its loadout as the 3x3 grid (row-major; false = empty). One weapon and one relic, which is the
    -- boss shape docs/bestiary.md names outright -- "a boss's identity is machinery, not a shelf".
    -- The machinery is the Sovereign Mass: the same immunity the common body wears, plus the split.
    startingItems = {
        false, "ability_corrosive_touch", "ability_engulf",
        "weapon_pseudopod", "utility_sovereign_mass", false,
        false, false,                     false,
    },
    defaultAction = "weapon_pseudopod",
    -- WHAT IT IS KNOWN FOR (docs/drops.md), and it needs a list where a general does not: the seven
    -- circle bosses each pay an authored relic off Descent.DROPS, so tools/drop_assign refuses them on
    -- the grounds that two reward routes make the authored one a consolation prize. This body is on no
    -- circle's roster and has no such relic, so a list is its ONLY way of being known for anything.
    --
    -- The common body's fiction one rung up (see character_slime.lua): what comes back out is what the
    -- inside of it could not get through. The difference is VOLUME -- only a King is big enough to have
    -- had a whole suit of plate in it, and the maul the man was carrying when he went in.
    --
    -- THE CHASE IS THE ANSWER TO ITS OWN KIN, which is the oldest good loop there is: a slime takes
    -- `ice = -5` and the hammer is the thing that freezes. It does nothing to a slime that has already
    -- adapted to cold -- an immune hit is voided before its status is carried -- so it is a weapon for
    -- OPENING on slimes, not for grinding them, which is the same lesson the body taught in the fight.
    --
    -- Depths 4, 5, 6, 7 (Spoils.depthOf), one per rung, against an elite band that runs 3-4 where this
    -- body first appears and 7-8 at the bottom of the rift -- so every depth it can be met at has
    -- exactly one thing on this list to pay, and the deepest is unique.
    -- TWO OF THE FOUR ARE ITS OWN, and that is the change the borrowed list was missing: what a body
    -- is known for should be what it IS, not only what it ate. The Unbroken Surface is its first rule
    -- worn (proof against blades, points and blows -- for one opening turn), and the Quicksilver
    -- Mantle is its second (take an element, be proof against it, strike with it -- for one turn).
    -- Both are `unstocked`: they come off this body and nowhere else, and no counter will ever deal
    -- or buy one (docs/drops.md, Vendor.foundPrice).
    --
    -- The plate stays, because the volume gag is the fiction the common body's list runs on and the
    -- King is the only thing in the fen big enough to have had a whole suit in it. The hammer stays as
    -- the chase: it is the answer to its own kin, and at depth 7 it is the one entry deeper than the
    -- rest -- which by docs/drops.md's rule 7 is also the one that competes on equal terms with the
    -- house's other stock instead of carrying the body's preference. So the Mantle at 6 is what this
    -- body usually pays, and the hammer is what it is farmed for.
    --
    -- Depths 4, 5, 6, 7, one per rung: the elite band opens at 3-4 where the King is first met and
    -- reaches 7-8 at the bottom of the rift, so there is no depth it can be met at that pays nothing
    -- of its own (tests/slime_spec.lua measures exactly that).
    drops = {
        "utility_unbroken_surface",
        "armor_iron_plate",
        "armor_quicksilver_mantle",
        "weapon_frostfall_hammer",
    },
    -- Basic tactics (models/ai.lua): a slime still has no plan, and a crowned one has no plan either.
    -- It presses the body closest to falling, which is the only thing about it that reads as intent --
    -- and it is the rule that makes the split land where it hurts, since it dies standing over
    -- whoever it was working on.
    ai = {
        -- Take the weapon FIRST, on whatever it has caught up with: a disarm landed on turn one is
        -- worth every turn after it, and landed on the last turn is worth nothing.
        { priority = "high", act = "cast", item = "ability_engulf",
          when = { subject = "nearest_foe", test = "in_reach" } },
        -- ...then eat what it could not take away.
        { priority = "normal", act = "cast", item = "ability_corrosive_touch",
          when = { subject = "nearest_foe", test = "in_reach" } },
        -- Otherwise the common body's one instinct: press whoever is closest to falling.
        { priority = "normal", act = "attack", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "exists" } },
    },
}
