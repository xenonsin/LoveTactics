-- A standard-bearer: the Pride circle's specialist, and the body a good player kills first.
--
-- It carries the colours and very little else (data/items/utility/utility_gilded_standard.lua). Because
-- both halves of the rank rule are measured LIVE off adjacency, killing it does not merely remove a buff
-- -- it collapses the shape the rest of the rank was built around, and the survivors are suddenly four
-- ordinary suits of armour.
--
-- Which makes this the circle's readable answer: not "kill the big one", but "kill the one that is not
-- hitting you". The same lesson the Long Note warband teaches with a Rally Banner, told again in armour.
return {
    name = "Standard-Bearer",
    kind = "construct",
    tier = 2,
    sprite = "assets/chars/standard_bearer.png",
    stats = {
        health = 64, mana = 0, stamina = 18,
        staminaRegen = 2,
        damage = 6, magicDamage = 0, -- it is not here to fight
        defense = 9, magicDefense = 6,
        movement = 3,
        speed = 3,
    },
    startingItems = { "weapon_gilded_pike", "utility_gilded_standard" },
    defaultAction = "weapon_gilded_pike",
    archetype = "defensive",
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
