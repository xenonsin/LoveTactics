-- THE UNWANTED: Envy's apex, a 2x2 body, and a fight whose health bar lies to you.
--
-- It sheds a pair of glass-motes at every threshold it is cut past
-- (data/items/utility/utility_fracture_line.lua), so the number going down is not the whole story --
-- what is actually happening is that there is MORE of it than there was. Which is the right shape for
-- Envy's apex: it does not grow stronger, it multiplies, and every piece it sheds goes off to strip
-- something you built.
--
-- FOOTPRINT 2x2. On the desert's open carve a four-tile body is less of a wall than it is elsewhere --
-- there is room to go around -- so its denial comes from the motes rather than from the bulk. That is
-- deliberate: an apex should read differently per stratum rather than being the same wall in seven
-- tilesets.
--
-- Tier 3's band is 81-154 health; it sits high, because a body that sheds parts of itself needs enough
-- of a bar to shed them from.
return {
    name = "The Unwanted",
    kind = "construct",
    tier = 3,
    sprite = "assets/chars/the_unwanted.png",
    footprint = { w = 2, h = 2 },
    stats = {
        health = 140, mana = 0, stamina = 24,
        staminaRegen = 2,
        damage = 13, magicDamage = 0,
        defense = 9, magicDefense = 11, -- glass: it wards magic far better than it takes a hammer
        movement = 3,
        speed = 3,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 7, luck = 0,
    },
    -- INNATE MITIGATION (models/character.lua `resist`), in the same unit an armour's resist
    -- table is written in and summed into the same total. This body wears nothing, so this is
    -- what it has instead of a coat -- and the negative line is not an oversight, it is the
    -- price. See docs/bestiary.md, "What a creature wears instead of armour".
    --   Glass, at the scale where a blade has a whole wall of it to slide down.
    --   Glass, at any scale.
    resist = { slash = 4, impact = -4 },
    startingItems = { "weapon_vitreous_bite", "utility_fracture_line" },
    defaultAction = "weapon_vitreous_bite",
    archetype = "aggressive",
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
