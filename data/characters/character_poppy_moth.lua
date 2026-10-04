-- POPPY-MOTH: the seat's small fry, met in clouds of four to six ("Sloth's Bestiary", 2026-10-04, slice E).
--
--   POPPY DUST   when a moth is struck -- and when it is felled -- it bursts a cloud, and every body beside it
--                falls Asleep, on either side (trait_poppy_dust; models/sloth_dreamers.lua)
--
-- THE COUNTERPLAY, STATED, and it is the review's: kill them from range, or with an area thrown from outside the
-- cloud. A sword that reaches one puts its own bearer to sleep, so wake it -- hit it -- and push on. The cloud is
-- both sides' problem: a moth struck in the middle of the cloud puts its neighbours under as well, and a sleeping
-- moth is a moth that is not buffeting anybody.
--
-- NEAR THE SWOONCAP PUFFER, AND NOT THE SAME: Lust's mushroom bursts Swoon when it DIES, and walks in to pop. This
-- bursts on any HIT and lays Sleep, and does nothing at all on its own -- the wound you give it is the trigger.
--
-- Tier 1's band is 1-30 health (Balance.HEALTH_BANDS): low in it, one arrow's worth, because a body whose answer is
-- "kill it at range" has to be one you can kill at range. A beast: a moth the size of a hand, grown fat on the
-- poppies of the white wood.
return {
    name = "Poppy-Moth",
    race = "beast",
    tier = 1,
    sprite = "assets/chars/poppy_moth.png",
    archetype = "aggressive",
    stats = {
        health = 14, mana = 0, stamina = 16,
        staminaRegen = 3,
        damage = 3, magicDamage = 0,
        defense = 1, magicDefense = 3,
        movement = 5, -- it flutters straight at whoever is warmest
        speed = 4,
        skill = 4, luck = 6,
    },
    -- INNATE MITIGATION (docs/bestiary.md): wings of powder. A point goes through without catching, and a club
    -- swats it out of the air. Its own dust is a sleep it has never been troubled by.
    resist = { pierce = 2, impact = -2 },
    startingItems = {
        "weapon_moth_wings", "utility_poppy_dust", false,
        false,               false,                false,
        false,               false,                false,
    },
    drops = { "utility_poppy_censer" },
    defaultAction = "weapon_moth_wings",
}
