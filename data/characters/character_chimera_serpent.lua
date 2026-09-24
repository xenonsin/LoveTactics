-- THE CHIMERA'S SERPENT: the tail, and a head of its own (Combat.spawnHeads). Grown at the bell off
-- utility_chimera_serpent -- or off utility_serpent_head on a Beastmaster -- it stands on no tile and
-- dies with the body it grows from.
--
-- THE FAST HEAD, and its turn is a COIL, not a strike (ability_coil): until it comes round again, the
-- first foe to strike the body in melee is bitten and Poisoned (trait_serpents_strike, carried by the
-- item that grew it, since the blow it answers lands on the BODY). "Once a round" had no visible start and
-- end in the round-one pitch; the serpent's card on the strip is both.
--
-- A coil that comes round unused feeds its hunger (status_starving), judged by ability_coil itself -- the
-- serpent always acts, so the wait rule the lion and goat are judged by would never fire for it.
return {
    name = "Chimera's Serpent",
    race = "beast",
    tier = 2,
    sprite = "assets/chars/chimera_serpent.png",
    -- No fists: a head has one mouth and one thing to do with it, and a goat that punched on the turns
    -- it had nothing to breathe on would never go hungry (status_starving).
    unarmed = false,
    stats = {
        health = 32, mana = 0, stamina = 18,
        staminaRegen = 3,
        damage = 5, magicDamage = 0,
        defense = 4, magicDefense = 4,
        movement = 0,
        speed = 7,
        skill = 6, luck = 5,
    },
    -- Scale turns a point but not an edge: a blade is how a tail comes off (docs/bestiary.md -- a hide is a
    -- redistribution, so the line it turns is paid for by the line it fears).
    resist = { pierce = 3, slash = -3 },
    startingItems = {
        "ability_coil", false, false,
        false, false, false,
        false, false, false,
    },
    defaultAction = "ability_coil",
    archetype = "defensive",
    ai = {
        { priority = "high", act = "cast", item = "ability_coil" },
    },
}
