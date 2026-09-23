-- SPIN: the Giant Spider restrings the glade. A strand breaks after its one catch (hazard_web.lua), so
-- the web the wood started with runs out, and this is how it comes back.
--
-- THREE STRANDS ACROSS THE APPROACH, one tile short of the foe it is aimed at: the line runs
-- perpendicular to the spider's own line to them, so the web crosses the lane the foe has to walk down
-- rather than lying along it. Short of them on purpose -- laying it under the foe would be the Silk Shot
-- again at area scale, and Cast the Net (the Mother's) is the one that does that.
local function strandCells(_, tx, ty, unit)
    local dx, dy = 0, 0
    if unit then
        dx = (unit.x > tx and 1) or (unit.x < tx and -1) or 0
        dy = (unit.y > ty and 1) or (unit.y < ty and -1) or 0
        -- A diagonal line of approach: the dominant axis wins, as Combat's own facing does.
        if dx ~= 0 and dy ~= 0 then
            if math.abs(unit.x - tx) >= math.abs(unit.y - ty) then dy = 0 else dx = 0 end
        end
    end
    local cx, cy = tx + dx, ty + dy
    local px, py = -dy, dx -- the perpendicular
    if px == 0 and py == 0 then px = 1 end
    return {
        { x = cx - px, y = cy - py },
        { x = cx, y = cy },
        { x = cx + px, y = cy + py },
    }
end

return {
    name = "Spin",
    description = "Lays three tiles of Web across the ground just short of a foe.",
    flavor = "The glade was open when you came into it. It is being closed behind you.",
    sprite = "assets/items/ability_spin.png",
    type = "ability",
    class = "creature",
    tags = { "silk" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 5,
        requiresSight = true,
        minRange = 2, -- a foe already beside it is a foe for the fangs, not the loom
        speed = 4,
        cost = { stat = "stamina", amount = 8 },
        aoe = { cells = strandCells },
        effect = function(fx)
            for _, c in ipairs(fx.aoeCells()) do fx.placeHazard(c.x, c.y, "hazard_web") end
        end,
    },
}
