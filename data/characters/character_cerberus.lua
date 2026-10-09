-- CERBERUS: the Crown's elite ("The Crown's Bestiary", slice C, approved 2026-10-09). The dog at the gate of the dead.
--
--   THREE HEADS   it bites up to three different adjacent bodies each turn, one bite per head (weapon_three_mouths).
--                 Each head is a third of its bar and goes quiet when that third is gone (trait_each_head_a_third)
--   HONEY-CAKE    a Sleep, or a draught thrown at a head, quiets that head for 2 turns (trait_honey_cake)
--
-- THE COUNTERPLAY, STATED, and it is the review's own: let only one body stand beside it, so it gets one bite, and
-- fight it from range. Put heads to sleep. Choose which third to break first.
--
-- THE HEADS ARE THE CHIMERA'S SEAM (Combat.spawnHeads), three of them grown off the three Cerberus's Head pieces
-- below: each stands on no tile, is aimed at through the body's head picker, and holds a third of the bar. They take
-- no turn (the head blueprint is `timeless`): the bites are this body's, one per head awake. A blow on the body lands
-- on the fullest head, so the third you break first is the one you aimed at. models/gate_and_pit.lua owns the rules.
--
-- `boss`, as every elite of the rift is: no execute, no Charm. A demon: its bites burn and holy hurts it.
return {
    name = "Cerberus",
    race = "demon",
    tier = 4,
    boss = true,
    sprite = "assets/chars/cerberus.png",
    footprint = { w = 2, h = 2 },
    stats = {
        -- 180, so each head holds 60: a third a tier-2 body's worth, and a head a company can choose to break.
        health = 180, mana = 0, stamina = 30,
        staminaRegen = 5,
        damage = 13, magicDamage = 0,
        defense = 6, magicDefense = 6,
        movement = 4, -- it holds the gate; it does not run anything down
        speed = 5,
        skill = 5, luck = 4,
    },
    -- The same hide every head wears (character_cerberus_head), so a blow on the body reads the armour it lands on.
    resist = { fire = 3, slash = 1, pierce = 1, impact = -2 },
    startingItems = {
        "weapon_three_mouths",   "utility_cerberus_head", "utility_cerberus_head",
        "utility_cerberus_head", "utility_each_head_a_third", false,
        false,                   false,                   false,
    },
    drops = { "ability_three_heads" },
    defaultAction = "weapon_three_mouths",
    archetype = "aggressive",
}
