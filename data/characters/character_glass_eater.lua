-- A glass-eater: the Envy circle's line body, and the only line body in the descent that cannot kill you.
--
-- It strips two blessings a swing and hits for less than anything else on its rung
-- (data/items/weapon/weapon_vitreous_bite.lua). Which is the sin as tactics: Envy does not want to beat
-- you, it wants you to stop being better than it, and it will spend the entire fight on that instead of
-- on winning.
--
-- The design problem it solves is that "spoiler" enemies are usually ignorable. This one is not, because
-- the circle behind it cashes what it takes -- a stripped body is what Second Water's mirror copies and
-- what a Mimic finds easiest to out-trade. Ignoring the eater is a decision about the next fight.
return {
    name = "Glass-Eater",
    kind = "construct",
    tier = 2,
    sprite = "assets/chars/glass_eater.png",
    stats = {
        health = 58, mana = 0, stamina = 20,
        staminaRegen = 2,
        damage = 9, magicDamage = 0, -- soft on purpose: what it takes is not health
        defense = 6, magicDefense = 8,
        movement = 4,
        speed = 4,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 6, luck = 0,
    },
    startingItems = { "weapon_vitreous_bite" },
    defaultAction = "weapon_vitreous_bite",
    -- Basic tactics (models/ai.lua): nearest, for the mote's reason -- any blessing will do, and picking
    -- favourites would waste turns walking.
    archetype = "aggressive",
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
