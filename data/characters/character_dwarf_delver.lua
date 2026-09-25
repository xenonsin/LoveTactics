-- THE DWARF DELVER, rung 1: the dwarf line's chaff, and it comes up out of the floor. Reviewed
-- 2026-09-24 as written ("The Dwarves of Greed").
--
-- ITS WHOLE KIT IS A PICK AND DELVE (data/items/ability/ability_delve.lua): go under, surface a turn
-- later beside somebody, and hit harder each time. It is the dwarf fight's arrival -- a line that is not
-- in front of you when the fight starts. What it IS comes off the race (data/races/dwarf.lua): Stout --
-- unmovable, unrobbable, and it goes for loose gold -- and Inheritance.
--
-- ALSO THE THANE'S HIRED HAND (ability_hire_hand): a summoned Delver leaves the field when the Thane
-- who paid it falls.
--
-- `class = "fighter"` (Growth.NEUTRAL_CLASS) for the reason the Fen Lancer gives: a knight or rogue table
-- lags the enemy scaling at depth. Movement 5 is 4 after the race, and Inheritance spends it.
return {
    name = "Dwarf Delver",
    race = "dwarf",
    tier = 1,
    class = "fighter",
    sprite = "assets/chars/dwarf_delver.png",
    archetype = "aggressive",
    coffer = 10, -- a day's wages, and it passes to the next dwarf when this one falls
    stats = {
        health = 24, mana = 0, stamina = 18,
        staminaRegen = 3,
        damage = 11, magicDamage = 0,
        defense = 2, magicDefense = 2, -- 3 after the race
        movement = 5, -- 4 after the race
        speed = 3,
        skill = 5, luck = 4,
    },
    startingItems = {
        "weapon_iron_hammer", "ability_delve", false,
        false,                false,           false,
        false,                false,           false,
    },
    drops = { "ability_delve" },
    defaultAction = "weapon_iron_hammer",
    signatureWeapon = "weapon_iron_hammer",
    ai = {
        -- Covet the gilded first (status_gilded): a gilded body is gold with legs.
        { priority = "high", act = "attack", targetPref = "gilded",
          when = { subject = "any_foe", test = "has_status", value = "status_gilded" } },
        -- Otherwise go under and come up beside somebody. The planner prices the exit tile by the blow
        -- it lands on the bodies beside it, so it surfaces where there is somebody to hit.
        { priority = "normal", act = "cast", item = "ability_delve",
          when = { subject = "any_foe", test = "exists" } },
    },
}
