-- THE BROOD QUEEN: the Coin-Eaters' elite, and floor five's puzzle. Reviewed 2026-09-25 ("The Coin-Eaters"
-- artifact): "I want the fight's mechanic to be a sort of puzzle, if you fail the puzzle it's fatal".
--
--   The Nest          a heap her scarabs roll into her goes into her Hoard (status_hoard)
--   Lay in the Hoard  she lays an egg in a heap; in two turns it hatches two scarabs -- break it first
--   Roll the Hoard    at 20 Hoard she winds up and rolls the whole of it down a marked lane, and
--                     EVERYTHING in the lane is downed, hers included
--
-- THE PUZZLE is keeping the hoard under the threshold -- loot heaps first, kill the rollers, stand a body
-- in a lane so the heap stops short of her -- or reading the marked lane in time to be out of it. The heaps
-- lie differently on every board, so it is a new puzzle every time the floor re-arms. An elite, not
-- ordinary traffic: a puzzle is something you see coming and choose.
--
-- An elite on the approach only: the stand-in Slime keeps the stair (settled on review).
return {
    name = "Brood Queen",
    race = "beast",
    tier = 3,
    sprite = "assets/chars/brood_queen.png",
    stats = {
        health = 120, mana = 0, stamina = 40,
        staminaRegen = 4,
        damage = 15, magicDamage = 0,
        defense = 8, magicDefense = 5,
        movement = 3,
        speed = 3,
        skill = 4, luck = 4,
    },
    resist = { slash = 2, pierce = 2, impact = -4 },
    startingItems = {
        "weapon_mandibles", "ability_roll_the_hoard", "ability_lay_in_the_hoard",
        "utility_the_nest", false, false,
        false, false, false,
    },
    drops = { "ability_brood_sting" },
    defaultAction = "weapon_mandibles",
    archetype = "guard",
}
