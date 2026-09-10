-- THE SUPPLIANT: Lust's mini sin, and the body that holds the Cathedral's first stair.
--
-- IT REPLACES A BORROWED SLOT. Descent.SINS gave this floor to character_inquisitor -- a discipline
-- exemplar standing in for a sin. A stratum's centrepiece should BE the sin one rank down.
--
-- WHAT A MINI SIN IS. A lesser embodiment of the same sin, carrying a cut-down version of its general's
-- rule, which turns up in full at half health:
--
--   from the bell   The Unasked: it drains whoever ENDED THEIR TURN having spent nothing
--   at 50%          it drains regardless, which is Luxuria's baseline
--   ...and Luxuria  drains every hit, unconditionally, from her opening bell
--
-- The gate is what makes the lesson learnable: a player can see which of their units it fired on and
-- work backwards to why. Hold a turn and you are drained; spend and you are not. See
-- data/items/utility/utility_offered_nothing.lua.
--
-- She is the Unbidden -- the one who was never asked. This one asks: named for the office rather than
-- for the mechanic. `referenceLevel` because the circles are dealt fresh every run; `boss = true` keeps
-- it off the execute and Charm tables.
return {
    name = "The Suppliant",
    kind = "demon",
    tier = 4,
    sprite = "assets/chars/the_suppliant.png",
    referenceLevel = 13,
    boss = true,
    stats = {
        health = 180, mana = 60, stamina = 22,
        staminaRegen = 3,
        damage = 11, magicDamage = 15,
        defense = 10, magicDefense = 14,
        movement = 4,
        speed = 4,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 8, luck = 6,
    },
    -- INNATE MITIGATION (models/character.lua `resist`), in the same unit an armour's resist
    -- table is written in and summed into the same total. This body wears nothing, so this is
    -- what it has instead of a coat -- and the negative line is not an oversight, it is the
    -- price. See docs/bestiary.md, "What a creature wears instead of armour".
    --   It offered everything it had and kept only the shell it was kneeling in.
    --   The shell is empty. A weight lands in it and there is nothing behind it to stop.
    resist = { slash = 5, impact = -5, dark = 5, holy = -10 },
    -- THREE THINGS TO DO, where it used to have one. This body is the guard on the first stair a
    -- descent meets, and it stood there with a single action that Charmed -- so the opening fight of a
    -- whole campaign was one move repeated, and the party's answer to it was one move repeated back.
    -- The touch is still its best line at melee and still what it reaches for first; the lash gives it
    -- a press at reach instead of a shuffle, and the bough is the circle's own sentence -- a body
    -- called out of the line -- at a volume that can be answered on the turn it happens rather than
    -- two turns later. See data/items/weapon/weapon_beckoning_bough.lua.
    startingItems = { "weapon_petal_touch", "weapon_briar_lash", "weapon_beckoning_bough",
                      "utility_offered_nothing" },
    defaultAction = "weapon_petal_touch",
    archetype = "aggressive",
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
