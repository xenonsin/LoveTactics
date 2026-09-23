-- A MANDRAKE: the first rung of the Alraune line, and the Lust circle's HOLD at its smallest.
--
-- WHAT IT IS, IN THE FICTION. Mandrake grows where the dead fall -- under the gallows, in the old herbals
-- -- and this grows out of the Cathedral's unmarked pit, where the blooding's third outcome is dumped and
-- written down as ascended (docs/story.md, "The blooding"). The circle already fields the rite that TOOK
-- (the succubi) and the rite that took WRONG (the harpies and the lamiae); this line is the rite that
-- KILLED, come back up out of the floor.
--
-- TWO THINGS, AND THEY PULL AGAINST EACH OTHER. It roots a body from three tiles off (weapon_taproot),
-- which is a reason to kill it -- and when it dies it screams, Stunning every body within two tiles on
-- both sides (trait_mandrake_shriek), which is a reason not to do it in melee. So the Lust circle's
-- standing law, cut the one doing it, still holds and now costs something: shoot it, or let something
-- else pull it up, as the herbals' dog does.
--
-- PLANTED (`movement = 0`), like the Blightstake, and `guard` for the Blightstake's reason: a posture
-- whose plan is repositioning would spend every turn trying to walk somewhere it cannot go. A PLANT
-- (models/grove.lua) as well, so a Nymph can step out of the grain beside one -- though the two lines
-- never share a fight: this one roots and the Dryad line throws (Descent.SINS' Lust entry).
--
-- Tier 1's band is 1-30 health (Balance.HEALTH_BANDS): chaff that dies to a blow, which is the point --
-- the blow is the mistake.
return {
    name = "Mandrake",
    race = "demon",
    tier = 1,
    plant = true,
    sprite = "assets/chars/mandrake.png",
    archetype = "guard",
    stats = {
        health = 20, mana = 24, stamina = 0,
        damage = 0, magicDamage = 8,
        defense = 2, magicDefense = 6,
        movement = 0, -- it is in the floor
        speed = 5,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 6, luck = 3,
    },
    -- INNATE MITIGATION (docs/bestiary.md, "What a creature wears instead of armour").
    --   A root is fibre: a point goes in and finds nothing to split. An edge goes through it like a spade.
    --   It burns like anything dug up and left to dry, and the blood in it is Luxuria's, so holy bites.
    resist = { pierce = 2, slash = -2, dark = 2, fire = -4, holy = -2 },
    startingItems = { "weapon_taproot", "utility_mandrake_scream" },
    -- WHAT IT IS KNOWN FOR (docs/drops.md): the whole body, planted on your side.
    drops = {
        "ability_mandrake_sprout",
    },
    defaultAction = "weapon_taproot",
    ai = {
        { priority = "high", act = "attack", item = "weapon_taproot", targetPref = "nearest",
          when = { subject = "any_foe", test = "within", value = 3 } },
    },
}
