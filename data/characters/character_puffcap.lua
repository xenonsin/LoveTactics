-- THE PUFFCAP AS FLOOR ONE MEETS IT (2026-10-21). Act 0's spore pod -- no strike, a burst on death, a
-- pin it pulls itself -- unpinned so it grows with the company. character_ember_newt.lua carries the
-- argument for the split; it is the same one.
--
-- SAME NUMBERS ON PURPOSE, copied from the tutorial body so the two cannot drift. Its kit is the
-- tutorial's kit (ability_self_destruct, the bound utility_volatile_core), so the burst it carries is
-- the burst the player learned on.
local base = require("data.characters.character_demon_bomblet_tutorial")

local pod = {}
for k, v in pairs(base) do pod[k] = v end
pod.scaling = nil -- ordinary stock: grows with the company, behind the lag (Growth.combatantLevel)

return pod
