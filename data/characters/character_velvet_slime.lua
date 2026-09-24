-- THE VELVET SLIME: Lust's slime (floors 3-4, the Thinwall Keep). Each circle's slime line carries one
-- rule of its own; this one's is STRIP (data/traits/trait_strip.lua) -- every blow it lands takes a piece
-- of your gear, armour first, and it WEARS what it takes. Kill it and the pieces come back; lose the
-- fight and they come back anyway (Combat.strip is a loan, never a theft).
--
-- Proof against steel like the fen's slime (utility_velvet_body), and adapting to elements the same
-- way, because by the third floor a company has had the time to find one. So the fight is the fen's
-- question -- did you bring an element -- asked while you are being undressed.
--
-- LUST'S RULE, AND ON NEITHER HALF OF IT. The circle keeps roots and shoves out of the same fight
-- (tests/greed_lust_circle_spec.lua); a strip is neither, so this body may stand in any roster here.
return {
    name = "Velvet Slime",
    race = "beast",
    tier = 2,
    sprite = "assets/chars/velvet_slime.png",
    stats = {
        health = 44, mana = 0, stamina = 16,
        staminaRegen = 2,
        damage = 12, magicDamage = 0,
        defense = 2, magicDefense = 2,
        movement = 3,
        speed = 4,
        skill = 4, luck = 2,
    },
    -- Its elemental trade: it has already taken fire into itself once too often (the keep's lamp rooms),
    -- and it is soft to the cold that stops it reaching.
    resist = { fire = 3, ice = -3 },
    startingItems = {
        false,              false,                 false,
        "weapon_pseudopod", "utility_velvet_body", false,
        false,              false,                 false,
    },
    defaultAction = "weapon_pseudopod",
    -- ITS OWN PIECE, and only its own (docs/drops.md): the Glove is its Strip, worn.
    drops = { "utility_velvet_glove" },
    archetype = "aggressive",
}
