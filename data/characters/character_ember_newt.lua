-- THE EMBER NEWT AS FLOOR ONE MEETS IT (2026-10-21, "the tutorial characters need to also be present on
-- the first floor as encounters"). The same newt Act 0 opens on -- name, sprite, spit, numbers -- with ONE
-- difference: it grows.
--
-- WHY A SECOND FILE AND NOT THE FIRST ONE IN A POOL. character_demon_imp_tutorial is pinned
-- (`scaling = false`) because the prologue COUNTS against it: one sword stroke and it falls, and
-- tests/enemy_scaling_spec.lua holds every Act 0 body to blueprint level so that stays true. Fielded on
-- a floor a company walks again at level six, a pinned newt is a body that cannot touch anybody, and
-- after the Crown the circles shuffle (Descent.sinOrder), so the wood can sit nine floors down. One
-- blueprint cannot be both, so it is split: the lesson keeps its counted body, the rift gets this one.
--
-- SAME NUMBERS ON PURPOSE, and copied rather than retyped, so the two cannot drift: this is a re-pin,
-- not a rebalance. Retune the newt in the tutorial file and both move; retune it HERE only if the rift's
-- newt is meant to stop being the one the player already met.
local base = require("data.characters.character_demon_imp_tutorial")

local newt = {}
for k, v in pairs(base) do newt[k] = v end
newt.scaling = nil -- ordinary stock: grows with the company, behind the lag (Growth.combatantLevel)

return newt
