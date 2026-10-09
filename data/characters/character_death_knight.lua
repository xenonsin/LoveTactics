-- THE DEATH KNIGHT: a champion who signed with the Crown and was kept ("The Crown's Bestiary", slice B, approved
-- 2026-10-09).
--
-- BUILT AS THE DEAD ARE BUILT HERE (character_skeleton_knight.lua, character_barrow_lord.lua; commit c3381575):
-- it extends the living knight, keeps the knight's class and the human race, and is tagged `undead` on top.
--
--   BULWARK OF THE FALLEN   when any ally falls within 3 tiles of it, the fallen ally's armour closes over it as a
--                           Physical Barrier equal to half that ally's max health (utility_bulwark_of_the_fallen;
--                           models/crown_demons.lua)
--
-- THE COUNTERPLAY, STATED, and it is the review's own: kill the Death Knight first, or fight its escort outside its
-- 3 tiles, or break the barrier with magic, which a Physical Barrier does not stop.
local base = require("data.characters.character_knight")

local knight = {}
for k, v in pairs(base) do knight[k] = v end

knight.name = "Death Knight"
knight.sprite = "assets/chars/death_knight.png"
knight.undead = true
knight.tier = 3

knight.stats = {}
for k, v in pairs(base.stats) do knight.stats[k] = v end
-- The middle of the elite band (Balance.HEALTH_BANDS: 81-154): the barrier is what makes it long, not the bar.
knight.stats.health = 118
knight.stats.mana = 0
knight.stats.damage = 15
knight.stats.skill = 6

-- IT WALKS AT YOU, as the Barrow Lord does: a dead body holding its post is a diorama, not a fight.
knight.archetype = "aggressive"

-- The knight's own iron and coat, and the oath that keeps it.
knight.startingItems = {
    "weapon_iron_sword",                "armor_chainmail", false,
    "utility_bulwark_of_the_fallen",    false,             false,
    false,                              false,             false,
}
knight.defaultAction = "weapon_iron_sword"
knight.signatureWeapon = nil
knight.signatureAbility = nil

knight.drops = { "armor_oathbound_plate" }

return knight
