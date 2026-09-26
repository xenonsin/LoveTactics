-- THE KOBOLD SKELETON: a Kobold Skulker that brooded too long, and the floor's chaff. Reviewed 2026-09-25
-- ("The Dead Hand").
--
-- A SKULKER STILL, AND DEAD -- the Skeleton Knight's idiom. The spear, Scurry, the fighter class and the
-- skirmisher discipline are the living blueprint's, and so is the race: Underfoot's Pack and Devotion.
--
-- DEVOTION FOUND ANOTHER GOD. A dead kobold treats a lich as its dragon (Devotion.isDragonTo): the Dragon's
-- Eye beside Vesh, Fervor when he is struck, Forsaken when he is destroyed. And he eats them (The Offering):
-- the escort is his battery, so the company kills the chaff first and reads why off his blue bar.
local base = require("data.characters.character_kobold_skulker")

local dead = {}
for k, v in pairs(base) do dead[k] = v end

dead.name = "Kobold Skeleton"
dead.undead = true

dead.stats = {}
for k, v in pairs(base.stats) do dead.stats[k] = v end
dead.stats.health = 14

dead.startingItems = {
    "weapon_iron_spear",  "utility_scurry", false,
    "utility_bare_bones", false,            false,
    false,                false,            false,
}
-- The kobold gives itself to its master; your summons can give themselves to you.
dead.drops = { "ability_offering_bone" }

return dead
