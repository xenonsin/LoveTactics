-- The Grendlemaw: Gluttony's mythic, and the one body in the circle that takes a party member OUT
-- rather than down.
--
-- It swallows whole (data/items/weapon/weapon_grendlemaw_gullet.lua, on status_suspended): the body it
-- eats cannot act, cannot answer, cannot move and cannot be reached -- by anything, including you. That
-- dual edge is what keeps it from being merely nasty. A swallowed knight is not dead, it is absent, and
-- a party of three on a mire board where crossing already costs more than anywhere else is quite enough
-- of a fight.
--
-- Its reach is one tile and its swing is slow, so it is answered the way a big animal is answered: see
-- it coming and do not be there. Nothing about it is a surprise except how much of your company it is
-- willing to remove.
--
-- ONE PER FLOOR AT MOST. Two Grendlemaws could halve a company in two turns with no interaction, which
-- is why encounter_gluttony_fen_mouth.lua fields it alone with a screen of chaff in front.
return {
    name = "Grendlemaw",
    kind = "beast",
    tier = 3,
    sprite = "assets/chars/grendlemaw.png",
    stats = {
        health = 118, mana = 0, stamina = 26,
        staminaRegen = 2,
        damage = 16, magicDamage = 0,
        defense = 10, magicDefense = 4,
        movement = 3,
        speed = 2, -- it comes around slowly, which is the whole telegraph
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 4, luck = 5,
    },
    startingItems = { "weapon_grendlemaw_gullet" },
    defaultAction = "weapon_grendlemaw_gullet",
    -- Basic tactics (models/ai.lua): it eats whatever is nearest. Aiming for the weakest would make it
    -- an execution engine; aiming for the closest makes it a thing you can position around.
    archetype = "aggressive",
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
