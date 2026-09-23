-- A HARPY: the Lust circle's line body, and the stratum's rule stated at the rung a fight is made of.
--
-- IT DOES NOT KILL YOU. It decides where you are. Two weapons, and they are ONE VERB POINTED BOTH
-- WAYS: the talons snatch a body at two tiles and haul it onto the bird, the gust beats a body back a
-- tile from three. Neither number is large and neither is meant to be -- what turns a tile into a
-- wound is the Thinwall Keep, where a shove ends in a wall, a doorway, or somebody else's back, and
-- Combat.knockback charges the impact of everything the shove could not spend. **The flock rearranges
-- a company and the building kills it.** See models/descent.lua's Lust entry for the argument.
--
-- SO A FLOCK DOES NOT BEAT A COMPANY, IT UNPICKS ONE. Four harpies working the same rank pull the
-- front body forward and push the back body off, and in a warren of rooms that is a party standing in
-- three places with a wall between each of them. The damage arrives afterwards, from whatever the
-- separated bodies were left next to.
--
-- IT USED TO PIN, AND PINNING WAS THE WRONG VERB -- Root sets `blocksForcedMove`, so a rooted victim
-- could not be moved by the rest of the flock either, and the circle's own line body was switching the
-- circle off one target at a time. Nothing on this stratum holds anything now.
--
-- WHY IT HOLDS THE GAP. `skirmish`, so it stays out where both its weapons reach and neither of them
-- is a brawl. A harpy that has hauled somebody in front of it is a harpy standing between that body
-- and everyone who could have helped.
--
-- WHAT IT IS, IN THE FICTION. A blooding that took wrong (docs/story.md, "The blooding"): a child the
-- Cathedral's rite half-took, hunted afterwards by the church that made it and written down as a demon
-- from the wild. That is why it is a demon on the roster, why its talons burn, and why holy cuts it --
-- the whole holy line is written against `kind = "demon"` (docs/bestiary.md) and this body is the first
-- thing on this ground that a Smite is the right answer to.
--
-- Tier 2's band is 31-80 health (Balance.HEALTH_BANDS). Low in it: fast, reaching, and thin.
return {
    name = "Harpy",
    race = "demon",
    tier = 2,
    sprite = "assets/chars/harpy.png",
    stats = {
        health = 48, mana = 0, stamina = 20,
        staminaRegen = 3,
        damage = 12, magicDamage = 0,
        defense = 4, magicDefense = 6,
        movement = 6, -- it gets to the flank, which is the only place its two tiles are worth anything
        speed = 5,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 7, luck = 7,
    },
    -- INNATE MITIGATION (models/character.lua `resist`), in the same unit an armour's resist
    -- table is written in and summed into the same total. This body wears nothing, so this is
    -- what it has instead of a coat -- and the negative line is not an oversight, it is the
    -- price. See docs/bestiary.md, "What a creature wears instead of armour".
    --   Feathers lie flat over each other and an edge slides across them without finding a seam.
    --   A point goes between them, and there is a great deal less behind than the shape promised.
    resist = { slash = 3, pierce = -3, fire = 3, holy = -6 },
    startingItems = { "weapon_harpy_talons", "weapon_stooping_gust" },
    -- The talons rather than the gust: `defaultAction` is what a compulsion and a counter swing
    -- (models/ai.lua), and the grab is what this body does to anything already standing next to it.
    -- The planner reaches for the gust on its own whenever the talons cannot reach.
    defaultAction = "weapon_harpy_talons",
    archetype = "skirmish",
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
