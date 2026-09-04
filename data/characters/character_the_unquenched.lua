-- THE UNQUENCHED: Wrath's mythic, and the body that turns the circle's own board into a resource.
--
-- It heals as it acts, if it is standing in fire (data/traits/trait_drinks_the_fire.lua) -- and this
-- stratum fills its own board with fire: the swarm leaves a tile alight every time one dies, the brands
-- Burn what they hit, and the biome's signature hazard is fire outright.
--
-- Which makes it the circle's best counterplay problem, because the obvious answer to a Wrath floor --
-- clear the chaff first -- is exactly what feeds it. On clean ground it is a large animal. The real
-- answer is to make it come to you, across ground nothing has died on.
--
-- FOOTPRINT 2x2. On the `rifts` carve -- open country with one road -- a four-tile body on the road IS
-- the road, which is what an apex should mean on a board with no warren to block.
--
-- Tier 3's band is 81-154 health. High, because a body you are supposed to out-position rather than
-- out-damage needs to survive being out-positioned.
return {
    name = "The Unquenched",
    kind = "beast",
    tier = 3,
    sprite = "assets/chars/the_unquenched.png",
    footprint = { w = 2, h = 2 },
    stats = {
        health = 144, mana = 0, stamina = 26,
        staminaRegen = 3,
        damage = 16, magicDamage = 0,
        defense = 10, magicDefense = 12, -- it has been on fire for a very long time
        movement = 3,
        speed = 3,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 4, luck = 5,
    },
    -- INNATE MITIGATION (models/character.lua `resist`), in the same unit an armour's resist
    -- table is written in and summed into the same total. This body wears nothing, so this is
    -- what it has instead of a coat -- and the negative line is not an oversight, it is the
    -- price. See docs/bestiary.md, "What a creature wears instead of armour".
    --   Cooked hard on the outside by the ground it stands in and heals on.
    --   The point is what gets past that crust, and the cold is what takes the ground away.
    resist = { slash = 4, pierce = -4, fire = 4, ice = -8 },
    startingItems = { "weapon_rift_jaws", "utility_quenchless_gut" },
    defaultAction = "weapon_rift_jaws",
    archetype = "aggressive",
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
