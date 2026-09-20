-- THE MEANDERING STAG: the only thing in the rift that is trying to leave.
--
-- Every other apex closes on you. The Unseeing holds ground and makes boars; the White Wolf runs you
-- down at movement 6; the Sow walks at you because nobody does her closing. This one is prey with no
-- weapon at all, and the fight is what happens when a company corners something that had no interest
-- in them.
--
-- IT CANNOT HURT YOU. Not a weak attack -- none. `damage = 0`, no weapon in the grid, and
-- `unarmed = false`, which models/character.lua already understands as "a thing that can be moved
-- around the board but cannot strike anything, ever". For the whole first half of this fight the boss
-- takes nothing off anybody.
--
-- SO THE WOOD FIGHTS FOR IT, and the stag is the enemy HEALER (see encounter_meandering_stag.lua).
-- Nothing else in this bestiary is: the eight `support` bodies are all chaff and line. It runs between
-- the things that are actually fighting you, mending the ground under them by doing nothing but move.
-- Which gives the first half its decision -- race the stag down to stop the healing and reach the
-- second half with the pack still standing, or grind the pack first and let the stag write a longer
-- trail. Both roads cost, and neither is obviously right.
--
-- MOVEMENT 7, ABOVE EVERYTHING IN THE GAME (the White Wolf's 6 was the ceiling). That is not a threat.
-- It is the reason you cannot corner it with bodies: `archetype = "quarry"` spends every turn putting
-- ground between itself and whoever is nearest (models/ai.lua's flee move), and it prefers the longer
-- way among tiles that break the same distance -- which is the name, and which is also more trail.
--
-- WHAT CATCHES IT IS THE MAP, AND A JEER. The flee walk measures the crow's line rather than the road,
-- so a pocket reads as close however the walls run and the animal keeps to open ground: walls, water,
-- mire and the wall of the carve are what corner it. And AI.preempt sits above the posture, so Taunt
-- pulls it into reach -- where it arrives with nothing to do, which is exactly what a company wanted
-- when it jeered. A melee line is not locked out of this fight; it is given a herding problem.
--
-- 130 HEALTH, above the White Wolf's 120 and under the three apexes that stand and fight (the Sow 145,
-- the Unseeing 138, the Winter Hart 136). Half this bar belongs to a body that cannot attack, so it
-- should not price like a full apex.
--
-- THE MANA POOL IS NOT FOR THIS BODY AT ALL, and it is the one number here that only makes sense read
-- forward. The stag has no abilities and never spends a point of it. models/transform.lua carries the
-- resource pools across -- "KEPT FROM THE ORIGINAL -- the CONTINUITY" -- so this arrives at the second
-- half untouched and becomes the Vengeful Spirit's magazine: 60 against Swailing's 12 is five
-- detonations in a fight, and nothing in this game restores mana on its own. Five is chosen to sit
-- just above what the spirit's own tempo allows anyway, so mana is a backstop that binds in a long
-- fight while the thing that usually binds is the tile count -- which is the loop.
--
-- `boss = true` keeps it off the execute and Charm tables. It matters more here than usual: a Charmed
-- stag would lay healing ground for the party on purpose, which is the one thing the first half is
-- built to make ambiguous, and a Coup de Grace would skip the threshold outright.
return {
    name = "Meandering Stag",
    kind = "beast",
    tier = 3,
    boss = true, -- see the header: off the execute and Charm tables (tests/charm_balance_spec.lua)
    sprite = "assets/chars/meandering_stag.png",
    footprint = { w = 2, h = 2 },
    -- NO NATURAL WEAPON WHATSOEVER (models/character.lua's `unarmed = false`). Not an empty grid with
    -- fists behind it -- nothing. It is also what makes the Taunt answer read correctly: the compulsion
    -- finds no weapon and falls to its last branch, which walks the body to the taunter and stops.
    unarmed = false,
    stats = {
        health = 130, mana = 60, stamina = 20,
        staminaRegen = 3,
        damage = 0, magicDamage = 0, -- the absence of the field, not a low number
        defense = 6, magicDefense = 8, -- low for the rung: nothing here is built to take a blow
        movement = 7, -- the fastest thing in the game, so that it cannot be caught on foot
        speed = 8,    -- and it moves before almost anything, so the ground is laid before you act
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        --
        -- Skill 0 because it never rolls one: it has nothing to hit with. Luck 7 is the highest on the
        -- road and it is the same statement the movement makes -- an animal that has spent nine years
        -- not being caught by anything.
        skill = 0, luck = 7,
    },
    -- INNATE MITIGATION (models/character.lua `resist`), in the same unit an armour's resist
    -- table is written in and summed into the same total. This body wears nothing, so this is
    -- what it has instead of a coat -- and the negative line is not an oversight, it is the
    -- price. See docs/bestiary.md, "What a creature wears instead of armour".
    --   A lean animal at the end of a hard autumn: a point goes in and finds nothing worth finding,
    --   an edge does a little better, and anything with weight behind it goes straight through a
    --   frame that is mostly legs. The three sum to zero, as the doc requires.
    --   Nine winters stood through, and a dry beast in a dry wood. Elements are free of the sum.
    resist = { pierce = 3, slash = 1, impact = -4, ice = 4, fire = -4 },
    startingItems = { "utility_what_the_wood_owes_it" },
    -- WHAT IT IS KNOWN FOR (docs/drops.md). None of it is its own kit -- the hide and the ground it
    -- lays are `class = "creature"` and carry no axis at all, so the pool cannot mint them. These are
    -- the three things this fight IS, rebuilt as gear somebody could carry, ordered by depth, which is
    -- this system's rarity: the print you will see, the rule, and the chase.
    --
    -- Wellspring Sandals are re-homed rather than re-authored -- the trail-footwear this game already
    -- has, taken off the shelf and made this animal's (utility_wellspring_sandals.lua). They pay mana
    -- rather than health, which is better than a copy of the boss's own ground would have been.
    -- Three, not four. ROOTFAST -- regenerate and be immovable on a turn you did not move -- was
    -- approved and is NOT here: the engine has no seam for either half. `Combat.tilesMovedThisTurn`
    -- measures displacement from where the turn OPENED, so it reads zero for everybody at turn start
    -- and can only be asked at the wrong moment; and nothing anywhere refuses a shove. Both are small
    -- additions and neither is one to make quietly inside a content pass, so the slot is left open.
    drops = { "utility_wellspring_sandals", "utility_the_second_hound", "utility_swailing_brand" },
    -- No `defaultAction`: there is nothing to default to.
    --
    -- THE POSTURE IS THE WHOLE BEHAVIOUR, and there are no `ai` rules under it on purpose. `quarry`
    -- ships an empty rule list (escort's trick), so AI.plan finds nothing to fire and drops straight to
    -- the walk. A rule here would be a rule about fighting, and this body does not.
    archetype = "quarry",
}
