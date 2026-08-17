-- THE INN's pop-up: a night for the company, priced per head.
--
-- The one place in the game that sets a bone. A body that goes down in a fight is WOUNDED for the rest
-- of its life (models/wound.lua) -- a share of its health reserved and unreachable, and debuffs stacking
-- as they accumulate -- and nothing underground undoes that. The rest stop on a floor hands back half of
-- what is left; only this hands back the body.
--
-- A THIN WRAPPER OVER ui/panels/choice.lua rather than a panel of its own, and that is the whole design:
-- what an inn actually offers is one yes-or-no with a price on it, and Choice already draws a titled
-- card with two options, handles mouse, keyboard and pad, and closes on Esc. The prices and the spend
-- live in models/gate.lua so a spec can drive them without a window; this is the two sentences the
-- player reads before pressing yes.
--
-- Same constructor contract every hub panel takes (states/hub.lua's launchPanel hands `player`, `title`
-- and `onClose` to all of them), so the building blueprint needed nothing special.

local Choice = require("ui.panels.choice")
local Gate = require("models.gate")
local Player = require("models.player")
local Wound = require("models.wound")

local Inn = {}

function Inn.new(opts)
    opts = opts or {}
    local player = opts.player or Player.active
    local price = Gate.innPrice(player)
    local hurt = #(Wound.wounded(player) or {})
    local canPay = (player and player.gold or 0) >= price

    -- Rebuilt rather than mutated after a rest: the price is per head and the wounded count changes the
    -- moment the bill is paid, so the card that says "three of them need the surgeon" has to stop saying
    -- it. Cheap -- it is a table of two options.
    local self
    local function rebuild(notice)
        self = Choice.new({
            title = opts.title or "The Inn",
            prompt = notice or (
                "A night, a fire and a surgeon: " .. price .. " gold for the company. Everything " ..
                "restored, and every bone set." ..
                (hurt > 0
                    and ("  " .. hurt .. (hurt == 1 and " of them needs" or " of them need") .. " the surgeon.")
                    or "")),
            options = {
                {
                    label = "Take the rooms  (" .. price .. "g)",
                    desc = canPay and "They come down to breakfast whole."
                        or "You cannot cover it.",
                    accent = { 0.83, 0.73, 0.45 },
                    cb = function()
                        local ok, why = Gate.rest(player)
                        if ok then Player.save() end
                        -- The card stays open on the news rather than closing on it. A panel that
                        -- vanishes the instant you spend leaves the player looking at a city and
                        -- guessing whether the gold went somewhere.
                        rebuild(ok and "They sleep, and somebody sets what is broken."
                            or (why == "gold" and "You cannot cover it."
                                or "There is nobody to take a room."))
                        if ok then
                            price, hurt, canPay = Gate.innPrice(player), 0,
                                (player.gold or 0) >= Gate.innPrice(player)
                        end
                    end,
                },
                {
                    label = "Not tonight",
                    desc = "Keep the coin.",
                    accent = { 0.50, 0.68, 0.92 },
                    cb = function() if opts.onClose then opts.onClose() end end,
                },
            },
            onClose = opts.onClose,
        })
    end
    rebuild()

    -- The live card is swapped underneath, so every callback forwards to whichever one is current.
    return setmetatable({}, {
        __index = function(_, k)
            local v = self[k]
            if type(v) ~= "function" then return v end
            return function(_, ...) return v(self, ...) end
        end,
    })
end

return Inn
