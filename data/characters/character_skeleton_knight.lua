-- THE SKELETON KNIGHT: character_knight.lua, some years after it stopped moving.
--
-- IT IS NOT A NEW BODY AND MUST NOT BECOME ONE. This EXTENDS the generic knight rather than restating
-- it, exactly as character_saber_bout.lua extends the companion: the stats, the sprite, the class and
-- the tactics are the living blueprint's, shared by reference, so tuning the knight tunes its corpse and
-- the two can never drift. Everything below is the short list of things dying changed.
--
-- That is also the fiction, and the fiction is the mechanic. The rift's dead are the companies that came
-- down here before yours -- the same seven houses, the same shelves, the same kit -- and a player who
-- has fought a knight already knows what this one does. What they have to work out is the two things
-- that are different, which is a much better first question than "what is a Barrow Fiend".
--
-- AND IT IS DRAWN AS ITSELF. The inherited `sprite` is the knight's own token, and Bare Bones redraws it
-- in bone at draw time (utility_bare_bones.lua -> Character.spriteOf), so what stands on the tile is
-- recognisably the knight and unmistakably dead. No new art, and none possible -- the crossing of "which
-- body" and "what happened to it" is composed, not commissioned (tools/char_compose.lua's SKIN).
--
-- THE THREE CHANGES:
--
--   1. IT IS UNDEAD. Grave-Cold (a heal wounds it) and Bare Bones (nothing to bleed, and the picture).
--   2. THE MAIL IS GONE, and with it the buckler and the potion. A corpse keeps iron and loses leather,
--      straps and anything it would have had to drink -- and stripping the coat is what LETS it declare
--      the innate line below, since a body wearing armour buys its per-tag mitigation off a shelf and
--      may not also have a hide (docs/bestiary.md; tests/bestiary_spec.lua enforces it).
--   3. THE LATTICE. An edge slips between the ribs and takes nothing with it, a point goes through a gap
--      it was already looking for, and a mace does what a mace has always done to a frame. That is the
--      board's whole argument for the weapon nobody brought -- and the joke is that this thing is still
--      holding the sword that does not work on it either.
local base = require("data.characters.character_knight")

local dead = {}
for k, v in pairs(base) do dead[k] = v end

dead.name = "Skeleton Knight"

-- A KNIGHT STILL, AND DEAD (settled 2026-09-25, "The Dead Hand": a skeleton keeps its class and its
-- race and is tagged undead on top). The class, the human race and the knight's growth are the living
-- blueprint's, inherited by the copy above; `undead` is the one line that says what happened to it
-- (Character.instantiate seeds Grave-Cold off it). This used to clear the class and swap the race for
-- `undead`, which made a dead knight a creature with no shelf -- the rule it broke is the one this
-- file's own header argues: it is the body you already know.
dead.undead = true

-- Its own table, copied off the base, so a tune to the living knight's pools cannot be undone here by
-- accident -- and so the two fields below are visibly the only numbers that moved.
dead.stats = {}
for k, v in pairs(base.stats) do dead.stats[k] = v end
-- AND IT IS THIN. A skeleton keeps the knight's reach and loses the knight's BULK -- which is a
-- fiction that happens to be the balance, and the measurement is worth recording. Left at the living
-- knight's 68 health and 3 defense, with the innate lattice on top, three of these against the
-- reference company did not resolve AT ALL: tests/skirmish_spec.lua's harness ran out at 400 unit-turns
-- with neither side able to finish, because the party's two commonest damage types were each being
-- mitigated twice -- once by armour value and once by the hide -- on a body carrying a soldier's pool.
--
-- The hide is the identity and the pool is not, so the pool paid. What is left is a body that dies
-- quickly to the right weapon and slowly to the wrong one, which is the entire lesson; a body that died
-- slowly to everything was just a long afternoon.
dead.stats.health = 34
-- The mail came off (see 2 above); the innate line is what it has instead, and it is the ONLY
-- mitigation this body carries. Stacking an armour value under a categorical hide is what produced the
-- stalemate above.
dead.stats.defense = 1
-- IT WALKS AT YOU, and this is the one inherited field that had to be overturned rather than kept. The
-- living knight is `defensive` (models/ai.lua): it holds its post until the fight comes to it, which is
-- a posture about DISCIPLINE -- a soldier standing where it was told to stand. Nothing down here was
-- told anything.
--
-- It was also, measurably, a stalemate. A board of bodies that all wait, against a company the autobattle
-- walks forward carefully, made contact with nothing: tests/skirmish_spec.lua's harness ran out at 400
-- unit-turns with every unit on both sides at full health. A rank of dead men holding formation is not a
-- fight, it is a diorama.
dead.archetype = "aggressive"

-- It has no spells and no use for a pool. Explicit rather than inherited, because the living knight
-- carries fifteen and a skeleton holding mana is a claim this file is not making -- the one body in the
-- orchard that pays for its own deaths is the Barrow Lord, and it says so on its sheet.
dead.stats.mana = 0

-- THE LATTICE RIDES ON BARE BONES NOW (data/items/utility/utility_bare_bones.lua), at exactly the line
-- this body used to declare innate: slash 3, pierce 3, impact -6, holy -6. A humanoid buys its per-tag
-- line off what it carries and may not also have a hide (tests/bestiary_spec.lua), and with the class
-- back this is a humanoid -- so the bone that IS the lattice carries it, and every skeleton that is bone
-- gets it from the same cell.

-- The knight's own grid, minus everything that rotted: the spear and the sword it was buried holding,
-- and the two standing facts of being a skeleton. No chainmail, no buckler, no potion -- a body that
-- wounds itself by drinking one would spend the fight proving it.
dead.startingItems = {
    "weapon_iron_spear", "weapon_iron_sword",  false,
    "utility_bare_bones", false,                false,
    false,                false,                false,
}

return dead
