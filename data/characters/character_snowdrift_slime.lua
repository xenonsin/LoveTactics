-- THE SNOWDRIFT SLIME: one of Sloth's three slimes. Its rule is DRIFT (data/traits/trait_drift.lua): it grows
-- every turn it does not move, so it waits (the `defensive` posture) -- leave it alone and it gets worse. Sloth
-- rewarded.
--
-- ITS LEVER IS ORDER (the creature identity pass, 2026-11-19, which kept this one's rule and moved its two
-- siblings off theirs). The stack is a badge on the slime itself, counting up where the company can read it:
-- kill it first, or shove it off its tile, which sheds the lot.
--
-- Its hide is water-soft rather than fire-soft, so the tundra's ice is not one answer printed eight times.
return {
    name = "Snowdrift Slime",
    race = "beast",
    tier = 2,
    sprite = "assets/chars/snowdrift_slime.png",
    stats = {
        health = 44, mana = 0, stamina = 16,
        staminaRegen = 2,
        damage = 12, magicDamage = 0,
        defense = 2, magicDefense = 2,
        movement = 3,
        speed = 4,
        skill = 4, luck = 2,
    },
    resist = { ice = 3, water = -3 },
    startingItems = {
        false,              false,                  false,
        "weapon_pseudopod", "utility_snowdrift_body", false,
        false,              false,                  false,
    },
    defaultAction = "weapon_pseudopod",
    -- ITS OWN PIECES, and only its own (docs/drops.md).
    drops = { "utility_snowbank" },
    archetype = "defensive",
}
