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

-- A HUNTER STILL, AND DEAD -- see character_skeleton_knight.lua for the rule (2026-09-25). The class and
-- the human race are the living archer's; `undead` is what happened to it.
dead.undead = true

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

-- The lattice rides on Bare Bones (see character_skeleton_knight.lua), at the line this body used to
-- declare innate.

-- The bow it was buried with, the volley it still remembers, and the trapper's kit back where it fits
-- (the review's retrofit line): a dead hunter still knows where it laid its spikes. The wolf does not
-- come back -- it reserved a mana pool this body no longer keeps, and a dead man's dog is its own body.
-- Grave-Cold is seeded by the tag; Bare Bones is the lattice and the picture.
dead.startingItems = {
    "ability_spike_trap", "weapon_iron_bow",    "ability_rain_of_arrows",
    "utility_trap_sense", "utility_bare_bones", false,
    false,                false,                false,
}
dead.defaultAction = "weapon_iron_bow"

return dead
