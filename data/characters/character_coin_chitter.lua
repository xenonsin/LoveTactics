-- A coin-chitter: the Greed circle's swarm, and the body that makes chasing a mistake.
--
-- It takes coin rather than health (data/items/weapon/weapon_cutpurse_nip.lua) and it is fast enough to
-- be annoying about it. Gold is the one resource in the game that does not come back at the end of a
-- fight, so what it costs you is real -- and chasing it is a decision about whether the coin is worth
-- the tempo, which is exactly the decision the sin is about.
--
-- Tier 1's band is 1-30 health (Balance.HEALTH_BANDS).
return {
    name = "Coin-Chitter",
    kind = "beast",
    tier = 1,
    sprite = "assets/chars/coin_chitter.png",
    stats = {
        health = 14, mana = 0, stamina = 14,
        staminaRegen = 3,
        damage = 5, magicDamage = 0,
        defense = 2, magicDefense = 2,
        movement = 6, -- it gets away, which is most of the problem
        speed = 6,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 3, luck = 5,
    },
    startingItems = { "weapon_cutpurse_nip" },
    defaultAction = "weapon_cutpurse_nip",
    -- Basic tactics (models/ai.lua): `skirmish` keeps its distance between nips, which is what turns
    -- it from a body you kill into a body you decide about.
    archetype = "skirmish",
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
