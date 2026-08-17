-- A RIVAL COMPANY: four bodies, a full player-shaped loadout each, never the same twice.
--
-- The marquee human fight, and the one that makes the descent feel populated: you are not the only
-- company that came down here, and the others brought builds too. Everything about the roster is
-- models/warband.lua's -- role buckets over the 79 discipline exemplars, drawn combo-aware, seeded off
-- the run so a resumed floor meets the same company and no company is ever stored.
--
-- IT DROPS NO KIT, and that is a decision rather than an oversight. This is the only enemy carrying a
-- complete player loadout, so lootable gear would have made it the most farmable fight in the game. It
-- pays a premium in coin and house materials through the ordinary depth-sloped salvage instead
-- (models/spoils.lua): the reward for beating a real company is a good purse, not a shortcut past the
-- Forge.
--
-- The require is at file scope and safe: models/warband.lua requires nothing, exactly as
-- models/curve.lua does not, so this cannot close a cycle back through the registry that loads it.
local Warband = require("models.warband")

return {
    name = "A Rival Company",
    kind = "combat",
    -- Heavy, because this is meant to be the human fight the road is MADE of rather than a rare event.
    -- The named warbands beside it are the set-pieces; this is the traffic.
    weight = 8,
    minDay = 2,
    composition = function(ctx)
        return Warband.compose(ctx)
    end,
}
