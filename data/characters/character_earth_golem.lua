-- THE EARTH GOLEM: Greed's ordinary rock, stood up (reviewed over two rounds, 2026-09-25, "The Golems of
-- Greed"). The MOUNTAIN made it, not the dwarves -- so it never shares a fight with them or the kobolds,
-- save the one Keno asked for (the Gold Golem's, where a dwarf crew breaks in for the hoard).
--
-- Built to be IN THE WAY, not to win an exchange: sturdy, slow, a fist that does not hit hard, and a steep
-- impact weakness that is how a company gets through it. CLASSLESS, so it grows on the fighter fallback
-- (a creature has no shelf -- tests/bestiary_spec.lua) and never on the knight table, which the kobolds
-- found walls a road fight at depth.
--
-- Its rules (utility_living_rock):
--   Delve            the Delver's own Delve, as creature kit (ability_golem_delve runs its very effect)
--   Strike the Vein  the hole it sank through is a coin heap, or one time in three a lava pit
--   Shed Plate       three plates, +2 Defense each; each impact blow knocks one off as a rubble wall
--
-- Drops Veinfinder and Shale Plating.
return {
    name = "Earth Golem",
    race = "construct",
    tier = 2,
    sprite = "assets/chars/earth_golem.png",
    stats = {
        health = 58, mana = 0, stamina = 18,
        staminaRegen = 3,
        damage = 12, magicDamage = 0,
        defense = 7, magicDefense = 4, -- 13 with its three plates on
        movement = 3,
        speed = 1,
        skill = 3, luck = 0,
    },
    -- Stone turns an edge and breaks under weight: the mace is the answer to the circle's golems.
    -- A creature's hide is a redistribution (Balance.INNATE_PHYSICAL): the lines sum to zero.
    resist = { slash = 2, pierce = 2, impact = -4 },
    startingItems = {
        "weapon_stone_fists", "ability_golem_delve", "utility_living_rock",
        false,                false,           false,
        false,                false,           false,
    },
    drops = { "ability_veinfinder", "utility_shale_plating" },
    defaultAction = "weapon_stone_fists",
    signatureWeapon = "weapon_stone_fists",
    ai = {
        -- Hit what is already in front of it.
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "nearest_foe", test = "in_reach" } },
        -- Otherwise go under and come up beside somebody: at speed 1 a golem that only walked would be a
        -- wall you kite forever. Delve's own cooldown paces it to every third turn.
        { priority = "normal", act = "cast", item = "ability_golem_delve",
          when = { subject = "any_foe", test = "exists" } },
    },
}
