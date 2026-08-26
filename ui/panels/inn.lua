-- THE INN's pop-up: a night for the company, priced per head, and a bed for each body that is broken.
--
-- The one place in the game that sets a bone. A body that goes down in a fight is WOUNDED for the rest
-- of its life (models/wound.lua) -- a share of its health reserved and unreachable, and debuffs stacking
-- as they accumulate -- and nothing underground undoes that. The rest stop on a floor hands back half of
-- what is left; only this hands back the body.
--
-- A THIN WRAPPER OVER ui/panels/choice.lua rather than a panel of its own, and that is the whole design:
-- what an inn offers is a short list of priced yes-or-nos, and Choice already draws a titled card of
-- options, handles mouse, keyboard and pad, and closes on Esc. The prices and the spends live in
-- models/gate.lua so a spec can drive them without a window; this is the sentences the player reads
-- before pressing yes.
--
-- THE BEDS MOVED HERE OFF THE GATE. Lodging a body used to be a fifth plate on the departure row
-- (ui/expedition_picker.lua), dropped onto rather than bought -- so the screen whose one question is
-- "who goes down" quietly answered "and who stays in a bed" with the same gesture, and the only counter
-- in the city that puts hands on the company sold half of what it does. A night and a bed are the two
-- things this house has; they are on one card now, priced against each other.
--
-- THERE IS NO DECLINE ROW. The card used to carry a "Not tonight" row beside the rooms, which is the
-- door out drawn twice: the X in the corner, Esc and B already leave, they leave from every panel in
-- the game, and a decline that costs nothing and changes nothing does not need a card of its own to be
-- discoverable. Every row here is something this counter actually sells.
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
-- THE NIGHT ACTUALLY PASSES, and that is what this counter is FOR. Buying it spends a day off the
-- calendar and takes one wound off everybody in a bed (models/gate.lua's Gate.night, the same beat going
-- down the stair runs). Before that the only way to move the clock was to walk into a descent -- so a
-- company that came up beaten had to go back down, hurt, to buy the days that would have healed them,
-- and the cure sat on the far side of the fight it was for.
--
-- THE ROOMS GREY OUT WHEN NOBODY IS BROKEN, which is the whole reason the wounded count is read here at
-- all. Coming home already restores health and mana for free (Player.restore, on hub entry), so a night
-- bought by a whole company is a bill for nothing. It is drawn and refused rather than hidden, because a
-- counter showing the player nothing but the door out says nothing about why they came. Same for a purse
-- that cannot cover it.
--
-- Same constructor contract every hub panel takes (states/hub.lua's launchPanel hands `player`, `title`
-- and `onClose` to all of them), so the building blueprint needed nothing special.

local Choice = require("ui.panels.choice")
local Gate = require("models.gate")
local Player = require("models.player")
local Vendor = require("models.vendor") -- only for the keeper's name and line
local Wound = require("models.wound")

local Inn = {}

-- HOW MANY BEDS THE CARD SHOWS AT ONCE. Four, which is the expedition (Descent.PARTY_MAX) and therefore
-- the most bodies that can come up hurt from one descent -- and it is also what the box holds under the
-- rooms before it runs off a 720-tall screen.
--
-- THE CAP SWEEPS ITSELF rather than hiding anybody for good: a body put to bed drops off this list, so
-- the next one waiting takes the row. A company deeper than four wounded is told how many are still
-- queued on the prompt, because a list that quietly stopped at four would read as "these are all of
-- them".
local MAX_BEDS = 4

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

    -- Rebuilt rather than mutated after a spend: the price is per head and the wounded count changes the
    -- moment a bill is paid, so the card that says "three of them need the surgeon" has to stop saying
    -- it -- and a body who has just taken a bed has to lose their row, or the counter would sell them a
    -- second one. Cheap -- it is a short table of options.
    local self
    local function rebuild(notice)
        price = Gate.innPrice(player)
        local wounded = Wound.wounded(player) or {}
        hurt = #wounded
        canPay = (player and player.gold or 0) >= price

        -- WHO A BED IS FOR: carrying a wound, and not already in one. Somebody lodged is not offered a
        -- second bed -- they are inside the thing being sold -- and they are counted on the prompt
        -- instead, so a player who paid yesterday can see what they are waiting on.
        local beds = {}
        for _, entry in ipairs(wounded) do
            if not Gate.isLodged(player, entry.char.id) then beds[#beds + 1] = entry end
        end
        local abed = #Gate.lodged(player)
        -- Re-read rather than snapshotted at construction: the card is rebuilt the moment the bill is
        -- paid, and a purse that still said what it held before the night would be the one line on the
        -- panel lying about what just happened.
        keeper.gold = player and player.gold or 0

        local prompt = notice
        if not prompt then
            -- KEPT SHORTER THAN THE LINE IT REPLACED, deliberately. Choice grows its card to fit the
            -- prompt and does not clamp, and MAX_BEDS is set to what the box holds at 720 tall -- so a
            -- sentence added here comes out of the bottom bed, silently, on the one screen size the
            -- game is authored in.
            prompt = "A night is " .. price .. " gold and a DAY: everything restored, and one wound " ..
                "off everybody in a bed. A bed is " .. Gate.LODGE_PER_WOUND ..
                " gold a wound, and they are out of the company until they are up."
            if hurt > 0 then
                prompt = prompt .. "  " .. hurt ..
                    (hurt == 1 and " of them needs" or " of them need") .. " the surgeon."
                if abed > 0 then
                    prompt = prompt .. "  " .. abed .. (abed == 1 and " is" or " are") .. " already abed."
                end
                if #beds > MAX_BEDS then
                    prompt = prompt .. "  " .. (#beds - MAX_BEDS) .. " more are waiting on a room."
                end
            else
                -- Says what is true of the company rather than what is wrong with the button. The row
                -- below carries the refusal; this carries the reason there is nothing to buy.
                prompt = prompt .. "  Nobody is carrying a wound."
            end
            -- NO BALANCE PRINTED HERE ANY MORE. It said how many days remained, because the day was a
            -- budget of forty and this counter spent one of them. There is no ceiling now
            -- (models/calendar.lua) -- what a night costs is the coin in the label and the body who is
            -- not in the company while they lie in the bed, and both of those are already on this card.
        end

        -- Two refusals, one dead card. Ordered so the player is told the thing they cannot buy their way
        -- out of first: an unbroken company is a reason not to, an empty purse a reason to come back.
        --
        -- THERE WERE THREE. The first was a spent calendar -- forty days, and past the last one there was
        -- no night to sell. The deadline is gone (models/calendar.lua) and with it the only refusal on
        -- this card that was about the world rather than about the company.
        --
        -- AN UNBROKEN COMPANY IS THE HARD ONE. Coming home already restores health and mana for free
        -- (Player.restore on hub entry), so a night sold to a whole company is a bill for nothing.
        -- Nobody in a bed is nobody the night can mend, and `hurt` counts the lodged too -- they are
        -- still carrying what they came up with -- so this stays live for as long as there is somebody
        -- to mend.
        local why
        if hurt == 0 then why = "Nobody is hurt. A night mends nothing that is not broken."
        elseif not canPay then why = "You cannot cover it." end

        local options = {
            {
                label = "Sleep the night  (" .. price .. "g)",
                desc = why or ("A day passes. " ..
                    (abed > 0 and (abed == 1 and "One bone is set by morning."
                                   or (abed .. " bones are set by morning."))
                              or "Nobody is abed, so no bone is set.")),
                disabled = why ~= nil,
                accent = { 0.83, 0.73, 0.45 },
                cb = function()
                    -- Gate.rest's second return is the ids it MENDED on success and the refusal reason
                    -- on failure, so it is read on the branch that knows which it is.
                    local ok, result = Gate.rest(player)
                    if ok then Player.save() end
                    -- The card stays open on the news rather than closing on it. A panel that
                    -- vanishes the instant you spend leaves the player looking at a city and
                    -- guessing whether the gold went somewhere.
                    --
                    -- ...AND IT SAYS WHOSE NIGHT IT WAS. Gate.rest hands back the ids it mended, which
                    -- is the only part of a night the player cannot see by looking at the card: the
                    -- purse moved, the rows redrew, and a bone quietly coming off a ledger would be the
                    -- one thing they paid a day for going unreported.
                    local said
                    if ok then
                        local n = #(result or {})
                        said = "They sleep, and the day is gone. " ..
                            (n > 0 and (n == 1 and "One bone is set." or (n .. " bones are set."))
                                   or "No bone was set: a night only mends what is in a bed.")
                    else
                        said = result == "gold" and "You cannot cover it."
                            or "There is nobody to take a room."
                    end
                    rebuild(said)
                end,
            },
        }

        -- A BED PER BROKEN BODY, under the rooms. This used to be a fifth plate on the Gate's departure
        -- row (ui/expedition_picker.lua), where it made the one screen that asks "who goes down" answer
        -- a second question in the same gesture. It belongs at the counter that already sells the night:
        -- a night and a bed are the two things this house has, and here they are priced side by side.
        --
        -- ONE ROW PER BODY, NAMED, because which body is the whole decision -- a bed costs days, and the
        -- days are only expensive on somebody you were going to send down. The rows all wear one colour:
        -- they are one kind of thing, and Choice's rotating accents would make four beds look like four
        -- different offers.
        for i = 1, math.min(#beds, MAX_BEDS) do
            local char, wounds = beds[i].char, beds[i].count
            local bill = Gate.lodgePrice(player, char.id)
            local short = (player and player.gold or 0) < bill
            local days = wounds .. (wounds == 1 and " day" or " days")
            options[#options + 1] = {
                label = "A bed for " .. (char.name or char.id) .. "  (" .. bill .. "g)",
                desc = short and "You cannot cover it."
                    or (wounds .. (wounds == 1 and " wound: " or " wounds: ") .. days ..
                        " abed, and out of the company until they are up."),
                disabled = short,
                accent = { 0.50, 0.68, 0.92 },
                cb = function()
                    local ok, reason = Gate.lodge(player, char.id)
                    if ok then Player.save() end
                    rebuild(ok and ((char.name or char.id) .. " takes a room: " .. days ..
                        " abed. A day passes each time you sleep the night here or go back down.")
                        or (reason == "gold" and "You cannot cover it."
                            or reason == "already" and "They are already in a bed."
                            or "There is nothing to set."))
                end,
            }
        end

        self = Choice.new({
            title = opts.title or def.name or "The Inn",
            keeper = keeper,
            prompt = prompt,
            options = options,
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
