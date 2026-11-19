-- THE FACELESS CHAMPION, rung 2: comparison (approved 2026-10-02, "Envy's Bestiary", round 2). It replaced a
-- Duelist that wore "whichever your attacker lacks", which the author found "not exciting".
--
-- Its hand is the rift's champions -- the Elf Bladedancer, the Orc Pit-Fighter, the Oni Swordmaster and the Asura
-- Adept (the Vampire Duelist was named too, but it is human-raced and humans are never a face) -- each worn with
-- its signature rule, and it swaps to whichever answers the nearest of the company (The Rift's Champions).
--
-- The counter is the review's: know the rift's champions, because you have fought each one before, and every
-- face brings its own known answer -- magic for Untouchable, focusing the Challenger. It drops the Mask of
-- Champions, on the duelist's rack.
--
-- IDENTITY LEVER (creature identity pass, 2026-11-19): POSITION. It picked its face by the nearest-foe read every
-- Faceless uses, so the player met each champion only once it was on. Now it TELEGRAPHS: at the end of its turn
-- (and at the bell) it commits the face it will wear next and names it on a badge (status_next_face,
-- Faces.telegraph), and Reshape wears exactly that face next turn. So the player knows which champion is coming
-- and chooses who stands nearest it. TARGETING: nearest in its own body -- a champion takes whoever steps up. (A
-- champion's face brings that champion's own tactics; this is the rule it falls back to Unmasked.)
return {
    name = "Faceless Champion",
    race = "faceless",
    tier = 3,
    class = "fighter",
    sprite = "assets/chars/faceless_champion.png",
    archetype = "aggressive",
    stats = {
        health = 86, mana = 0, stamina = 26,
        staminaRegen = 4,
        damage = 12, magicDamage = 0,
        defense = 4, magicDefense = 4,
        movement = 4,
        speed = 4,
        skill = 6, luck = 5,
    },
    startingItems = {
        "weapon_iron_sword", "utility_the_rifts_champions", "armor_buckler",
        false,               false,                         false,
        false,               false,                         false,
    },
    drops = { "utility_mask_of_champions" },
    defaultAction = "weapon_iron_sword",
    signatureWeapon = "weapon_iron_sword",
    ai = {
        { priority = "normal", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "exists" } },
    },
}
