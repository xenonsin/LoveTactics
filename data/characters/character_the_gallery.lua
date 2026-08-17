-- THE GALLERY: Pride's mythic -- armour that keeps standing more of itself up.
--
-- Every threshold it is cut past puts another Gilded Sworn on the board
-- (data/items/utility/utility_the_gallery.lua), which does two things at once: it replaces the body you
-- just spent turns removing, and it TOPS UP THE RANK, so the formation rule that makes every Pride body
-- dangerous is being repaired while you work.
--
-- That second effect is the real one. In a circle where power is adjacency, a body that adds neighbours
-- is a body that makes everything else stronger, and killing it is the only way to stop the hall
-- refilling itself.
return {
    name = "The Gallery",
    kind = "construct",
    tier = 3,
    sprite = "assets/chars/the_gallery.png",
    stats = {
        health = 122, mana = 0, stamina = 22,
        staminaRegen = 2,
        damage = 11, magicDamage = 0,
        defense = 11, magicDefense = 8,
        movement = 3,
        speed = 3,
    },
    startingItems = { "weapon_gilded_pike", "utility_the_gallery" },
    defaultAction = "weapon_gilded_pike",
    archetype = "defensive",
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
