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
-- IDENTITY LEVER (creature identity pass, 2026-11-19): POSITION. The mote fields from floor 11 and the mirror
-- that cashes its stripping in only from 12, so on 11 it stripped a blessing and was nothing. It now shatters
-- where it falls into Glass Shards (trait_shatters_to_shards, data/hazards/hazard_glass_shards.lua): a foe that
-- ends a turn there takes 3 damage, through armour, and loses a blessing. Kill it where you will not need to stand. The cut is the
-- half a company with no blessings still feels. (The other option on the row, a floor-12-only pool, was passed
-- over: the mote is Leviathan's escort on 11 and the stair would have lost its swarm.)
--
-- Tier 1's band is 1-30 health (Balance.HEALTH_BANDS). Bottom of it -- glass.
return {
    name = "Glass-Mote",
    race = "elemental",
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
    -- INNATE MITIGATION (models/character.lua `resist`), in the same unit an armour's resist
    -- table is written in and summed into the same total. This body wears nothing, so this is
    -- what it has instead of a coat -- and the negative line is not an oversight, it is the
    -- price. See docs/bestiary.md, "What a creature wears instead of armour".
    --   A chip of glass turning in the air. Nothing catches on it.
    --   A chip of glass.
    resist = { slash = 2, impact = -2 },
    startingItems = { "weapon_glass_shard" },
    defaultAction = "weapon_glass_shard",
    -- Basic tactics (models/ai.lua): it goes for whatever is nearest, because what it wants is any
    -- blessing at all. Choosing a target would make it a threat; taking the closest makes it weather.
    -- TARGETING (2026-11-19): ahead of this rule, the glass envies the FAIREST (models/fairest.lua -- the most
    -- blessed, then the healthiest) and strikes it whenever it can reach it this turn (models/envy_oneoffs.lua).
    archetype = "aggressive",
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
