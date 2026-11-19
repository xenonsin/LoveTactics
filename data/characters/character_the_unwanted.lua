-- THE UNWANTED: Envy's apex, a 2x2 body, and a fight whose health bar lies to you.
--
-- IT CRACKS THE FLOOR AT EVERY THRESHOLD IT IS CUT PAST (data/items/utility/utility_fracture_line.lua,
-- trait_fracture_line): straight lines of glass run three tiles out of each side of its body, cut every foe on
-- them, and are left as Glass Shards that cut and strip whoever of the company ends a turn there. So the number
-- going down is not the whole story -- every third of its bar it takes away more of the ground you can stand on.
--
-- IDENTITY LEVER (creature identity pass, 2026-11-19): POSITION. It used to shed a pair of glass-motes at each
-- threshold, the same apex template as The Long Winter's drift-things (the audit's same-apex row). The Winter's
-- escalation is tempo; this one's is ground. The cracks never run off its corners, so the body that reads its
-- bar stands on a diagonal when it is about to break. Its bite is the Glass-Eater's, and it feeds on blessings
-- the same way (status_glass_fed).
--
-- FOOTPRINT 2x2. On the desert's open carve a four-tile body is less of a wall than it is elsewhere --
-- there is room to go around -- so its denial comes from the glass it lays rather than from the bulk. That is
-- deliberate: an apex should read differently per stratum rather than being the same wall in seven
-- tilesets.
--
-- Tier 3's band is 81-154 health; it sits high, because a body that breaks at two thresholds needs enough
-- of a bar between them for the ground it lays to matter.
return {
    name = "The Unwanted",
    race = "construct",
    tier = 3,
    boss = true, -- the fight is it: off the execute and Charm tables (tests/charm_balance_spec.lua)
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
