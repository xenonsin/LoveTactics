-- The ground a Deadfall has rigged (data/items/ability/ability_deadfall.lua): nine tiles, one rig. SEEN,
-- and hostile, so every planner walks round it -- including the kobolds who laid it.
--
-- The first FOE of the rig's side to step onto any of its tiles SPRINGS it: all nine cells are taken up
-- and replaced by falling rock (hazard_deadfall_falling), which lands a turn later. The cells share one
-- `rig` table (stamped by the ability), which is how one boot on a corner springs the whole square. A body
-- on the layer's own side walks over it and sets nothing off.
return {
    name = "Deadfall",
    description = "Rigged ground. The first foe to step in springs it: a turn later, rocks fall on the whole square.",
    tags = { "earth" },
    duration = 40, -- about eight turns: a rig left too long slips its rope
    disposition = "hostile",
    onEnter = function(ctx)
        local unit, combat, cell = ctx.unit, ctx.combat, ctx.hazard
        if not (unit and unit.alive and combat and cell.alive) or ctx.isAlly(unit) then return end
        local Hazard = require("models.hazard")
        local cells = (cell.rig and cell.rig.cells) or { cell }
        local spots = {}
        for _, h in ipairs(cells) do
            if h.alive then
                spots[#spots + 1] = { x = h.x, y = h.y }
                Hazard.consume(combat, h)
            end
        end
        for _, s in ipairs(spots) do
            Hazard.place(combat, s.x, s.y, "hazard_deadfall_falling", { side = cell.side, amount = cell.amount })
        end
        require("models.combat").logEvent(combat, "action", string.format(
            "%s springs a deadfall. The rock above creaks.", (unit.char and unit.char.name) or "Something"), unit)
    end,
}
