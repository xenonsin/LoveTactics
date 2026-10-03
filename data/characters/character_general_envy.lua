-- THE MANY FACED ONE: the general of Envy, on floor twelve's stair. Reviewed over three rounds, 2026-10-01..03
-- ("Envy's Bestiary", the general's rows), and it REPLACES Livia, the Unborn on the same id: the alchemist's
-- homunculus who copied your strongest at the bell. Her rule and her Glass are left on disk (the Glass is still a
-- trophy on the alchemist's rack), and nothing fields them now.
--
-- WHO IT IS: the face every Faceless envies, and the race's own crown (data/races/faceless.lua). Its soldiers
-- wear soldiers; it wears GENERALS. The seat floor it stands under is its court, practising. Its own shape is seen
-- for a moment at most, between faces: a crown of a thousand faces with no head under it.
--
-- THE FIGHT IS models/many_faced.lua, and the header there argues it in full:
--   * it wears, in turn, the general of every circle above Envy in this run, in the order the company met them
--     (Gula, Luxuria, Avaritia, Furor, Acedia on the authored way down; the circles BELOW, nearest first, when a
--     shuffled campaign deals Envy early) -- each through the transform, real body and kit, openers fired;
--   * each form calls that stair's escort and its waves, and its court shapeshifts into the next form's adds;
--   * one bar in six equal shares -- five forms, then the split -- and dropping through a share moves on;
--   * the split: an exact copy of each body in the company, items, stats and tactics, on one health pool.
--
-- REDUCED BY DESIGN. 540 is six shares of 90, so each form holds about three-eighths of what its general holds on
-- her own stair. A form is that fight, shortened, which is the author's note: "their health could be reduced so
-- the fights are not just repeats of all the floors". Its own flat stats are a placeholder in the strictest sense
-- -- every form brings its own, and the split brings yours.
--
-- A Thousand Faces is its race's rule too, and is never allowed to choose: `faceLocked` is set at the bell, since
-- its forms come from its own rule (the Crown of a Thousand Faces in its first cell, so it opens first).
return {
    name = "The Many Faced One",
    race = "faceless",
    tier = 4,
    -- WHAT LEVEL THESE NUMBERS WERE WRITTEN FOR (models/growth.lua scales it down toward the shallows, so a
    -- shuffled descent that deals Envy early meets a smaller version of the same thing).
    referenceLevel = 13,
    boss = true, -- a quest objective: immune to execute (Coup de Grace) and to Charm
    revivable = false,
    sprite = "assets/chars/general_envy.png",
    portrait = "assets/portraits/general_envy.png", -- large VN portrait for conversations (falls back if missing)
    archetype = "aggressive",
    stats = {
        health = 540, mana = 60, stamina = 30, -- the one bar every form and the split are cut from
        staminaRegen = 3,
        damage = 12, magicDamage = 12,
        defense = 10, magicDefense = 10,
        movement = 4, -- 5 after the race
        speed = 4,
        -- Accuracy (docs/accuracy.md): authored, and never grown.
        skill = 6, luck = 6,
    },
    -- The crown first, so its opener runs before the race's and the forms are chosen before anything reshapes.
    startingItems = {
        "utility_crown_of_a_thousand_faces", false, false,
        false,                               false, false,
        false,                               false, false,
    },
}
