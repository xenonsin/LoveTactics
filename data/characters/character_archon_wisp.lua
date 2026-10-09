-- An Archon's Wisp: the spirit a fallen Archon throws clear (data/races/archon.lua, models/spirit.lua). Never
-- dealt by any encounter -- it only arrives through Spirit Body -- so it is in no floor's pool and counts toward
-- no variety measure.
--
-- SMALL, SLOW AND WORTH STOPPING. Two tiles a turn, so a wisp thrown three tiles off needs two of its turns to
-- get home, which is about the downed window (status_downed): a company that does nothing loses the body back,
-- and a company that sends one body after it can kill it or stand on the corpse. A light pool, so one honest
-- blow ends it; it carries no weapon and hits nothing.
--
-- IT IS AN ARCHON (race), which hands it Spirit Body too -- models/spirit.lua refuses to release a summon, so
-- a wisp's death is final.
return {
    name = "Archon's Wisp",
    race = "archon",
    tier = 1,
    sprite = "assets/chars/archon_wisp.png",
    revivable = false, -- a spirit leaves no body of its own
    stats = {
        health = 14, mana = 0, stamina = 10,
        staminaRegen = 2,
        damage = 0, magicDamage = 0,
        defense = 0, magicDefense = 2,
        movement = 2,
        speed = 4,
        skill = 0, luck = 4,
    },
    startingItems = { "utility_wisp_homeward" },
    -- No fists either: without this the gather walk's attack rule sends it bare-handed at the nearest foe
    -- instead of home. The engine reads it as a body that cannot strike anything, ever.
    unarmed = false,
    -- Walks to its body (models/ai.lua's `gather`, steered by the `seeksBody` flag on trait_homeward).
    archetype = "gather",
}
