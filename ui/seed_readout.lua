-- THE SEED, ON SCREEN, IN A DEVELOPMENT BUILD -- and in exactly one place however many surfaces show it.
--
-- What it says is models/seed.lua's business (Seed.line), including whether it says anything at all: a
-- release build gets nil back and this draws nothing. What lives here is WHERE it sits and HOW BIG it
-- is, which is the part that has to be identical everywhere it appears.
--
-- ONE POSITION, ONE SIZE, and that is the whole reason this is a module instead of four lines copied
-- into two draw functions. A reader learns where a readout lives once; a line that sits bottom-left on
-- the Gate and bottom-left-but-eight-pixels-higher on the board is a line you have to find twice. The
-- corner is chosen for being the last one free on both screens -- the board's centre bottom carries its
-- hint row, and the Gate's middle carries the stair.
--
-- Deliberately quiet: Theme.muted at the smallest body size. It is a number you go and look for when
-- something has gone wrong, not something to read past for an hour.

local Scale = require("scale")
local Theme = require("ui.theme")
local Seed = require("models.seed")

local SeedReadout = {}

-- The one layout, shared by every surface that draws this.
SeedReadout.X = 16
SeedReadout.Y = Scale.HEIGHT - 26
SeedReadout.W = 460

local font = Theme.body(12)

-- `run` is optional: the Gate before a descent and the board during one both draw this, and only the
-- second has a rift to name.
function SeedReadout.draw(player, run)
    local line = Seed.line(player, run)
    if not line then return end
    love.graphics.setFont(font)
    Theme.set(Theme.muted)
    love.graphics.printf(line, SeedReadout.X, SeedReadout.Y, SeedReadout.W, "left")
    love.graphics.setColor(1, 1, 1)
end

return SeedReadout
