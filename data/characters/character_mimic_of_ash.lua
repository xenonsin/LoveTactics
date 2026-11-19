-- A Mimic-of-Ash: the Envy circle's specialist, and the body that hands your opening move back.
--
-- It throws back the element it was last struck with (data/items/weapon/weapon_ashen_echo.lua,
-- trait_ashen_echo), which on the desert board -- open ground, slow crossing, both lines watching each other the
-- whole way in -- means your first commitment is information the mimic gets to use. Burn it and it burns you back.
--
-- IDENTITY LEVER (creature identity pass, 2026-11-19): BRING and ORDER. Its item used to say "throws back the
-- last thing thrown" while the code was a missing-health ramp, so it read like any enrage. Now the badge
-- (status_ashen_echo) names the element it is holding, its strikes carry it, and a plain blow washes it out. So:
-- throw an element your front line shrugs off, or throw your fire and finish with steel. And it goes for whoever
-- last struck it (models/envy_oneoffs.lua's plan), so the body that lit it is the body that gets it back.
--
-- WHY NOT A LITERAL RE-CAST still holds: a mimic that had eaten a party's best spell would delete the party with
-- it. Borrowing the element keeps the blow its own size.
return {
    name = "Mimic-of-Ash",
    race = "construct",
    tier = 2,
    sprite = "assets/chars/mimic_of_ash.png",
    stats = {
        health = 66, mana = 0, stamina = 22,
        staminaRegen = 2,
        damage = 11, magicDamage = 0,
        defense = 7, magicDefense = 7,
        movement = 4,
        speed = 4,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 6, luck = 0,
    },
    -- INNATE MITIGATION (models/character.lua `resist`), in the same unit an armour's resist
    -- table is written in and summed into the same total. This body wears nothing, so this is
    -- what it has instead of a coat -- and the negative line is not an oversight, it is the
    -- price. See docs/bestiary.md, "What a creature wears instead of armour".
    --   Ash holds its shape until something asks it to hold a shape.
    --   A spear asks nothing of it and passes through; an edge takes the whole silhouette apart at once.
    resist = { pierce = 3, slash = -3 },
    startingItems = { "weapon_ashen_echo" },
    defaultAction = "weapon_ashen_echo",
    -- Basic tactics (models/ai.lua): it presses whoever is closest to falling. A body paid for taking
    -- blows should be walking INTO the party, not picking at the edges. Ahead of this rule, its plan
    -- (models/envy_oneoffs.lua) answers whoever last struck it whenever that body can be reached this turn.
    archetype = "aggressive",
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
