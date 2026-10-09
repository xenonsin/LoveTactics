-- CHAIN FIEND: the Crown's line demon ("The Crown's Bestiary", slice B, approved 2026-10-09).
--
--   DRAG BELOW   a hooked chain with reach 3 pulls the struck body to the fiend and Roots it there for 1 turn.
--                A pull stops on a body (weapon_drag_below; Combat.pull)
--
-- THE COUNTERPLAY, STATED, and it is the review's own: keep a wall or an ally in the line between you and it,
-- since a pull stops on a body. It is a tier-2 body, so killing it first is cheap. Cure the Root. A demon, so its
-- chain burns and it takes holy the harder.
--
-- Tier 2's band is 31-80 health (Balance.HEALTH_BANDS). Middling in it: it does not need to be hard to kill, it
-- needs you next to it.
return {
    name = "Chain Fiend",
    race = "demon",
    tier = 2,
    sprite = "assets/chars/chain_fiend.png",
    stats = {
        health = 58, mana = 0, stamina = 22,
        staminaRegen = 3,
        damage = 12, magicDamage = 0,
        defense = 5, magicDefense = 4,
        movement = 4,
        speed = 4,
        skill = 6, luck = 3,
    },
    -- Wrapped in its own chain: an edge rings off the links, and a hammer drives them into it. Fire is its own.
    resist = { slash = 3, impact = -3, fire = 3 },
    startingItems = {
        "weapon_drag_below", false, false,
        false,               false, false,
        false,               false, false,
    },
    drops = { "ability_hook_and_drag" },
    defaultAction = "weapon_drag_below",
    archetype = "aggressive",
}
