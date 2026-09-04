-- A gorge-fly: the Gluttony circle's swarm, and the body its combo starts from.
--
-- It bites for almost nothing and leaves Bleed (data/items/weapon/weapon_gorge_bite.lua). On its own
-- that is a rounding error. Behind a Tallow Hound it is the setup: a bled body is one the hound can
-- finish, and a finished body is what Engorge is paid for (data/traits/trait_engorge.lua).
--
-- The tension it creates is the circle in one body. Killing the flies is obviously correct -- and every
-- fly you kill in the hound's reach feeds the hound, because Engorge reads any death nearby and does
-- not care whose. So the swarm is worth clearing and clearing it has a price, which is what a Gluttony
-- fight should feel like at the cheapest rung available.
--
-- Tier 1's band is 1-30 health (Balance.HEALTH_BANDS). Sits at the bottom of it: this is meant to die
-- to any blow that touches it.
return {
    name = "Gorge-Fly",
    kind = "beast",
    tier = 1,
    sprite = "assets/chars/gorge_fly.png",
    stats = {
        health = 12, mana = 0, stamina = 12,
        staminaRegen = 3,
        damage = 5, magicDamage = 0,
        defense = 1, magicDefense = 1,
        movement = 6, -- it gets there first, which is the only thing it is good at
        speed = 6,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 2, luck = 5,
    },
    -- INNATE MITIGATION (models/character.lua `resist`), in the same unit an armour's resist
    -- table is written in and summed into the same total. This body wears nothing, so this is
    -- what it has instead of a coat -- and the negative line is not an oversight, it is the
    -- price. See docs/bestiary.md, "What a creature wears instead of armour".
    --   A fly is mostly air and wing: a blade finds almost nothing to part.
    --   What kills one is being swatted, and a mace is a very large hand.
    resist = { slash = 2, impact = -2 },
    startingItems = { "weapon_gorge_bite" },
    defaultAction = "weapon_gorge_bite",
    -- Basic tactics (models/ai.lua): it goes for whatever is already hurt, which stacks the Bleed where
    -- the hound behind it can cash it.
    archetype = "aggressive",
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.6 } },
    },
}
