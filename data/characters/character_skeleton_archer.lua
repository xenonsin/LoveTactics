-- THE SKELETON ARCHER: character_archer.lua, long after anyone came looking for it.
--
-- The ranged rank of the bone orchard, and the reason backing off is not the answer to a melee line you
-- cannot cut. Extends the living archer for the argument character_skeleton_knight.lua makes at length:
-- the rift's dead are the companies that came down before yours, so they are the bodies the player
-- already knows, wearing what happened to them. Stats, sprite, class and the kiting posture are the
-- archer's own, shared by reference.
--
-- WHAT DYING TOOK, beyond the two undead facts. The leather, the buckler and the potion, like the
-- knight's mail -- which is what lets it declare the innate lattice below. And, less obviously, the
-- discipline kit: the trap sense, the spike trap and the summoned wolf are trapper, poacher and
-- beastmaster stock, and a creature may not carry an earned class's gear (docs/bestiary.md; the rule
-- that says a wolf is not a Beastmaster). So what is left is the plainest possible hunter -- a bow and
-- the volley -- which is also exactly what a dead archer should be: the training is gone, the aim is not.
local base = require("data.characters.character_archer")

local dead = {}
for k, v in pairs(base) do dead[k] = v end

dead.name = "Skeleton Archer"
dead.race = "undead"

-- NO SHELF. A body that is not humanoid declares no `class` -- a class is a vendor shelf and a growth
-- declaration, and neither is a thing a corpse has (docs/bestiary.md, "creatures carry no discipline
-- gear"). The living blueprint's class is inherited by the copy above and cleared here, which is also
-- the line that makes this a corpse rather than a knight with a condition.
dead.class = nil
dead.discipline = nil

dead.stats = {}
for k, v in pairs(base.stats) do dead.stats[k] = v end
-- Thin, on the Skeleton Knight's measured argument: the hide is the identity, the pool is not, and a
-- body mitigating the party's two commonest damage types twice over does not resolve a fight.
-- 32 rather than 30, and the two are the same decision: thin enough that the hide is the only real
-- mitigation, and no thinner than the tier-2 floor (Balance.HEALTH_BANDS: 31-80). A body that claims a
-- rung has to hold its band, or the rung is a label (docs/bestiary.md).
dead.stats.health = 32
-- The leather came off; the innate line is what it has instead, and it is the only mitigation here.
dead.stats.defense = 1
-- Rain of Arrows is the one thing on the grid that costs anything, and it is stamina. Nothing here
-- spends mana, and a pool nothing draws on is a bar the player is invited to misread -- on a board where
-- one body's blue bar is the whole fight (character_barrow_lord.lua), that misreading is expensive.
dead.stats.mana = 0

-- INNATE MITIGATION -- see character_skeleton_knight.lua for the argument. The same lattice, on the same
-- tier-2 budget: edges and points slide through, the frame pays for both and breaks, holy at the cap.
dead.resist = { slash = 3, pierce = 3, impact = -6, holy = -6 }

-- The bow it was buried with, the volley it still remembers, and the two facts of being a skeleton.
dead.startingItems = {
    false,                "weapon_iron_bow",    "ability_rain_of_arrows",
    "utility_grave_cold", "utility_bare_bones", false,
    false,                false,                false,
}
dead.defaultAction = "weapon_iron_bow"

return dead
