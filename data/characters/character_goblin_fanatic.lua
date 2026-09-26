-- THE GOBLIN FANATIC, rung 2: a spinning ball and chain nobody steers (approved as pitched, 2026-09-26, "The
-- Goblins of Wrath"; its drop re-picked in round 2 as Spin Out).
--
-- Its whole turn is Spin Out: it picks a line, winds up for a turn with the lane drawn for both sides, and spins
-- three tiles along it, striking every body beside the path -- goblins included. Taunt and Charm do nothing to
-- it, and a spin that runs into lava takes it with it (Unsteered). No control and disaster, but readable: step
-- out of the line, or leave goblins standing in it. Also what the Goblin King's Cage Lever lets loose.
return {
    name = "Goblin Fanatic",
    race = "goblin",
    tier = 2,
    class = "fighter",
    discipline = "barbarian",
    sprite = "assets/chars/goblin_fanatic.png",
    archetype = "aggressive",
    stats = {
        health = 40, mana = 0, stamina = 30,
        staminaRegen = 5,
        damage = 11, magicDamage = 0,
        defense = 2, magicDefense = 1,
        movement = 3,
        speed = 4,
        skill = 4, luck = 2,
    },
    startingItems = {
        "ability_spin_out", "utility_unsteered", false,
        false,              false,               false,
        false,              false,               false,
    },
    drops = { "ability_spin_out" },
}
