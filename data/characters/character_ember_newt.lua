-- THE EMBER NEWT AS FLOOR ONE MEETS IT (2026-10-21, "the tutorial characters need to also be present on
-- the first floor as encounters"). The same newt Act 0 opens on -- name, sprite, spit -- grown into a fight: it scales
-- with the company, and it carries the four numbers below instead of the lesson's.
--
-- WHY A SECOND FILE AND NOT THE FIRST ONE IN A POOL. character_demon_imp_tutorial is pinned
-- (`scaling = false`) because the prologue COUNTS against it: one sword stroke and it falls, and
-- tests/enemy_scaling_spec.lua holds every Act 0 body to blueprint level so that stays true. Fielded on
-- a floor a company walks again at level six, a pinned newt is a body that cannot touch anybody, and
-- after the Crown the circles shuffle (Descent.sinOrder), so the wood can sit nine floors down. One
-- blueprint cannot be both, so it is split: the lesson keeps its counted body, the rift gets this one.
--
-- IT WAS A RE-PIN AND IS A REBALANCE NOW (2026-11-13). It shipped as a byte-for-byte copy of the lesson,
-- on the theory that the rift's newt should be the one the player already met. But the lesson's numbers
-- are tuned to LOSE: 14 health is one sword stroke by design, speed 2 hands the party every opening, and
-- floor one cuts every ordinary fight to three bodies (Descent.OPENING_CAP). Three bodies that each die
-- before they act are not a fight, and the author met it as one an unlevelled company auto-won. Measured
-- through `. early-floors` (30 seeds, floor 1): 12 unit-turns and nothing spent, the lightest kill-all on
-- the floor -- and raising speed and the spit ALONE moved nothing, because the newts were dead before
-- either mattered. Health is the dial with authority.
--
-- So the rift's newt keeps the lesson's identity -- the same body, sprite, spit, mana-as-shot-count, the
-- same hide -- and changes four numbers, overridden below rather than retyped so everything else still
-- follows the tutorial file:
--
--   * health 14 -> 28: two strokes instead of one, a wolf's pool (character_wolf_grunt).
--   * speed 2 -> 5, movement 4 -> 5: a wolf's tempo. The newt now spits before the company closes and
--     can step back out to its two tiles, which is the fight encounter_ember_newts.lua says it is.
--   * magicDamage 10 -> 14: about twelve a spit into the company's front line at floor one.
--
-- Measured after: about 16 unit-turns, and the clutch costs a potion or a Heal. The tutorial body is
-- untouched, so the lesson still counts one stroke.
local base = require("data.characters.character_demon_imp_tutorial")

local newt = {}
for k, v in pairs(base) do newt[k] = v end
newt.scaling = nil -- ordinary stock: grows with the company, behind the lag (Growth.combatantLevel)

-- A fresh stats table: the tutorial's is shared, and writing into it would retune the lesson too.
newt.stats = {}
for k, v in pairs(base.stats) do newt.stats[k] = v end
newt.stats.health = 28
newt.stats.speed = 5
newt.stats.movement = 5
newt.stats.magicDamage = 14

return newt
