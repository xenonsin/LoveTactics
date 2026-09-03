-- A rime-gnat: the Sloth circle's swarm, and the cheapest way to lose a turn.
--
-- It Freezes what it nips (data/items/weapon/weapon_rime_nip.lua). On the one board where crossing costs
-- nothing, what a circle has to charge for is the clock -- and three gnats is somebody's whole turn.
--
-- Tier 1's band is 1-30 health (Balance.HEALTH_BANDS). Bottom of it.
return {
    name = "Rime-Gnat",
    kind = "elemental",
    tier = 1,
    sprite = "assets/chars/rime_gnat.png",
    stats = {
        health = 10, mana = 0, stamina = 12,
        staminaRegen = 3,
        damage = 3, magicDamage = 4,
        defense = 1, magicDefense = 3,
        movement = 6,
        speed = 6,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 2, luck = 6,
    },
    startingItems = { "weapon_rime_nip" },
    defaultAction = "weapon_rime_nip",
    archetype = "aggressive",
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
