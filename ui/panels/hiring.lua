-- THE HIRING HALL's pop-up: the people you turned down underground, of whom one may be taken on.
--
-- NOT A SHELF OF STRANGERS. The hall deals nothing of its own -- its stock is Recruit.hallSlate, the
-- bodies this player met on a floor and walked past, and it is empty until there is one. That is what
-- makes refusing somebody a decision you meet again rather than a free one, and it is why a hire is
-- never a body the player has not already stood in front of and read.
--
-- SO THE ROOM CAN BE EMPTY, and on a fresh save it is. Nothing is blocked by that: the company that
-- walks to the gate is the prologue's, and the floors are where a company grows.
--
-- A THIN WRAPPER OVER ui/panels/choice.lua, like ui/panels/inn.lua and for the same reason: what this
-- offers is a few cards and a way out, which Choice already draws with mouse, keyboard and pad support.
--
-- NOTHING IS ROLLED HERE, so nothing can reshuffle: the room shows the three most recent refusals, in
-- the order they happened. Walking out and back in shows the same three, and the only thing that changes
-- them is what you do on a floor.

local Choice = require("ui.panels.choice")
local Descent = require("models.descent")
local Player = require("models.player")
local Recruit = require("models.descent_recruit")

local Hiring = {}

function Hiring.new(opts)
    opts = opts or {}
    local player = opts.player or Player.active

    local self
    local function rebuild(notice)
        local full = not Descent.hasRoom(player)
        local waiting = #Recruit.hallSlate(player)
        local options = {}

        if not full then
            -- THE PEOPLE YOU TURNED DOWN, and nobody else (Recruit.hallSlate). The hall is a consequence
            -- rather than a shop: the survivor you had no room for on floor three is still in town when
            -- you come back up, and walking past somebody is a decision you meet again. A hall nobody
            -- has walked past is EMPTY, and says so.
            -- Three at most: Choice draws 2-4 cards and "Leave" is one of them. A player who has
            -- refused a dozen people sees the three most recent, which is also the right order --
            -- the ones you walked past this run are the ones you are still thinking about.
            local slate = Recruit.hallSlate(player)
            for i = math.max(1, #slate - 2), #slate do
                local id = slate[i]
                options[#options + 1] = {
                    label = Recruit.nameOf(id) or id,
                    desc = Recruit.describe(id),
                    accent = { 0.62, 0.86, 0.45 },
                    cb = function()
                        Recruit.join(player, id)
                        Player.save()
                        rebuild((Recruit.nameOf(id) or id) .. " takes the work.")
                    end,
                }
            end
        end

        options[#options + 1] = {
            label = "Leave",
            desc = "Back to the street.",
            accent = { 0.50, 0.68, 0.92 },
            cb = function() if opts.onClose then opts.onClose() end end,
        }

        self = Choice.new({
            title = opts.title or "Hiring Hall",
            -- A ROW HERE IS TWO LINES: what a body can take and deal, then what it fights with
            -- (Recruit.describe), and neither half is decoration -- they are the two facts a company
            -- short of somebody actually weighs. Choice's default card holds one, and the second lands
            -- with its descenders across the bottom border, so the room is asked for rather than the
            -- sentence cut.
            optionHeight = 84,
            -- THREE THINGS THIS ROOM CAN BE, and the empty one is the one worth wording carefully: a
            -- player who has never turned anybody down needs to be told the hall is stocked from BELOW,
            -- or an empty room reads as a building that does not work yet.
            prompt = notice or (full
                and ("The company is full at " .. Descent.PARTY_MAX ..
                     ". Nobody else is going down with them.")
                or (waiting == 0
                    and "Nobody is waiting. The people who come up and stay up are the ones you " ..
                        "walked past down there, and you have not walked past anybody."
                    or "There is room in the company, and these came up ahead of you.")),
            options = options,
            onClose = opts.onClose,
        })
    end
    rebuild()

    -- The live card is swapped underneath on every hire, so each callback forwards to the current one.
    return setmetatable({}, {
        __index = function(_, k)
            local v = self[k]
            if type(v) ~= "function" then return v end
            return function(_, ...) return v(self, ...) end
        end,
    })
end

return Hiring
