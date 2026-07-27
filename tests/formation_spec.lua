-- Tests for the persistent marching formation: the grid the player arranges in "Choose Your Party"
-- (states/party_select.lua), stored on the player (models/player.lua), seated onto the board by
-- Arena.generateLayout, and carried across a save (models/save.lua). Pure logic, runs headless.

local Player = require("models.player")
local Arena = require("models.arena")
local Save = require("models.save")

-- A throwaway character stub: the formation helpers only ever key off char.id.
local function char(id) return { id = id } end

-- The board cell Arena maps a { col, row } grid slot onto, mirrored here so the expected placement is
-- spelled out rather than lifted from the code under test. Row 1 is the FRONT line and faces the enemy,
-- so it seats one row TOWARD the enemy from the party's home edge (board row `rows`): front -> rows-frows+1,
-- back -> rows.
local function expectCell(col, row, fcols, frows, cols, rows)
    local x = math.floor(col * (cols + 1) / (fcols + 1) + 0.5)
    x = math.max(1, math.min(cols, x))
    return x, math.max(1, math.min(rows, rows - frows + row))
end

return {
    {
        name = "setFormationSlot assigns a cell, formationSlot reads it back, clear removes it",
        fn = function()
            local p = { formation = {} }
            local a = char("a")
            assert(Player.formationSlot(p, a) == nil, "unset member has no slot")
            Player.setFormationSlot(p, a, 2, 1)
            local slot = Player.formationSlot(p, a)
            assert(slot and slot.col == 2 and slot.row == 1, "slot assigned")
            Player.clearFormationSlot(p, a)
            assert(Player.formationSlot(p, a) == nil, "slot cleared")
        end,
    },
    {
        name = "placing onto an occupied cell swaps the two members' cells",
        fn = function()
            local p = { formation = {} }
            local a, b = char("a"), char("b")
            Player.setFormationSlot(p, a, 1, 1)
            Player.setFormationSlot(p, b, 3, 2)
            -- Move b onto a's cell: a should take b's old cell (a true swap), never share the cell.
            Player.setFormationSlot(p, b, 1, 1)
            local sa, sb = Player.formationSlot(p, a), Player.formationSlot(p, b)
            assert(sb.col == 1 and sb.row == 1, "b took the target cell")
            assert(sa.col == 3 and sa.row == 2, "a was pushed to b's old cell")
        end,
    },
    {
        name = "placing a fresh member onto an occupied cell displaces the occupant to unplaced",
        fn = function()
            local p = { formation = {} }
            local a, b = char("a"), char("b")
            Player.setFormationSlot(p, a, 2, 2)
            -- b has no cell of its own; taking a's cell leaves a unplaced.
            Player.setFormationSlot(p, b, 2, 2)
            assert(Player.formationSlot(p, a) == nil, "the displaced occupant is now unplaced")
            local sb = Player.formationSlot(p, b)
            assert(sb.col == 2 and sb.row == 2, "the mover holds the cell")
        end,
    },
    {
        name = "a slot is clamped to the grid",
        fn = function()
            local p = { formation = {} }
            local a = char("a")
            Player.setFormationSlot(p, a, 99, 99)
            local slot = Player.formationSlot(p, a)
            assert(slot.col == Player.FORMATION_COLS and slot.row == Player.FORMATION_ROWS,
                "an out-of-range cell is pulled onto the grid")
        end,
    },
    {
        name = "generateLayout seats each member on their formation cell, in party order",
        fn = function()
            local fcols, frows = Player.FORMATION_COLS, Player.FORMATION_ROWS
            local slots = { { col = 1, row = 1 }, { col = 4, row = 1 }, { col = 2, row = 2 } }
            local layout = Arena.generateLayout({
                seed = 1, party = 3, enemies = 2, formation = slots, formationCols = fcols,
            })
            assert(#layout.partySpawns == 3, "one spawn per party member")
            for i, slot in ipairs(slots) do
                local ex, ey = expectCell(slot.col, slot.row, fcols, frows, layout.cols, layout.rows)
                local sp = layout.partySpawns[i]
                assert(sp.x == ex and sp.y == ey,
                    string.format("member %d seated at its cell (%d,%d), got (%d,%d)", i, ex, ey, sp.x, sp.y))
            end
        end,
    },
    {
        name = "the front row (row 1) seats nearer the enemy than the back row (row 2)",
        fn = function()
            -- Enemies hold the far edge (low y), the party the near rows (high y). "Front" must mean
            -- CLOSER to the enemy -- a lower y -- so a front-row member's y is above a back-row member's.
            local fcols = Player.FORMATION_COLS
            local slots = { { col = 2, row = 1 }, { col = 2, row = 2 } } -- same column, front then back
            local layout = Arena.generateLayout({
                seed = 5, party = 2, enemies = 2, formation = slots, formationCols = fcols,
            })
            local front, back = layout.partySpawns[1], layout.partySpawns[2]
            assert(front.y < back.y,
                string.format("front row (y=%d) stands ahead of the back row (y=%d)", front.y, back.y))
            assert(back.y == layout.rows, "the back row sits on the party's home edge")
        end,
    },
    {
        name = "an unplaced member (nil slot) still gets a spawn, off the formation's cells",
        fn = function()
            local fcols = Player.FORMATION_COLS
            local slots = { { col = 1, row = 1 }, nil, { col = 4, row = 1 } } -- member 2 has no cell
            slots[2] = nil
            local layout = Arena.generateLayout({
                seed = 7, party = 3, enemies = 1, formation = slots, formationCols = fcols,
                formationRows = Player.FORMATION_ROWS,
            })
            for i = 1, 3 do
                assert(layout.partySpawns[i], "member " .. i .. " has a spawn")
            end
            -- No two party members share a cell.
            local seen = {}
            for _, sp in ipairs(layout.partySpawns) do
                local k = sp.x .. "," .. sp.y
                assert(not seen[k], "spawns do not collide at " .. k)
                seen[k] = true
            end
        end,
    },
    {
        name = "with no formation, placement falls back to the even auto-spread (unchanged)",
        fn = function()
            local layout = Arena.generateLayout({ seed = 3, party = 3, enemies = 2 })
            assert(#layout.partySpawns == 3, "everyone is still seated without a formation")
            for _, sp in ipairs(layout.partySpawns) do
                assert(sp.y == layout.rows or sp.y == layout.rows - 1,
                    "auto-placed members stand on the two near rows")
            end
        end,
    },
    {
        name = "a curated board reseats the party by the formation, keeping authored spawns without one",
        fn = function()
            local fcols, frows = Player.FORMATION_COLS, Player.FORMATION_ROWS
            -- No formation: the authored colosseum spawns (all on the back row, y = rows) are kept.
            local plain = Arena.build({}, {
                biome = "castle", layout = "colosseum_sand", seed = 1,
                party = { "a", "b" }, composition = function() return { "x" } end,
            })
            for _, u in ipairs(plain.party) do
                assert(u.y == plain.rows, "an unarranged party keeps the authored back-row spawn")
            end
            -- A real formation (both on the front row) seats the party one row forward, onto walkable ground
            -- -- never on the board's own near-row shoulder pillars.
            local slots = { { col = 2, row = 1 }, { col = 3, row = 1 } }
            local built = Arena.build({}, {
                biome = "castle", layout = "colosseum_sand", seed = 1,
                party = { "a", "b" }, composition = function() return { "x" } end,
                formation = slots, formationCols = fcols, formationRows = frows,
            })
            for _, u in ipairs(built.party) do
                assert(u.y < built.rows, "an arranged front-row party stands ahead of the home edge")
                assert(built.tiles[u.y][u.x].walkable, "no member is seated on a wall")
            end
        end,
    },
    {
        name = "a formation survives a save/restore round trip, keyed by character id",
        fn = function()
            local p = Player.new()
            local member = p.roster[1]
            Player.setFormationSlot(p, member, 3, 2)
            local restored = Save.restore(Save.snapshot(p))
            assert(restored, "the snapshot restores")
            -- Find the same character by id in the restored roster and check its cell came back.
            local match
            for _, c in ipairs(restored.roster) do
                if c.id == member.id then match = c end
            end
            assert(match, "the member is still on the restored roster")
            local slot = Player.formationSlot(restored, match)
            assert(slot and slot.col == 3 and slot.row == 2, "the formation cell came back intact")
        end,
    },
    {
        name = "an empty formation is omitted from the snapshot (older saves diff clean)",
        fn = function()
            local p = Player.new()
            assert(Save.snapshot(p).formation == nil, "no formation means no field")
        end,
    },
}
