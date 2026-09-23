-- A LAMIA: the Lust circle's second line body, and the one that says you cannot leave.
--
-- THE CIRCLE FIELDS TWO ANIMALS AND THEY ARE OPPOSITE HALVES OF ONE RULE. A harpy decides where your
-- body is -- it hauls you in and drives you off, and neither blow is worth much alone
-- (data/characters/character_harpy.lua). A lamia decides that it does not get to be anywhere else.
-- Neither of them can kill a company. Together they are a company that spends the whole floor being
-- moved and charged for having moved.
--
-- TWO WEAPONS, ONE SENTENCE, TWO LENGTHS:
--
--   Strangleknot  melee. Root: you cannot leave THIS TURN. Six ticks, and the circle's fifth verb
--                 returned to it on the one body that displaces nothing.
--   Lunging Fang  reach 3. Coiled: you cannot leave AT ALL -- no clock, no pin, and every turn ended
--                 outside its circle closes the coil on you.
--
-- SO THE FLOCK BECOMES ITS DELIVERY. A gust that shoves a coiled body a tile off is the serpent's
-- damage arriving on somebody else's wings, for free. That is the reason this circle authors a second
-- animal rather than more harpies: two bodies that make each other worse are a stratum, and two that
-- merely add are a bigger fight.
--
-- ...AND THEY ARGUE, WHICH IS LEFT IN. A rooted body cannot be shoved at all, so a company caught in
-- the coils is sheltered from the wind. Being held next to a serpent is a real alternative to being
-- scattered by a flock, and picking which of the two to be caught by is a decision the player can make
-- on the board. The bodies were never meant to be additive.
--
-- WHAT IT IS, IN THE FICTION. The same rite that made the harpies, gone wrong in the other direction
-- (docs/story.md, "The blooding") -- a child the Cathedral's blessing half-took, come back long. It is
-- a demon on the roster for the reason every one of them is: the church calls what it ruins a demon
-- from the wild, and hunts it, and is believed.
--
-- NOT A NAGA, and the difference is worth stating because the silhouette invites the mistake. The naga
-- race is the FEN'S -- water +2, lightning -4, a swim grant and movement -1, written to a rung-1
-- shoalkin and belonging to Greed's swamp (data/races/naga.lua). A lamia in a dry keep would wear a
-- resist table about a river it will never see, and would carry coils for crossing water there is none
-- of. It is a demon that is shaped like a snake, not serpent-folk.
--
-- Tier 2's band is 31-80 health (Balance.HEALTH_BANDS). Middle of it -- heavier and slower than a
-- harpy, because the thing it does is stay.
return {
    name = "Lamia",
    race = "demon",
    tier = 2,
    sprite = "assets/chars/lamia.png",
    stats = {
        health = 62, mana = 0, stamina = 22,
        staminaRegen = 2,
        damage = 13, magicDamage = 0,
        defense = 7, magicDefense = 5,
        movement = 4, -- it does not need to chase what it has already tethered
        speed = 4,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 7, luck = 4,
    },
    -- INNATE MITIGATION (models/character.lua `resist`), in the same unit an armour's resist
    -- table is written in and summed into the same total. This body wears nothing, so this is
    -- what it has instead of a coat -- and the negative line is not an oversight, it is the
    -- price. See docs/bestiary.md, "What a creature wears instead of armour".
    --   Scale over scale over scale, and an edge slides down the lie of them.
    --   A weight does not have to find a seam. It only has to land on what is underneath.
    resist = { slash = 3, impact = -3, fire = 3, holy = -6 },
    startingItems = { "weapon_strangleknot", "weapon_lunging_fang" },
    -- WHAT IT IS KNOWN FOR (docs/drops.md). The tether, handed over: a foe you mark cannot end its
    -- turn away from YOU without paying. The rift sells you the trick.
    drops = {
        "utility_the_slow_circle",
    },
    -- The knot rather than the fang: `defaultAction` is what a compulsion and a counter swing
    -- (models/ai.lua), and what this body does to something already beside it is hold it.
    defaultAction = "weapon_strangleknot",
    -- `aggressive` where the flock skirmishes, and the pair is the point: a harpy holds the gap
    -- because its weapons are about distance, and this closes because its weapons are about denying
    -- it. A floor that fields both is pulled two ways at once.
    archetype = "aggressive",
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
