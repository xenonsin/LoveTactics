-- THE LONGFANG: the pride's leader, and the Sabertooth plus one sentence -- "and a kill does not bring her
-- out of hiding". Named rather than titled (round two: "Rename"; round three chose The Longfang over
-- Sabertooth Matriarch and Elder Sabertooth), the way the wyverns have The Highwing.
--
-- THE ONE RULE: The Longfang's Hunt (data/traits/trait_the_unbroken_stalk.lua). A pounce that DOWNS its
-- target leaves her Invisible and opens her next turn Invisible, so she takes a body a turn and is never
-- once seen. Pitched as Thrill of the Hunt and approved as option A of round three; the hunter's shelf
-- already holds a Thrill of the Hunt, so the rule carries the name of her drop.
--
-- THE KILL ORDER IS A HEALTH QUESTION, NOT A POSITION ONE. Keep every body above one critical bite and
-- she has to come out after each one; let somebody drop and she is gone again. An area blast and
-- Witchlight reach her while she hides, exactly as they reach her pride.
return {
    name = "The Longfang",
    race = "beast",
    tier = 2,
    sprite = "assets/chars/the_longfang.png",
    stats = {
        health = 60, mana = 0, stamina = 24,
        staminaRegen = 3,
        damage = 18, magicDamage = 0,
        defense = 7, magicDefense = 3,
        movement = 4,
        speed = 5, -- first of the pride
        skill = 4, luck = 6,
    },
    resist = { slash = 3, impact = -3 },
    startingItems = {
        "weapon_pounce",          "utility_tawny_hide",        "utility_wood_walker",
        "utility_feral_instinct", "utility_the_longfangs_hunt", false,
        false,                    false,                       false,
    },
    drops = { "utility_the_unbroken_stalk" },
    defaultAction = "weapon_pounce",
    archetype = "aggressive",
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
