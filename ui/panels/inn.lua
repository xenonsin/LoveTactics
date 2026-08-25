-- THE INN's pop-up: a night for the company, priced per head.
--
-- The one place in the game that sets a bone. A body that goes down in a fight is WOUNDED for the rest
-- of its life (models/wound.lua) -- a share of its health reserved and unreachable, and debuffs stacking
-- as they accumulate -- and nothing underground undoes that. The rest stop on a floor hands back half of
-- what is left; only this hands back the body.
--
-- A THIN WRAPPER OVER ui/panels/choice.lua rather than a panel of its own, and that is the whole design:
-- what an inn actually offers is one yes-or-no with a price on it, and Choice already draws a titled
-- card of options, handles mouse, keyboard and pad, and closes on Esc. The prices and the spend
-- live in models/gate.lua so a spec can drive them without a window; this is the two sentences the
-- player reads before pressing yes.
--
-- THERE IS ONE ROW, not two. The card used to carry a "Not tonight" row beside the rooms, which is the
-- door out drawn twice: the X in the corner, Esc and B already leave, they leave from every panel in
-- the game, and a decline that costs nothing and changes nothing does not need a card of its own to be
-- discoverable. What is left is the only thing this counter actually sells.
--
-- THE PURSE IS ON THE CARD, in the keeper pane where every shelf in the city prints it. A bed is priced
-- per head and the price climbs, so what the player is really deciding is whether the night leaves
-- enough for the day after it -- and that is unanswerable from a panel that shows the bill and not the
-- balance. `keeper.gold` is re-read on every rebuild so the number moves the moment the bill is paid.
--
-- IT HAS A FACE NOW, and it did not before. Every other counter in the city draws its keeper down the
-- left of its panel -- the Cafe, the Touchstone, the Crossing, the seven houses -- and this was the
-- one door where somebody puts hands on the company and nobody was standing behind it. The pane is the
-- same recessed slot at the same width, added to Choice itself (`keeper`) rather than by growing this
-- room a three-column panel it has no content for. The name, the portrait and the line under it all
-- come off data/vendors/inn.lua, which is also what the first-visit greeting hangs on.
--
-- THE ROOMS GREY OUT WHEN NOBODY IS BROKEN, which is the whole reason the wounded count is read here at
-- all. Coming home already restores health and mana for free (Player.restore, on hub entry), so a night
-- buys exactly one thing: the bones. With none to set, the bill is a charge for nothing -- and pressing
-- it would take the gold and change nothing on the roster, which is the shape of a bug even when the
-- ledger is right. It is drawn and refused rather than hidden, because a counter showing the player
-- nothing but the door out says nothing about why they came. Same for a purse that cannot cover it.
--
-- Same constructor contract every hub panel takes (states/hub.lua's launchPanel hands `player`, `title`
-- and `onClose` to all of them), so the building blueprint needed nothing special.

local Choice = require("ui.panels.choice")
local Gate = require("models.gate")
local Player = require("models.player")
local Vendor = require("models.vendor") -- only for the keeper's name and line
local Wound = require("models.wound")

local Inn = {}

function Inn.new(opts)
    opts = opts or {}
    local player = opts.player or Player.active
    local def = Vendor.get(opts.vendor or "inn") or {}
    -- The keeper is named and marked, not pictured: the pane wears the house's own glyph on the name
    -- (ui/vendor_icons.lua) where it used to reserve room for a portrait nobody was going to paint.
    local keeper = {
        id = opts.vendor or "inn",
        name = def.name or "The Inn",
        line = def.description,
    }

    local price, hurt, canPay

    -- Rebuilt rather than mutated after a rest: the price is per head and the wounded count changes the
    -- moment the bill is paid, so the card that says "three of them need the surgeon" has to stop saying
    -- it -- and the rooms themselves have to go dark, since there is now nothing left to set. Cheap --
    -- it is a table of two options.
    local self
    local function rebuild(notice)
        price = Gate.innPrice(player)
        hurt = #(Wound.wounded(player) or {})
        canPay = (player and player.gold or 0) >= price
        -- Re-read rather than snapshotted at construction: the card is rebuilt the moment the bill is
        -- paid, and a purse that still said what it held before the night would be the one line on the
        -- panel lying about what just happened.
        keeper.gold = player and player.gold or 0

        local prompt = notice
        if not prompt then
            prompt = "A night, a fire and a surgeon: " .. price .. " gold for the company. Everything " ..
                "restored, and every bone set."
            if hurt > 0 then
                prompt = prompt .. "  " .. hurt ..
                    (hurt == 1 and " of them needs" or " of them need") .. " the surgeon."
            else
                -- Says what is true of the company rather than what is wrong with the button. The row
                -- below carries the refusal; this carries the reason there is nothing to buy.
                prompt = prompt .. "  Nobody is carrying a wound."
            end
        end

        -- Two refusals, one dead card. Ordered so the player is told the thing they cannot change first:
        -- an empty purse is a reason to come back, an unbroken company is a reason not to.
        local why
        if hurt == 0 then why = "Nobody needs a bed you have to pay for."
        elseif not canPay then why = "You cannot cover it." end

        self = Choice.new({
            title = opts.title or def.name or "The Inn",
            keeper = keeper,
            prompt = prompt,
            options = {
                {
                    label = "Take the rooms  (" .. price .. "g)",
                    desc = why or "They come down to breakfast rested. A bed is not a surgeon.",
                    disabled = why ~= nil,
                    accent = { 0.83, 0.73, 0.45 },
                    cb = function()
                        local ok, reason = Gate.rest(player)
                        if ok then Player.save() end
                        -- The card stays open on the news rather than closing on it. A panel that
                        -- vanishes the instant you spend leaves the player looking at a city and
                        -- guessing whether the gold went somewhere.
                        rebuild(ok and "They sleep, and somebody sets what is broken."
                            or (reason == "gold" and "You cannot cover it."
                                or "There is nobody to take a room."))
                    end,
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
