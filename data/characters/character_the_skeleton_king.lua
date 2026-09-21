-- THE SKELETON KING: the crown at the bottom of the barrows, and the last thing this line of bodies has
-- to say.
--
-- ITS OWN BODY, AND THE ONLY ONE IN THE ORCHARD THAT IS. Everything else down here extends a living
-- blueprint -- the dead are the companies that came before yours, wearing what happened to them
-- (data/characters/character_skeleton_knight.lua). The King is not one of those companies. He was here
-- when they arrived, and the difference is meant to read on the tile before he has taken a turn: he is
-- the one silhouette on that board the player has never seen alive.
--
-- THE FIGHT, and it is the third time the game asks one question:
--
--     WHAT DOES IT TAKE TO PUT THIS DOWN?
--
--   * The common dead do not rise. The answer is a WEAPON -- a mace, for a lattice that slips edges.
--   * The Barrow Lord rises on its own mana, twice. The answer is a BAR -- and that fight exists to
--     teach a player to stop watching the red one.
--   * The King rises on his COURT (data/traits/trait_court_of_bone.lua). His mana is not a resource, it
--     is a headcount: thirty for every subject still standing, and thirty is exactly what one rise
--     costs. So the blue bar the player has already learned to read now says how many bodies are left,
--     and the fight states itself without a word:
--
--         EMPTY THE ROOM, THEN KILL THE KING.
--
-- AND HE FILLS THE ROOM BACK UP. Call the Court (data/items/ability/ability_call_the_court.lua) puts two
-- more subjects on his flanks, on a cooldown, as a TELEGRAPHED cast -- so the clearing is not a chore
-- with a known end, it is a race against a clock the player can see and can choose to spend a turn
-- denying. That is the whole rhythm: clear, watch the bar fall, and put him down inside the window
-- before the next call, with the King's own spear holding you a tile off while you try.
--
-- IT IS NOT A LOCK, and the trait file argues this at length rather than hiding it: between two deaths
-- the pool does not refill, so a company that ignores the court entirely can grind three whole bars
-- instead. Five times the damage for the stubborn line, and the clever line is cheaper. Both work,
-- neither is announced.
--
-- THE MACE IS STILL THE ANSWER, at the tier-4 budget, which is what keeps three bars from being a wall:
-- a party carrying the weapon the orchard has been arguing for since floor three takes him apart, and a
-- party carrying four swords finds out -- one last time, expensively -- why it should have listened.
return {
    name = "The Skeleton King",
    race = "undead",
    tier = 4,
    boss = true,
    sprite = "assets/chars/the_skeleton_king.png",
    stats = {
        -- Tier-4 band (Balance.HEALTH_BANDS: 155+), and near its floor on the King Slime's argument:
        -- this body is several of these bars, so pricing it high would turn a rule into a chore.
        health = 172,
        -- THE CEILING, not the pool. Court of Bone writes `current` every time anything dies, so what
        -- this number does is cap the court at four standing subjects' worth -- a fifth body on the
        -- board buys him nothing, which is what stops a lucky call from putting the fight out of reach.
        mana = 120,
        stamina = 26,
        staminaRegen = 2,
        damage = 20, magicDamage = 0,
        -- The mail rotted off him with everything else; the innate line below is what he has instead.
        -- Deliberately not also armoured: a body that was both un-cuttable AND armoured against the one
        -- answer would leave nothing to play (the King Slime's file makes the same argument).
        defense = 6, magicDefense = 4,
        movement = 4,
        speed = 4,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 7, luck = 2,
    },
    -- INNATE MITIGATION (models/character.lua `resist`) -- see character_skeleton_knight.lua for the
    -- argument. The same lattice the whole orchard wears, at the tier-4 budget
    -- (Balance.INNATE_BUDGET allows 5; the weakness cap is twice that).
    --   Edges and points pass through the gaps they were already aiming for.
    --   The frame pays for both, in full, so the three lines sum to zero (Balance.INNATE_PHYSICAL).
    --   And the Cathedral was right about the dead, at the tier-4 weakness cap.
    resist = { slash = 5, pierce = 5, impact = -10, holy = -10 },
    -- Its loadout as the 3x3 grid (row-major; false = empty). The crown in the centre where a bound
    -- relic goes, the reach beside it, the court on call, and the two standing facts of being a
    -- skeleton. Every one of them is `class = "creature"` -- unpriced, noSteal, on nobody's shelf --
    -- which is the whole of what separates the King's version of the rule from the one the player earns.
    startingItems = {
        false,                    "ability_call_the_court",   false,
        "weapon_the_kings_reach", "utility_the_barrow_crown", false,
        "utility_grave_cold",     "utility_bare_bones",       false,
    },
    defaultAction = "weapon_the_kings_reach",
    -- WHAT HE IS KNOWN FOR (docs/drops.md). He sits on no circle's roster, so an authored list is his
    -- only route to paying anything -- the King Slime's argument, one barrow over.
    --
    -- The crown itself is NOT on it and cannot be: it is `bound`, which is the line tools/drop_assign
    -- refuses on by definition, and a player holding Court of Bone would be a player whose own body
    -- cannot be killed while a summon stands. What the King pays instead is the OTHER half of his own
    -- fight -- the hammer that answers a frame, and the plate that answers his reach.
    drops = {
        "weapon_frostfall_hammer",
        "armor_iron_plate",
    },
    -- Basic tactics (models/ai.lua): he presses whoever is closest to falling, like the Lord and the
    -- crowned slime before him, and for the reason that rule keeps earning -- a body that dies standing
    -- over the party's weakest is a body that gets back up there.
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "exists" } },
    },
}
