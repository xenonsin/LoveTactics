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
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 6, luck = 0,
    },
    -- INNATE MITIGATION (models/character.lua `resist`), in the same unit an armour's resist
    -- table is written in and summed into the same total. This body wears nothing, so this is
    -- what it has instead of a coat -- and the negative line is not an oversight, it is the
    -- price. See docs/bestiary.md, "What a creature wears instead of armour".
    --   Pride's mythic is armour, and its answer to being hurt is to stand up more armour.
    --   Every piece is fitted, and a fitting is a hole somebody agreed to leave. A spear knows it.
    resist = { slash = 4, impact = 2, pierce = -6 },
    startingItems = { "weapon_gilded_pike", "utility_the_gallery" },
    defaultAction = "weapon_gilded_pike",
    archetype = "defensive",
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
