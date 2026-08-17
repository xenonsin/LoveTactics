-- A drift-thing: the Sloth circle's line body.
--
-- It Halts on hit, and a Halted body that is also SWORN drags its partner's tempo down with it
-- (data/traits/trait_torpor.lua). That is the circle's combo in two bodies: one lost turn costs two.
--
-- Slow and unbothered. It is not trying to reach you quickly; the whole stratum is about the fact that
-- it does not have to.
return {
    name = "Drift-Thing",
    kind = "elemental",
    tier = 2,
    sprite = "assets/chars/drift_thing.png",
    stats = {
        health = 60, mana = 0, stamina = 20,
        staminaRegen = 2,
        damage = 6, magicDamage = 9,
        defense = 7, magicDefense = 9,
        movement = 3,
        speed = 2, -- it comes around the wheel slowly, which is thematically the entire point
    },
    startingItems = { "weapon_drift_touch" },
    defaultAction = "weapon_drift_touch",
    archetype = "aggressive",
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
