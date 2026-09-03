-- THE MASS NEVER OUT-BRIGHTENS THE FLOOR, on any of the eight grounds.
--
-- A cell that is not there is drawn in the biome's own material -- the forest's canopy, the underworld's
-- basalt, the tundra's drift -- because the floor was cut out of that material and a dungeon whose walls
-- do not say where you are is a dungeon anywhere. What that cannot be allowed to cost is the reading: if
-- the mass comes out brighter than the ground beside it, the floor inverts and reads as bright fields
-- with dark paths between them, which is the opposite of the truth and the first thing a player has to
-- get right.
--
-- IT WAS A CONSTANT AND A CONSTANT CANNOT DO IT. One dim (0.45) held the forest and broke the tundra and
-- the desert, because a biome authors its fill against its floor as a COUNTRY reads: a canopy is darker
-- than a trail, and a snow drift is far brighter than trodden snow. Preserving that relationship is
-- exactly wrong on a board where the fill is a hole rather than a hedge.
--
-- So the dim solves for a relationship instead (ui/overworld_map.lua's massDimFor), and this is that
-- relationship asserted over every tileset in the game -- including ones added later, which is the half
-- a screenshot cannot cover. Two of the eight would have needed their own screenshot to catch.

local OverworldMap = require("ui.overworld_map")
local Tileset = require("models.tileset")
local Biome = require("models.biome")

local function biomeIds()
    local ids = {}
    for id in pairs(Biome.defs) do ids[#ids + 1] = id end
    table.sort(ids) -- `pairs` over the registry is unspecified; the report has to reproduce
    return ids
end

return {
    {
        name = "on every ground, the mass reads darker than the darkest a place gets",
        fn = function()
            local bad = {}
            for _, id in ipairs(biomeIds()) do
                local def = Tileset.get(Biome.get(id).tileset)
                local mass = OverworldMap.massLum(def)
                local place = OverworldMap.darkestPlaceLum(def)
                -- The darkest a place ever gets is the floor colour under unread fog, which is what
                -- nearly the whole board looks like on the frame the company arrives at.
                if not (mass < place) then
                    bad[#bad + 1] = string.format("%s (mass %.3f vs place %.3f)", id, mass, place)
                end
            end
            assert(#bad == 0,
                "the mass out-brightens the floor on: " .. table.concat(bad, ", ")
                .. " -- a floor there reads as fields with paths between them")
        end,
    },
    {
        name = "every ground keeps its own colour -- the mass is dimmed, never recoloured",
        fn = function()
            -- The other half of the ask, and the one a brightness rule could satisfy by painting every
            -- biome the same near-black. A dim is a scale on the authored colour, so the hue survives:
            -- no two grounds may end up with the same mass, and none may lose its cast entirely.
            local seen = {}
            for _, id in ipairs(biomeIds()) do
                local def = Tileset.get(Biome.get(id).tileset)
                local fill = def.tiles.thicket.color
                local dim = OverworldMap.massDimFor(def)
                assert(dim > 0 and dim <= 1, id .. " solved a dim outside 0..1: " .. dim)

                local r, g, b = fill[1] * dim, fill[2] * dim, fill[3] * dim
                local key = string.format("%.3f/%.3f/%.3f", r, g, b)
                assert(not seen[key], id .. " draws its mass the same colour as " .. tostring(seen[key]))
                seen[key] = id

                -- ...and it is still recognisably that material: the channel spread the artist authored
                -- survives the dim in proportion, so a green canopy is still green.
                local hi = math.max(fill[1], fill[2], fill[3])
                local lo = math.min(fill[1], fill[2], fill[3])
                if hi - lo > 0.05 then
                    assert(math.max(r, g, b) - math.min(r, g, b) > 0.005,
                        id .. "'s mass lost its cast -- it is a colour, not a shade of black")
                end
            end
        end,
    },
}
