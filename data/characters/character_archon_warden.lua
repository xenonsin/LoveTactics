-- THE ARCHON WARDEN: the court's keeper, on the Crown's floor ("The Crown's Bestiary", slice A, 2026-10-09). A
-- heavy-armoured keeper of a door between the spheres, humanoid like every Archon.
--
--   HOLD THE GATE   on any turn it has not moved, every Archon within 2 of it takes half damage from anything struck
--                   from farther than 2 tiles (utility_hold_the_gate; models/archon_court.lua's isHolding)
--   THE GLAIVE      its own blows shove the struck body 1 tile back out (weapon_gatekeepers_glaive)
--   SPIRIT BODY     the race (data/races/archon.lua)
--
-- HOW YOU BEAT IT, the review's own: close in. Arrows and spells from range do half against its court, but melee does
-- full. Or knock it off its post with a shove or a pull, which ends the cover until its next still turn.
--
-- AGGRESSIVE, NOT `holdGround`, though a keeper that never leaves its door was the first reading. Rooted, it is a
-- body the company has to walk to, and the harness company shot at it from range -- at half -- for 39 unit-turns. It
-- walks in and holds wherever it stands to swing, which is the same rule met sooner. Iron Plate is its armour (heavy,
-- and a third item: a tier-3 humanoid is more than a weapon). On the fighter table, not the knight's, which walls a
-- line body at depth, and at the foot of its rung's health band. It drops the Warden's Post, a Sentinel's.
return {
    name = "Archon Warden",
    race = "archon",
    tier = 3,
    class = "fighter",
    sprite = "assets/chars/archon_warden.png",
    archetype = "aggressive",
    stats = {
        health = 81, mana = 0, stamina = 30,
        staminaRegen = 4,
        damage = 12, magicDamage = 0,
        defense = 4, magicDefense = 4, -- 6 after the race
        movement = 4, -- 2 under the plate
        speed = 3,
        skill = 5, luck = 4,
    },
    startingItems = {
        "weapon_gatekeepers_glaive", "utility_hold_the_gate", false,
        "armor_iron_plate",          false,                   false,
        false,                       false,                   false,
    },
    drops = { "utility_wardens_post" },
    defaultAction = "weapon_gatekeepers_glaive",
    signatureWeapon = "weapon_gatekeepers_glaive",
}
