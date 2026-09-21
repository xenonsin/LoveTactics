-- A SWEEP OVER AUTHORED GRIDS: every ability a blueprint ships in its `startingItems` must be able to
-- FIRE from the cell it was authored in.
--
-- `requiresAdjacent` is a placement rule, and the 3x3 grid is where a blueprint states its placement.
-- Nothing had ever checked that the two agreed, and the failure is silent in the worst way: the item
-- is carried, it is drawn in the grid, its tooltip reads normally, and Combat.itemBlockReason refuses
-- it in every fight the body ever stands in. The unit simply falls through to the next thing it can
-- do, which looks exactly like an ordinary turn.
--
-- THE SENTINEL SHIPPED THAT WAY. Single Combat -- the duel verb that discipline is half built on --
-- sat in the top-right cell with two abilities for neighbours and a `requiresAdjacent = { type =
-- "weapon" }` it could never meet, so the exemplar for the discipline had a dead cell in its own
-- shop-window kit. Found by watching a Sentinel fight and wondering why it never did anything.
--
-- Sweeps every character blueprint rather than that one, because a rule about placement is a rule
-- about every grid anybody authors. Pure data, headless.

local Character = require("models.character")
local Combat = require("models.combat")

-- The two kits whose grid holds nothing that could meet the requirement from ANY cell -- a content
-- decision rather than a placement mistake. See that file's header; a row there is a waiver with a
-- reason, and the sweep below refuses to let one sit there after the kit has been fixed.
local WAIVED = require("tests.support.dead_kit_cells")

return {
    {
        name = "every ability a blueprint ships can meet its adjacency where it was authored",
        fn = function()
            local bad, seen = {}, {}
            for id in pairs(Character.defs) do
                local char = Character.instantiate(id)
                for i = 1, Character.MAX_INVENTORY do
                    local item = char.inventory[i]
                    local ab = item and item.activeAbility
                    local waived = false
                    for _, waivedId in ipairs(WAIVED[id] or {}) do
                        if waivedId == item.id then waived = true end
                    end
                    local dead = ab and ab.requiresAdjacent and not Combat.adjacencyMet(char, item)
                    -- Marked SEEN only while it is still dead. A waiver on a kit somebody has since
                    -- fixed goes unmarked and the ratchet at the bottom reports it -- which is the
                    -- whole point, and is what a `seen` set on the waiver itself would have lost.
                    if dead and waived then seen[id .. "/" .. item.id] = true end
                    if dead and not waived then
                        local where = Combat.adjacencyCandidateCells(char, item)
                        local cells = {}
                        for cell in pairs(where) do cells[#cells + 1] = cell end
                        table.sort(cells)
                        bad[#bad + 1] = string.format("%s: %s in cell %d (%s)", id, item.id, i,
                            #cells > 0 and ("try cell " .. table.concat(cells, "/"))
                                or "no cell in this grid can meet it")
                    end
                end
            end
            table.sort(bad)
            assert(#bad == 0, "abilities authored where they can never fire:\n  " ..
                table.concat(bad, "\n  "))

            -- A waiver naming a kit that has since been fixed would sit there forever excusing
            -- nothing, which is how a backlog stops being a backlog. Held to the same ratchet
            -- tests/support/slow_road_fights.lua is.
            local stale = {}
            for charId, list in pairs(WAIVED) do
                for _, itemId in ipairs(list) do
                    local key = charId .. "/" .. itemId
                    if not seen[key] then stale[#stale + 1] = key end
                end
            end
            table.sort(stale)
            assert(#stale == 0, "tests/support/dead_kit_cells.lua waives a cell that is no longer "
                .. "dead -- delete the row: " .. table.concat(stale, ", "))
        end,
    },
}
