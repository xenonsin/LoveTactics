-- THE MANTICORE: Gluttony's seat-floor flier, and the first thing in the wood that fights at two ranges.
-- Every other animal here closes and bites, or waits and lets you come; this one fills the air with its
-- tail from across the glade, then flies in to bite what it softened. Pitched and reviewed in two rounds
-- (2026-09-23, "The Manticore" artifact); every rule below is one a line of that review approved.
--
-- THE LOOP IS BRISTLEBACK'S, taken on review in place of a pitched quill purse:
--   Tail Volley  a 3x3 of quills on a cooldown, foes only -- every foe inside is Quilled
--   Quilled      each stack is +2 PIERCE taken, capped at 4 (= Vulnerable: Pierce), so the next volley,
--                its bite, and the company's own arrows all land harder
--   Bristle      every 15 damage it takes, it sprays quills at every foe within 2
--   Three Rows   a plain pierce bite -- the stacks do its work
--   Wings        the flier's trade: fast over anything, and no cover from the wood while it is up
--   Man-eater    a foe that goes down beside it is eaten -- no revive this battle -- and the volley
--                comes straight back
--
-- THE COUNTERPLAY, STATED: break sight (the volley needs it); Cure a front line before the cooldown
-- turns (one Cure pulls every quill); kill it from range (Bristle only answers what is close, and it is
-- pierce -3 with no cover in the air); and do not go down next to it.
--
-- THE PIERCE WEAKNESS IS THE FLOOR'S OTHER HALF. The Giant Spider on the same stair RESISTS pierce, so a
-- company that brought bows is bad against one of the seat's two fights and good against the other.
-- Slash is what its hide turns, like a lion's.
--
-- WHAT IT HANDS OVER, each of its mechanics rebuilt for a person (docs/drops.md -- never a body part):
-- the Bristle's barbs as a coat, the volley as a fletching, and the Bristle itself as the chase. Ordered
-- shallow to deep, which within one list IS the rarity.
return {
    name = "Manticore",
    race = "beast",
    tier = 2,
    palate = "ability_tail_volley", -- what Gula takes when she eats one (models/palate.lua)
    sprite = "assets/chars/manticore.png",
    stats = {
        -- 20 at 3 a tick: a volley (6) and a bite (5) in the same stretch, with the volley's own cooldown
        -- rather than the pool being what spaces the volleys out.
        health = 52, mana = 0, stamina = 20,
        staminaRegen = 3,
        damage = 15, magicDamage = 0, -- between the spider's 13 and the bear's 19
        defense = 6, magicDefense = 4,
        movement = 5, -- flying: every tile costs one (utility_manticore_wings)
        speed = 4,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid. Skill a point over
        -- the beasts' because it shoots; luck under, because it is big and in the open.
        skill = 5, luck = 4,
    },
    -- INNATE MITIGATION (models/character.lua `resist`). A lion's hide turns an edge; the wings are skin
    -- over bone, and an arrow brings it down. See docs/bestiary.md, "What a creature wears instead of
    -- armour" -- the negative line is the price.
    resist = { slash = 3, pierce = -3 },
    startingItems = {
        "weapon_three_rows", "ability_tail_volley", "utility_bristle",
        "utility_manticore_wings", "utility_man_eater", "utility_feral_instinct",
        false, false, false,
    },
    drops = { "armor_quillhide", "utility_barbed_fletching", "utility_the_bristling" },
    defaultAction = "weapon_three_rows",
    archetype = "aggressive",
    -- Basic tactics (models/ai.lua). The volley carries its own rule and is reached first (an item's rule
    -- sits above the body's), so: fill the air when the tail is ready, and otherwise press whoever is
    -- closest to falling. Nothing here names the Quilled -- the planner scores a blow by what it will deal,
    -- and a quilled body is worth more to a pierce bite, so it is chosen without being told to be.
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
