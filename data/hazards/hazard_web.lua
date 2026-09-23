-- WEB: the forest's signature ground, and what a spider strings before the bell.
--
-- Gluttony is a beast hunt, and every animal in the wood hunted by closing on you until this one. The
-- web is the half of the hunt that WAITS: it is already down when the fight opens -- two or three
-- strands wherever the wood is (data/biomes/forest.lua), and more in the gap between the lines for every
-- spider standing there (a body's `seedsGround`, laid by models/arena.lua) -- so which lane to cross is
-- the first decision of the fight rather than something learned by walking into it.
--
-- WHAT IT DOES TO A BODY THAT STEPS IN: Root (it cannot walk, nothing can move it, and a walk that
-- reaches it ends there -- status_root's stopsMovement) and Mark (the strand shivering, telling every
-- spider on the board where the catch is -- and the Hunter's Lodge's own setup status, met here from
-- the receiving end first).
--
-- ONE CATCH, THEN IT BREAKS. The first body it holds pulls it down to HOLD ticks -- a Root's own
-- length -- and both statuses are ZONE-BOUND (neither lingers, so Hazard stamps them with this zone as
-- their source): when the strand goes, the Root and the Mark go with it, on one clock. A strand left
-- standing is a strand still waiting for somebody, and a spider restrings the lane with Spin or Cast the
-- Net. A body immune to Root (the Slipchain Charm) is not caught, and the strand stays whole.
--
-- A SPIDER WALKS IT (trait_silkfoot's `walksSilk`) and is quicker on it than off it: instead of the
-- catch it wears status_on_the_web, which lifts the moment it steps clear. `welcomes` tells the AI the
-- same thing (Hazard.tileBias / Hazard.tollMap): every other body routes around a web, a spider routes
-- onto one.
--
-- FIRE BURNS IT. `dousedByTags` answers a fire cast over the tile (Combat's footprint douse) and fire
-- spreading onto it (it is `burnable`, and new ground douses what it is doused by -- Hazard.place).
-- Unsided, like all terrain: a slow boar blunders into it exactly as a knight does.
local HOLD = 6 -- ticks: the length of a Root (data/status/status_root.lua), so strand and Root end together

local function walksSilk(unit)
    local Trait = require("models.trait") -- lazily: trait.lua is a long way down the require graph
    return unit ~= nil and unit.traits ~= nil and Trait.flag(unit, "walksSilk") ~= nil
end

return {
    name = "Web",
    description = "Holds whoever steps in and Marks them. Breaks once its catch comes free; fire burns it away.",
    tags = { "silk", "web", "burnable" },
    duration = 9999, -- a strand waits for the whole fight; what ends it is a catch or a flame
    disposition = "hostile",
    dousedByTags = { "fire" },
    welcomes = walksSilk,
    onEnter = function(ctx)
        local unit = ctx.unit
        if walksSilk(unit) then
            ctx.applyStatus(unit, "status_on_the_web")
            return
        end
        local held = ctx.applyStatus(unit, "status_root")
        ctx.applyStatus(unit, "status_mark")
        -- The tooltip's dry run has no board and no live zone to shorten.
        if held and ctx.combat and ctx.hazard then
            ctx.hazard.remaining = math.min(ctx.hazard.remaining, HOLD)
        end
    end,
}
