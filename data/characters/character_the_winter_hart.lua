-- THE WINTER HART: Sloth's mythic, and the body that manufactures the tundra's own ground.
--
-- It lays black ice as it acts (data/traits/trait_conduction.lua), so the danger is not the animal, it is
-- where the animal has BEEN. The tundra's terrain identity is that ice costs nothing to cross and
-- conducts (data/biomes/tundra.lua); the Hart is what turns that from a property of the map into a thing
-- something on the board is doing to you on purpose.
--
-- It pays for the ground with its turn -- a Hart that spends the fight walking is not also hitting you --
-- so the counterplay is to make it choose, and then to punish whichever it chose.
--
-- FOOTPRINT 2x2. On the `floes` carve there is nothing to block, so its bulk is not denial; the ice is.
-- An apex should read differently per stratum rather than being the same wall in seven tilesets.
return {
    name = "The Winter Hart",
    kind = "beast",
    tier = 3,
    sprite = "assets/chars/the_winter_hart.png",
    footprint = { w = 2, h = 2 },
    stats = {
        health = 136, mana = 0, stamina = 24,
        staminaRegen = 3,
        damage = 15, magicDamage = 6,
        defense = 10, magicDefense = 12,
        movement = 4, -- it walks, and walking is half of what it does
        speed = 3,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 4, luck = 5,
    },
    -- INNATE MITIGATION (models/character.lua `resist`), in the same unit an armour's resist
    -- table is written in and summed into the same total. This body wears nothing, so this is
    -- what it has instead of a coat -- and the negative line is not an oversight, it is the
    -- price. See docs/bestiary.md, "What a creature wears instead of armour".
    --   Frozen through: it takes a blow the way a frozen thing does, which is by not moving at all.
    --   A frozen thing also splits. Cut it, or thaw it, and it stops being one piece.
    resist = { impact = 4, slash = -4, ice = 4, fire = -8 },
    startingItems = { "weapon_hoarfrost_antlers", "utility_hoarfrost_pelt" },
    defaultAction = "weapon_hoarfrost_antlers",
    archetype = "aggressive",
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
