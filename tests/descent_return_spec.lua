-- THE RETURN TRIP: what a company comes back to after it is beaten.
--
-- A wipe does not end a descent. The bodies wake at the Gate, poorer and hurt, and the stair they walk
-- back down opens on the SAME FLOOR they fell on, laid out the way they left it -- with everything they
-- were carrying in a heap on the tile where it happened.
--
-- None of that was pinned anywhere, and it is the property the whole mode rests on. Everything the wipe
-- path does is destructive -- drop the pack, take the coin, wound the company, save the board -- so the
-- failure this file exists to catch is a well-meaning tidy-up on that path resetting the one field that
-- must not move. A run reset to floor one after a wipe is a nine-floor walk the player already made,
-- and nothing else in the game would say a word about it.
--
-- The contrast at the bottom is the deliberate half: GIVING UP does end a run, and the next one starts
-- at the top. Two endings, two answers, and this file holds them side by side so neither can be
-- "fixed" into the other by somebody reading only one.

local Descent = require("models.descent")
local Player = require("models.player")
local Save = require("models.save")

-- A company standing on `floor`, having beaten everything above it.
local function runAt(player, floor, seed)
    local run = Descent.new(player, seed or 4242)
    for _ = 2, floor do
        Descent.clearFloor(run)
        Descent.advance(run)
    end
    return run
end

return {
    {
        name = "the floor a company fell on is the floor its stair goes back to",
        fn = function()
            local player = Player.new()
            local run = runAt(player, 9)
            assert(Descent.depth(run) == 9, "the fixture stands on floor nine, got " .. Descent.depth(run))

            -- Everything the wipe path does to the run, in the order states/game.lua does it. None of
            -- it is allowed to move where the company is standing. The pack drop that used to lead
            -- this list is gone with the pile system (models/descent.lua) -- a wipe takes nothing.
            Descent.keepFloor(run, 9, { cols = 8, rows = 8, marker = "the board they died on" })

            assert(Descent.depth(run) == 9,
                "a wipe must not move the company off floor nine, got " .. Descent.depth(run))
            assert(run.cleared == 8,
                "and the floor that killed them is not credited as beaten, got " .. tostring(run.cleared))
        end,
    },
    {
        -- THE GROUND IS THE ONE THEY WALKED, not a fresh roll of the same seed. A floor cannot be
        -- rebuilt from its seed (the stops are drawn in `pairs` order), so a return trip that re-rolled
        -- would open on ground the company had never seen -- which is the whole reason a board is kept
        -- rather than a seed. The pile this case used to look for is deleted; the board is the promise.
        name = "the board comes back exactly as it was walked",
        fn = function()
            local player = Player.new()
            local run = runAt(player, 5)
            Descent.keepFloor(run, 5, { cols = 8, rows = 8, marker = "walked" })

            local board = Descent.floorBoard(run, 5)
            assert(board and board.marker == "walked", "the floor they walked is kept")
        end,
    },
    {
        -- ...ACROSS A SAVE, because a wipe is exactly when a player quits. Board and depth have to
        -- survive together: either one coming back without the other is a return trip to the wrong
        -- place, or to the right place with the wrong ground under it.
        name = "depth and board survive the quit a wipe invites",
        fn = function()
            local player = Player.new()
            local run = runAt(player, 7)
            Descent.keepFloor(run, 7, { cols = 8, rows = 8, marker = "seven" })
            player.descentRun = run

            local back = Save.restore(Save.snapshot(player)).descentRun
            assert(back, "the run comes back at all")
            assert(Descent.depth(back) == 7, "on floor seven, got " .. Descent.depth(back))
            assert((Descent.floorBoard(back, 7) or {}).marker == "seven", "with the board they walked")
        end,
    },
    {
        -- THE OTHER ENDING. Giving up is not being beaten: it drops the run, and the next descent opens
        -- at the top. Held here beside the wipe so the two cannot be collapsed into one answer by
        -- somebody reading either in isolation.
        name = "a run given up starts the next one at the top",
        fn = function()
            local player = Player.new()
            player.descentRun = runAt(player, 6)
            assert(Descent.depth(player.descentRun) == 6, "six floors down")

            player.descentRun = nil -- what states/game.lua's clearRun leaves behind
            local fresh = Descent.new(player, 99)
            assert(Descent.depth(fresh) == 1,
                "a descent begun after giving up starts at one, got " .. Descent.depth(fresh))
        end,
    },
}
