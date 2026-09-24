-- The general of Gluttony, and the end of the Hunter's Lodge line (docs/story.md, "The Hunter's Lodge").
-- She holds the wood's last stair (Descent.SINS' gluttony `guardian`).
--
-- WHO SHE IS: once the finest hunter the region ever produced, and the Grand Hunter turning NOW. Every
-- Grand Hunter turns; most turn into a mere beast. Gula made a pact with the Demon Lord and did not merely
-- turn -- she became the APEX of the wood, the one predator every other one in it is prey to. What the
-- bargain gave her was not strength but APPETITE, and an appetite that has eaten everything in a wood can
-- do everything in it.
--
-- THE REDESIGN (settled on review 2026-09-23, "think Kirby"). Every beast in the circle is known for one
-- thing -- the wyvern carries, the spider roots, the manticore quills, the boar charges -- and Gula EATS a
-- body and takes that thing (models/palate.lua). Her fight is three rules deep:
--
--   * DEVOUR (ability_devour) -- a corpse or a downed body of either side, or any of her OWN side at any
--     time. She heals a tenth and takes its power into her grid.
--   * THE PALATE -- the huntress holds ONE power (`palateCapacity = 1`); eating something new replaces
--     it, and THE KNOCK (a blow of 12% of her health, or a crit) makes her lose it. Her stair line is the
--     rule word for word: "there is nothing in me that keeps things".
--   * STUDIED (utility_hunters_read) -- every blow teaches her its damage kind, and the next blow of that
--     kind lands on a body that resists it. One lesson at a time: alternate, and you always land in full.
--
-- At half health she TURNS (utility_the_turning_hunger -> character_gula_the_apex), keeping what she held.
-- The beast keeps EVERYTHING it eats, grows what it eats twice, cannot be knocked, and draws breath.
--
-- AND THE FIGHT IS A WAVE BATTLE: the beasts of the whole floor keep walking in to help her, and every one
-- of them is also food (Descent.SINS' gluttony `guardian.waves`). The win is her body, not the field.
--
-- What she hands over is the Maw of the Unfed (the relic, reworked into the player's half of the Palate),
-- then the Breath and the Hide lifted off the two halves of her rule -- Descent.DROPS.gluttony.
return {
    name = "Gula, the Unsated",
    race = "human",
    tier = 4,
    -- WHAT LEVEL THESE NUMBERS WERE WRITTEN FOR. This body is authored as the fight it is at the end
    -- of its line, and models/growth.lua scales it DOWN toward the shallows rather than growing it up
    -- from a base -- so a descent that deals this circle as floor 1 meets a smaller version of the
    -- same thing instead of an unkillable one. At this level the numbers below are exactly the
    -- numbers. See Growth.spawn.
    referenceLevel = 13,
    boss = true, -- a quest objective: immune to execute (Coup de Grace) and to Charm
    sprite = "assets/chars/general_gluttony.png",
    portrait = "assets/portraits/general_gluttony.png", -- large VN portrait for conversations (falls back if missing)
    archetype = "aggressive",
    -- One power at a time (models/palate.lua). The beast she turns into declares none, and keeps everything.
    eats = true,
    palateCapacity = 1,
    stats = {
        health = 240, mana = 20, stamina = 20,
        staminaRegen = 3,
        damage = 18, magicDamage = 0, -- the copies are her threat now; her own blade is only a blade
        defense = 12, magicDefense = 8, -- warded in hide, thin against the magic she never learned
        movement = 4,
        speed = 5,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 6, luck = 4,
    },
    -- Her loadout as the 3x3 grid (row-major); false = an empty cell. Five cells are left open on
    -- purpose: they are where what she eats goes.
    startingItems = {
        "weapon_gralloch_knife", "ability_devour",             false,
        "utility_hunters_read",  "utility_the_turning_hunger", false,
        false,                   false,                        false,
    },
    defaultAction = "weapon_gralloch_knife",
    ai = {
        { priority = "normal", act = "attack", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "exists" } },
    },
}
