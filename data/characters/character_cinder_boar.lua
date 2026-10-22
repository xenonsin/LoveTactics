-- THE CINDER BOAR AS FLOOR ONE MEETS IT (2026-10-21). Act 0's boar -- rending claws, Brimstone -- unpinned
-- so it grows with the company. character_ember_newt.lua carries the argument for the split.
--
-- SAME NUMBERS, ONE ADDITION: AN INNATE RESIST. The tutorial body declares none, and is waived from
-- having to (tests/bestiary_spec.lua's NO_INNATE) for one reason only: data/tutorials/village.lua counts
-- five blows against its exact block, and a slash/impact redistribution would move a number the lesson
-- counted. Nothing counts against THIS body, so the waiver does not reach it and it carries what every
-- other armourless beast carries. The wood's Wild Boar's hide (slash turned, impact taken) plus the
-- cinders it is named for -- the fire it walks out of Brimstone with.
local base = require("data.characters.character_demon_grunt_tutorial")

local boar = {}
for k, v in pairs(base) do boar[k] = v end
boar.scaling = nil -- ordinary stock: grows with the company, behind the lag (Growth.combatantLevel)
boar.resist = { slash = 3, impact = -3, fire = 3 }

return boar
