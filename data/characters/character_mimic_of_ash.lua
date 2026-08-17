-- A Mimic-of-Ash: the Envy circle's specialist, and the body that hands your opening move back.
--
-- It hits harder for every blow it has taken (data/items/weapon/weapon_ashen_echo.lua), which on the
-- desert board -- open ground, slow crossing, both lines watching each other the whole way in -- means
-- your first commitment is information the mimic gets to use. Swing big at it and it swings big back.
--
-- WHY NOT A LITERAL RE-CAST. Storing the last ability aimed at it and throwing that would let a mimic
-- which had eaten a party's best spell delete the party with it -- a body that copies your peak output
-- is not counterplay, it is a coin flip, and it would sit outside every number its rung was authored
-- for. Reading missing health gets the same board-level idea (hurt it and it hurts you back) inside the
-- band, with no state to keep and nothing to desynchronise.
--
-- The counterplay is real and it is Envy's: do not commit your biggest thing into the mirror. Kill it
-- with the small stuff, or walk around it.
return {
    name = "Mimic-of-Ash",
    kind = "construct",
    tier = 2,
    sprite = "assets/chars/mimic_of_ash.png",
    stats = {
        health = 66, mana = 0, stamina = 22,
        staminaRegen = 2,
        damage = 11, magicDamage = 0,
        defense = 7, magicDefense = 7,
        movement = 4,
        speed = 4,
    },
    startingItems = { "weapon_ashen_echo" },
    defaultAction = "weapon_ashen_echo",
    -- Basic tactics (models/ai.lua): it presses whoever is closest to falling. A body paid for taking
    -- blows should be walking INTO the party, not picking at the edges.
    archetype = "aggressive",
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
