-- THE STUDY: the Arcanum's half of the upgrade ladder -- abilities honed per instance, and the
-- recipes behind the company's draughts refined per type.
--
--   local panel = Study.new({ player = p, vendor = "arcanum", onClose = fn })
--
-- IT IS THE FORGE'S SCREEN WITH THE OTHER TWO TABS. Everything about the bench -- the cards, the
-- track, the three-track bill, every refusal -- is one file (ui/panels/forge.lua), and the room only
-- decides which kinds of work it offers (models/forge.lua's Forge.WORK). This module exists because
-- states/hub.lua opens a room by naming a module under ui/panels/, so the second door needs a name of
-- its own; it is deliberately the whole of the difference between the two rooms.
--
-- WHY THE SPLIT IS A SPLIT AND NOT A FIFTH TAB, and the argument is the Bastion's: a forge is heat and
-- stock and a hand that has made one before, and none of the three has anything to do with making a
-- spell land harder. The bench that held all five could not say in one sentence what it was, and a
-- player looking for where an ability gets better had no reason to try the knights' armoury.

local Forge = require("models.forge")
local ForgePanel = require("ui.panels.forge")

local Study = {}

-- A COPY RATHER THAN A STAMP ON THE CALLER'S TABLE. states/hub.lua builds a fresh opts table per
-- panel today, but a host that reused one would find the room it named last still on it.
function Study.new(opts)
    local own = {}
    for k, v in pairs(opts or {}) do own[k] = v end
    own.room = Forge.STUDY
    own.title = own.title or "Study"
    return ForgePanel.new(own)
end

return Study
