-- THE PAYMASTER: Greed's elite on floor five, and the one body in the deeps that is not what it looks like.
-- Reviewed over five rounds, 2026-09-25/26 ("The Paymaster"). The fight is
-- data/encounters/encounter_greed_the_paymaster.lua; the rules are models/paymaster.lua.
--
-- VESH SALTED THE DEEP SEAMS WITH GOLD TO DRAW GREEDY DWARVES DOWN FOR FRESH BODIES (character_vesh.lua), and
-- this is the hand that throws it. A SHADE of Vesh's own, wearing a dead dwarf's shape, walking with a living
-- crew and paying it into the ground. He does not covet the gold -- he is not a dwarf, and he is not alive.
--
-- THE DISGUISE HOLDS UNTIL THE REVEAL. The plate reads the Paymaster, the race reads dwarf (the dwarf's resist
-- line and short legs come with the shape), and the book shows only the dwarf. What the shape does NOT bring
-- is what a dwarf is inside: `raceGrants = false` (models/character.lua) keeps Stout out of the grid, so he
-- is not drawn to loose gold, never pockets a heap, takes no Dragon-Sickness and takes up no Share. Never
-- pocketing is the fight's only tell.
--
--   PAY OUT (utility_pay_out)      at the start of each of his turns a coin heap lands within 2 of a living
--                                  dwarf of his crew -- three pocketed and it is a Gilt Wyrm
--   THE PAYROLL (utility_the_payroll)  when the last OTHER dwarf of his crew falls, he turns into the Lure
--                                  (`unmasks`, character_the_lure.lua) on the same health bar, and the crew
--                                  that fell gets back up on his side. Killed first, nothing rises.
--   THE PICK (weapon_paymasters_pick)  a weak swing. He is the fight's clock, not its muscle, so he hangs back
--                                  behind his crew (`support` posture: it walks to its own).
--
-- Rated beside floor five's other elites: tier 3 on the health band, a low blow, and a mana pool the Lure
-- casts Grave-Chill out of once he turns (a shape keeps the pools -- models/transform.lua).
--
-- `class = "fighter"` for the reason every dwarf gives (Growth.NEUTRAL_CLASS): a crewman, as far as anybody
-- can see. Movement 5 is 4 after the race.
return {
    name = "The Paymaster",
    race = "dwarf",
    raceGrants = false, -- the shape, not the organs: no Stout (see the header)
    unmasks = "character_the_lure", -- what he turns into at the reveal (models/paymaster.lua; models/bestiary.lua)
    tier = 3,
    class = "fighter",
    sprite = "assets/chars/the_paymaster.png",
    archetype = "support",
    stats = {
        health = 96, mana = 30, stamina = 16,
        staminaRegen = 2,
        damage = 4, magicDamage = 0,
        defense = 3, magicDefense = 4, -- 4 after the race
        movement = 5, -- 4 after the race
        speed = 4,
        skill = 4, luck = 4,
    },
    startingItems = {
        "weapon_paymasters_pick", "utility_pay_out", "utility_the_payroll",
        false,                    false,             false,
        false,                    false,             false,
    },
    -- HIS TROPHY (round 5): the company's own gold, thrown at a tile -- a heap on open ground, a blow at a
    -- foe. Pay Out turned round, and it drops off him in either face.
    drops = { "ability_thrown_wages" },
    defaultAction = "weapon_paymasters_pick",
    -- No rules of his own: the `support` posture's walk (toward his own, EXPOSURE priced dear) is the hanging
    -- back, and its default swing is the pick at whoever walks up to him.
}
