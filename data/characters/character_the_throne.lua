-- THE THRONE: the seat's elite, and a raid fight (reviewed 2026-09-30, "Pride's Bestiary"). Four tiles of burning
-- wheel that never moves, Incorruptible like every angel, with three phases that overlap rather than follow:
--
--   THE DECREE   every turn it holds none, it lights a pattern of the floor -- the cross, the rings, the lines, in
--                turn -- and the light lands, holy, when its slot comes round (weapon_the_decree). The telegraph is
--                the board's own wind-up wash, so the fight is reading the floor and stepping off it.
--   THE SENTENCE every third turn it chains the two of the company standing furthest apart: end a turn more than
--                2 tiles from your partner and you are both hurt (utility_the_sentence).
--   HOSANNA      at 75%, 50% and 25% health two Heralds walk on, under the reinforcement telegraph (utility_hosanna).
--
-- The phases pull against each other on purpose: the Sentence asks two bodies to close up, the Decree punishes a
-- knot, and the Heralds bless the Ophan that stands guard over it.
--
-- `boss = true`: the fight is it -- off the execute and Charm tables, as every centrepiece is (and Incorruptible
-- would refuse the Charm anyway). It never moves (`movement = 0`), and nothing moves it.
--
-- It drops the Throne's Verdict, its Decree in a person's hands. On the inquisitor's table.
return {
    name = "The Throne",
    race = "angel",
    tier = 3,
    boss = true,
    sprite = "assets/chars/the_throne.png",
    footprint = { w = 2, h = 2 },
    archetype = "aggressive",
    stats = {
        health = 150, mana = 0, stamina = 30,
        staminaRegen = 4,
        damage = 4, magicDamage = 12,
        defense = 8, magicDefense = 10,
        movement = 0, -- it does not come to you
        speed = 3,
        skill = 6, luck = 2,
    },
    startingItems = {
        "weapon_the_decree", "utility_the_sentence", "utility_hosanna",
        false,               false,                  false,
        false,               false,                  false,
    },
    drops = { "ability_thrones_verdict" },
    defaultAction = "weapon_the_decree",
}
