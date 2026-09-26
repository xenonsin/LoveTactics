-- THE RUST MITE: it eats metal, and any weapon that strikes it rusts (utility_rust_hide: Tarnished, 2
-- less damage with THAT weapon for the fight, stacking to -6). The line body of the Coin-Eaters.
-- Reviewed 2026-09-25 ("The Coin-Eaters" artifact); its forge-eating bite was cut on review.
--
-- THE COUNTERPLAY IS WHAT YOU HIT IT WITH: a spell, an arrow, a fist, or a blade you do not mind blunting.
-- The sword that answers everything else on the floor is the one this ruins. Its soft body gives to an
-- edge and shrugs off a point.
return {
    name = "Rust Mite",
    race = "beast",
    tier = 2,
    sprite = "assets/chars/rust_mite.png",
    stats = {
        -- Soft, on purpose: the rust is the whole of its threat, and at 48 health / 7 defense the Tarnish ran
        -- 34 unit-turns against the ordinary road's 22 (tests/skirmish_spec.lua).
        health = 40, mana = 0, stamina = 20,
        staminaRegen = 3,
        damage = 12, magicDamage = 0,
        defense = 5, magicDefense = 3,
        movement = 3,
        speed = 4,
        skill = 3, luck = 4,
    },
    resist = { pierce = 3, slash = -3 },
    startingItems = {
        "weapon_mandibles", "utility_rust_hide", false,
        false, false, false,
        false, false, false,
    },
    drops = { "armor_rustcoat" },
    defaultAction = "weapon_mandibles",
    archetype = "aggressive",
}
