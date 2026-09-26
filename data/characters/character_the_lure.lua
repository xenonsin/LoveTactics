-- THE LURE: what the Paymaster was all along (data/characters/character_the_paymaster.lua). Reviewed over five
-- rounds, 2026-09-25/26 ("The Paymaster"). Nothing fields this body directly: the Paymaster turns into it the
-- moment the last dwarf of his crew falls (models/paymaster.lua), through models/transform.lua -- the same
-- unit, tile, turn and health bar, in this body. So every number below is the SHAPE's (the kit and the flat
-- stats); the pools are the Paymaster's, carried across, and it is minted at his level.
--
-- A SHADE OF VESH'S OWN. Vesh drew the dwarves down with the gold this hand threw (character_vesh.lua), and
-- the name is his vocabulary -- the Lured are what he calls what came. Tagged undead by its race.
--
--   INCORPOREAL    there is little there for a blade or a hammer to find: a high Defense (the physical
--                  mitigation stat), and the two things a shade fears -- light and fire -- find all of it
--                  (`resist`: holy and fire, both weak). The dwarf's forge-born fire line went with the shape.
--   GRAVE-CHILL    Vesh's own bolt (ability_grave_chill): dark damage that Inters, so the heal the company
--                  reaches for lands as a wound. Paid out of the Paymaster's mana, which is why he walked in
--                  with a pool.
--   HELD IN TRUST  Vesh's Bone-Knit on its unpriced latch (utility_held_in_trust): the first blow that would
--                  fell it is refused and it stands up whole -- once.
--
-- It stops paying out and fights with these (the reveal lifts status_pay_out). It carries no drop list of its
-- own: the Paymaster's trophy (ability_thrown_wages) is the one body's, and the body walked in as him.
return {
    name = "The Lure",
    race = "undead",
    tier = 3,
    sprite = "assets/chars/the_lure.png",
    archetype = "skirmish",
    stats = {
        health = 96, mana = 30, stamina = 16,
        staminaRegen = 2,
        damage = 6, magicDamage = 15,
        defense = 10, magicDefense = 3,
        movement = 4,
        speed = 5,
        skill = 5, luck = 3,
    },
    resist = { holy = -6, fire = -6 },
    startingItems = {
        "ability_grave_chill", "utility_held_in_trust", false,
        false,                 false,                   false,
        false,                 false,                   false,
    },
    drops = {},
    defaultAction = "ability_grave_chill",
    ai = {
        { priority = "normal", act = "attack", item = "ability_grave_chill", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "exists" } },
    },
}
