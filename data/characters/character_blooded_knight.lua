-- THE BLOODED KNIGHT: character_knight.lua, standing with a succubus on a Lust floor (2026-11-19, the
-- creature identity pass).
--
-- WHY A SECOND FILE. The audit failed the Knight Lust fields: "a generic class template, just a wall with
-- more armour". The approved lever was a guard -- a blow aimed at the ally beside him is taken by him --
-- and the generic knight could not take it. character_knight is the reference company's front line
-- (Descent.COMPANY), the template a hired knight is rolled from, a draft body, the base three skeletons
-- extend, and the stock body half the suite fights with; an intercept on it would move every one of those.
-- So this EXTENDS the generic knight the way character_skeleton_knight does -- stats, sprite, class, drops
-- and tactics shared by reference -- and changes one cell of the grid. The three Lust fights that field a
-- blooded knight name this file (the Long Gallery, the Chapter House, the Lady Chapel).
--
-- ITS IDENTITY LEVER IS THE GUARD. The chainmail is swapped for the Warden's Oath (armor_wardens_oath),
-- which carries the knight's own Oathward: the first blow each turn on an adjacent ally is taken by him
-- instead. In these fights the ally beside him is the succubus who holds him -- so the room's lesson
-- ("cut the charmer and the room empties") now has a body in the way. The answers are an ORDER and a
-- POSITION: kill him first, or pull her out of his reach, or spend a cheap blow to draw the guard and
-- land the real one after it. The guard cools down (six ticks), so it is a shield, not an aegis.
--
-- The coat is a fair trade rather than a buff: more plate (defense 6 against the mail's 2) and less
-- turned edge (no slash or pierce line), and the barrier it banks is paid for in blows he took for her.
--
-- STILL "Knight" IN THE FICTION, and named apart only because the bestiary addresses a body by its name.
local base = require("data.characters.character_knight")

local knight = {}
for k, v in pairs(base) do knight[k] = v end

knight.name = "Blooded Knight"

-- The grid, with the one cell changed. Copied rather than edited in place, because `base` is the live
-- blueprint every other knight reads.
knight.startingItems = {
    "weapon_iron_spear", "weapon_iron_sword", "armor_wardens_oath",
    "armor_buckler",     "consumable_healing_potion", false,
    false,               false,               false,
}

-- Basic tactics (models/ai.lua): a knight already fights for the ally a foe threatens (AI.knightGuard),
-- so the rule here is the one that makes the guard and the blow agree -- swing at whatever is on HER.
-- `nearest` from beside the succubus is the body that just walked up to her.
knight.ai = {
    { priority = "high", act = "attack", targetPref = "nearest",
      when = { subject = "nearest_foe", test = "in_reach" } },
}

return knight
