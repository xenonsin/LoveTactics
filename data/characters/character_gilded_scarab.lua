-- THE GILDED SCARAB: Greed's dung beetle, and the ball is gold. Chaff of the Coin-Eaters, the family that
-- MOVES the floor's gold where every other body in the deeps pockets it, eats it or guards it. Reviewed
-- 2026-09-25 ("The Coin-Eaters" artifact).
--
--   Roll       it pushes a coin heap down a lane, merging the heaps it crosses, and hits the first foe
--              for damage by the gold in it -- or rolls it into the Brood Queen's hoard
--   Carry Home with a Brood Queen on the board, it rolls heaps toward her instead, into her Hoard
--   Mandibles  a plain bite, for when there is no gold to push
--
-- THE COUNTERPLAY: loot a heap before a scarab reaches it, or kill the scarabs while the heaps are small.
-- Its shell turns an edge and a point and cracks under a hammer.
return {
    name = "Gilded Scarab",
    race = "beast",
    tier = 1,
    sprite = "assets/chars/gilded_scarab.png",
    stats = {
        health = 24, mana = 0, stamina = 20,
        staminaRegen = 3,
        damage = 9, magicDamage = 0,
        defense = 3, magicDefense = 2,
        movement = 4,
        speed = 5,
        skill = 3, luck = 4,
    },
    resist = { slash = 1, pierce = 1, impact = -2 },
    startingItems = {
        "weapon_mandibles", "ability_roll_heap", "ability_carry_home",
        false, false, false,
        false, false, false,
    },
    drops = { "ability_gathering_roll" },
    defaultAction = "weapon_mandibles",
    archetype = "aggressive",
}
