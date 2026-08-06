-- Saber, as the DEBUT BOUT fights her -- the boss twin of the recruitable companion
-- (data/characters/character_saber.lua). The quest's objective fields THIS blueprint
-- (data/quests/arena_debut.lua's composition); `rewardCharacter` still hands the player the clean
-- `character_saber`. That split is the whole point of the twin: everything the bout needs and the
-- companion must not keep -- the boss flag, the fuller health pool, and above all the phase relic that
-- commits her at a third of her health -- lives here and rides home with nobody. It is exactly how the
-- Demon Champion is never a recruitable body.
--
-- It EXTENDS the recruit rather than restating her, so the two can never drift. Her kit and her tactics
-- are shared by reference off the base table -- the bolas, The First Motion, the four escalating rules
-- that snap the swing, set up the net, and hold the edge deep on a mired foe. Tune the companion and the
-- boss follows; there is one Saber, fought two ways. Only the three fields the bout needs are overridden
-- below.
local base = require("data.characters.character_saber")

-- Shallow copy: every field of the companion (name, sprite, portrait, class, defaultAction, and the
-- shared-by-reference `ai` list) carries over untouched, and the three overrides below replace only what
-- the bout changes. `ai` is deliberately the SAME table the recruit uses -- it is read during planning
-- and never mutated, so sharing it is what keeps the boss's tactics identical to the companion's.
local bout = {}
for k, v in pairs(base) do bout[k] = v end

-- A quest objective: immune to instant execution (Coup de Grace), Charm and Polymorph, so beating her
-- is a bout fought down rather than a finisher skipped past. Inert on the recruit, which is why she no
-- longer carries it -- an ally is never targeted that way.
bout.boss = true

-- A deeper pool than the companion's 84: the debut's fuller toolkit (the trappers' nets, her own deep
-- holds) would kill 84 before the 33% commit threshold could ever read, and the phase IS the fight's
-- turn. Copied off the base stats so movement and speed stay exactly the companion's.
bout.stats = {}
for k, v in pairs(base.stats) do bout.stats[k] = v end
-- MUST stay above the recruit's 84, and tests/saber_debut_spec.lua fails the build if it does not:
-- the phases read off percentages of this pool, and a twin shallower than the companion cannot reach
-- its own 33% commit before the fight is over. A balance pass cut it to 81 once -- inside the tier-3
-- band, and still wrong for that reason.
bout.stats.health = 96

-- Defense is overridden here rather than inherited, and that is the whole reason this line exists.
-- This is slot 1 of the Colosseum -- the first fight of a line, on an Easy quest, against a company
-- carrying whatever the shelf sold them unforged -- and the companion's own armour value made the
-- bout a nine-swing grind against a band of four to eight (docs/balance.md). It cannot be fixed on
-- character_saber: she is a PLAYER unit for the rest of the campaign and tuning her down to settle an
-- opening duel would be paying for this fight with every later one. The bout form already keeps its
-- own health for the same kind of reason; this is that argument applied to the other axis.
bout.stats.defense = 8

-- The base kit (potion, bolas, bound First Motion in the centre) plus the bout relic in the
-- bottom-centre cell. Two bound items in two cells is fine -- the lock lives on the item, not on a
-- reserved centre slot (models/character.lua). The relic carries the three-stage script
-- (data/items/utility/utility_gatekeepers_measure.lua); it is bound, so a rogue cannot lift her whole
-- fight off her in one grab.
bout.startingItems = {
    false,           "consumable_healing_potion",   false,
    "ability_bolas", "weapon_first_motion",         false,
    false,           "utility_gatekeepers_measure", false,
}

return bout
