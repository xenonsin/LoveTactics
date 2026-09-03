-- A glass-mote: the Envy circle's swarm, and the body that decides who gets copied.
--
-- It strips one blessing and shatters (data/items/weapon/weapon_glass_shard.lua). On its own that is
-- nothing. Standing in front of Second Water it is the setup for the whole circle: Lesser Reflection
-- copies the WEAKEST body it can see, and the motes are what make a body weakest.
--
-- So the counterplay is a decision about the shape of your company rather than a target priority.
-- Protect a body and it stops being the cheapest thing on the board; leave it stripped and the mirror
-- takes it. Livia's own header states Envy's answer as "do not let one unit tower"; this is the mirror
-- of that, one rank down.
--
-- Tier 1's band is 1-30 health (Balance.HEALTH_BANDS). Bottom of it -- glass.
return {
    name = "Glass-Mote",
    kind = "elemental",
    tier = 1,
    sprite = "assets/chars/glass_mote.png",
    stats = {
        health = 10, mana = 0, stamina = 12,
        staminaRegen = 3,
        damage = 4, magicDamage = 0,
        defense = 1, magicDefense = 4, -- it is glass: nothing stops a blow, a good deal stops a spell
        movement = 5,
        speed = 5,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 2, luck = 6,
    },
    startingItems = { "weapon_glass_shard" },
    defaultAction = "weapon_glass_shard",
    -- Basic tactics (models/ai.lua): it goes for whatever is nearest, because what it wants is any
    -- blessing at all. Choosing a target would make it a threat; taking the closest makes it weather.
    archetype = "aggressive",
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
