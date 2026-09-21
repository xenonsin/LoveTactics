-- THE BARROW LORD: the knight that was buried with a rite, and the body that teaches the rule before the
-- rift sells it to you.
--
-- Extends character_knight.lua like the Skeleton Knight beside it -- same argument, same idiom
-- (character_saber_bout.lua): it is not a new creature, it is a body the player already knows with
-- something done to it. What separates it from the common dead is one item and one number.
--
-- THE ITEM is the Barrow Binding (utility_barrow_binding.lua), which grants data/traits/trait_bone_knit.lua
-- -- the same rule, through the same engine seam, that Marrowlight will grant the player later. Kill it
-- and it stands back up, WHOLE, and goes on fighting.
--
-- THE NUMBER is its mana, and the number is the fight. Sixty, at a toll of thirty, is exactly two rises
-- and nothing spare. A pool that covered two and a half would be a pool nobody can count, and counting it
-- is the thing this body exists to teach:
--
--     THE RED BAR IS NOT THE BAR.
--
-- A company that plays this the ordinary way -- focus it down, watch it drop, look away -- gets the whole
-- thing back at full and has learned only that it took a while. A company that notices the blue bar going
-- down by thirty each time works out that there are three deaths in here and plays for burst instead,
-- because chip damage is the one thing a body that heals BY DYING does not care about.
--
-- AND THEN THE RIFT SELLS YOU THE TRICK. It pays Marrowlight (see `drops`), which is this rule with the
-- player's name on it. That ordering is the whole reason this body is authored: an aspect that makes one
-- of your own stand back up for mana is a strange thing to be handed cold, and an ordinary thing to be
-- handed by the corpse of something that spent a fight doing it to you.
--
-- THE ESCORT IS WHAT MAKES IT LEGIBLE (data/encounters/encounter_the_barrow_knight.lua): two common
-- skeletons take the same blows, stay down, and leave the player with exactly one question about the
-- third body. Nothing has to be explained.
local base = require("data.characters.character_knight")

local lord = {}
for k, v in pairs(base) do lord[k] = v end

lord.name = "Barrow Lord"
lord.race = "undead"

-- NO SHELF. A body that is not humanoid declares no `class` -- a class is a vendor shelf and a growth
-- declaration, and neither is a thing a corpse has (docs/bestiary.md, "creatures carry no discipline
-- gear"). The living blueprint's class is inherited by the copy above and cleared here, which is also
-- the line that makes this a corpse rather than a knight with a condition.
lord.class = nil
lord.discipline = nil
-- Elite: a signature relic and a rule that reads (docs/bestiary.md). The relic is the Binding.
lord.tier = 3

lord.stats = {}
for k, v in pairs(base.stats) do lord.stats[k] = v end
-- THE BOTTOM OF THE ELITE BAND (Balance.HEALTH_BANDS: 81-154), on purpose. This body is three of these
-- bars, not one, so authoring it near the top would price an elite at four hundred effective health and
-- turn its lesson into a chore. The rule is the content; the bar is not.
lord.stats.health = 84
-- EXACTLY TWO RISES at the Binding's thirty, with nothing spare. It spends mana on nothing else -- there
-- is no spell on the grid -- so every point of it is a death, and the bar reads as one.
lord.stats.mana = 60
-- A lord, not a rank body: it hits harder and reads the board better than the knight it was.
lord.stats.damage = 16
lord.stats.skill = 6
-- The mail is gone with everything else that rotted, and the innate line is what it has instead.
lord.stats.defense = 4

-- IT WALKS AT YOU, and this is the one inherited field that had to be overturned rather than kept. The
-- living knight is `defensive` (models/ai.lua): it holds its post until the fight comes to it, which is
-- a posture about DISCIPLINE -- a soldier standing where it was told to stand. Nothing down here was
-- told anything.
--
-- It was also, measurably, a stalemate: a board of bodies that all wait, against a company the autobattle
-- walks forward carefully, made contact with nothing: tests/skirmish_spec.lua's harness ran out at 400
-- unit-turns with every unit on both sides at full health. A rank of dead men holding formation is not a
-- fight, it is a diorama.
lord.archetype = "aggressive"


-- INNATE MITIGATION -- see character_skeleton_knight.lua for the argument, at the tier-3 budget
-- (Balance.INNATE_BUDGET allows 4). The mace is still the answer, which is what keeps three whole bars
-- from being a wall: a company carrying the right weapon takes this apart, and a company carrying four
-- swords finds out why it should have.
lord.resist = { slash = 4, pierce = 4, impact = -8, holy = -8 }

-- The knight's own iron, the fact of being dead, and the rite that holds him up. Both utilities are
-- `class = "creature"`, unpriced and noSteal, which is the whole of what separates this body's version
-- of the rule from the one the player gets to carry.
--
-- NO BARE BONES, and its absence is deliberate rather than an oversight: the Binding carries that
-- item's bleed immunity AND its own `crowned` skin, so the Lord holds exactly one thing that decides
-- how he is drawn. Two skin items on one grid would make his appearance depend on which cell they
-- landed in (Character.spriteOf takes the first in grid order), and this is the one body in the
-- orchard whose whole fight rests on the player being able to pick him out of the rank.
lord.startingItems = {
    "weapon_iron_spear",  "weapon_iron_sword",      false,
    "utility_grave_cold", "utility_barrow_binding", false,
    false,                false,                    false,
}

-- WHAT IT IS KNOWN FOR (docs/drops.md). It sits on no circle's roster, so an authored list is its only
-- way of being known for anything -- the King Slime's argument.
--
-- Marrowlight is the whole reason this body exists, and it is first. The Turning Year is the other half
-- of the same evening -- what a barrow does to the ground around it -- and it gives the list a second
-- entry so a company that already owns the rite is not fighting for nothing (Descent.dropFor walks the
-- list and skips what you hold).
lord.drops = {
    "utility_marrowlight",
    "utility_the_turned_year",
}

-- Basic tactics (models/ai.lua): it presses the body closest to falling. Deliberately the King Slime's
-- rule and for a related reason -- what makes a death matter here is WHERE it happens, and a body that
-- dies standing over the party's weakest is a body that gets back up there.
lord.ai = {
    { priority = "high", act = "attack", targetPref = "lowest_hp",
      when = { subject = "any_foe", test = "exists" } },
}

return lord
