-- AN ALRAUNE: the alpha of the Alraune line -- the flower the Mandrake is the root of -- and the Lust
-- circle's HOLD turned into a trap you are paid to walk into.
--
-- THE LINE IS THE ONE BELOW PLUS ITS CASTING. She keeps the Mandrake's Taproot and its scream, and she
-- casts three things that are one sentence between them:
--
--   Honeyed Ground  heals whoever arrives on it, and puts to sleep whoever ENDS a turn there
--                   (weapon_honeyed_ground, data/status/status_honeyed.lua).
--   Gallows Seed    every heal the seeded body receives is hers instead (data/status/status_gallows_seed.lua).
--   Nightshade      double on a sleeping body, and it wakes them (weapon_nightshade).
--
-- The root keeps you on the honey, the honey heals you into the seed, the seed pays her, and Nightshade
-- collects on whoever fell asleep. Every link can be cut -- a Cure takes the root or the seed, stepping
-- off takes the honey, and cutting HER dries the honey where it lies -- and a company that cuts none of
-- them feeds her the fight.
--
-- WHICH IS "WANTING COSTS", THE CIRCLE'S FIRE VERB, TURNED INSIDE OUT. Everywhere else on this stratum
-- the reaching is what is billed. Here the ground pays you for being there, and the bill is the turns.
--
-- IN THE HOLD HALF OF THE CIRCLE, never beside a shover (Descent.SINS' Lust entry): a rooted body cannot
-- be thrown, and a fight that fielded both would switch itself off one target at a time.
--
-- Tier 2's band is 31-80 health (Balance.HEALTH_BANDS). Low in it: she is a caster, and what protects
-- her is the garden in front of her.
return {
    name = "Alraune",
    race = "demon",
    tier = 2,
    plant = true,
    sprite = "assets/chars/alraune.png",
    archetype = "skirmish",
    stats = {
        health = 54, mana = 46, stamina = 10,
        staminaRegen = 2,
        damage = 6, magicDamage = 13,
        defense = 5, magicDefense = 10,
        movement = 2, -- she has roots too; she lifts them slowly
        speed = 5,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 8, luck = 6,
    },
    -- The Mandrake's hide at a tier's budget (docs/bestiary.md): fibre turns a point and not an edge, and
    -- the petals burn. The blood is Luxuria's, so holy bites.
    resist = { pierce = 3, slash = -3, dark = 3, fire = -4, holy = -3 },
    -- THE GARDEN'S OWN GROUND: sweetbriar, which Charms whoever blunders into it. It was the forest's
    -- signature hazard while the wood was Lust's; the wood went to Gluttony (and its web), and the briar
    -- came with the circle it was written for -- laid by the bodies that grow it (models/arena.lua).
    seedsGround = { id = "hazard_sweetbriar", count = 2 },
    startingItems = { "weapon_nightshade", "weapon_honeyed_ground", "weapon_gallows_seed",
                      "weapon_taproot", "utility_mandrake_scream" },
    -- WHAT SHE IS KNOWN FOR (docs/drops.md), rarest first: the seed, which is the trap's hook and the
    -- half nothing else in the game does; the sleeping draught her root is famous for; and the Mandrake
    -- itself, so a company that already holds the other two is paid rather than refused.
    drops = {
        "ability_gallows_seed",
        "consumable_mandragora",
        "ability_mandrake_sprout",
    },
    defaultAction = "weapon_nightshade",
    ai = {
        -- NIGHTSHADE ON A SLEEPER FIRST: that is the collection, and a sleeper not collected on wakes up
        -- for free on the next stray blow.
        { priority = "urgent", act = "attack", item = "weapon_nightshade", targetPref = "nearest",
          when = { subject = "any_foe", test = "has_status", value = "status_sleep" } },
        { priority = "high", act = "attack", item = "weapon_honeyed_ground", targetPref = "nearest",
          when = { subject = "any_foe", test = "lacks_status", value = "status_honeyed" } },
        { priority = "normal", act = "attack", item = "weapon_gallows_seed", targetPref = "nearest",
          when = { subject = "any_foe", test = "lacks_status", value = "status_gallows_seed" } },
    },
}
