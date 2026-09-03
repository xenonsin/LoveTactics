-- ISELLE'S TALLY, drawn. One widget, three surfaces, so the player learns to read it once.
--
-- WHAT IT SHOWS is models/descent.lua's count: what the company has left forming behind it. It climbs
-- when they come back up the stair early and falls when they go deeper, and the fiction for it is the
-- first conversation in the game (data/conversations/prologue/conversation_prologue_sponsor.lua --
-- nothing down there is born, it forms, and the trade is paid by the floor to keep the number down).
--
-- MARKS RATHER THAN A BAR, and that is the one real decision in this file. The thing being shown is an
-- INTEGER that moves one step at a time; a continuous fill would claim a continuous quantity and hide
-- the step, so a player who came up once would watch a bar creep and learn nothing about what they had
-- just spent. Marks grouped in fives are countable at a glance -- two groups and one is eleven without
-- anybody counting -- and the whole budget is legible the first time it is seen, which is the other half
-- of the job (a deadline nobody knows the size of is not a deadline).
--
-- AND THE ROW IS A LADDER, green through red, coloured per mark rather than per reading. See
-- BAND_COLOR below for why the geography is fixed rather than restained on every band change.
--
-- NO NUMERAL. The fives carry the count, and a figure beside them says the same thing twice on a plate
-- that also has to hold a building's name. The one place a figure IS drawn is the Way Up card, where it
-- is a transition rather than a reading (states/game.lua) -- there the player is being told what a move
-- they have not made yet would do, and "12 of 15" alone would not say which way it moved.
--
-- NO PROSE UNTIL IT MATTERS EITHER. The bottom bands draw marks alone; the single warning appears near
-- the top, so its arrival is the signal (models/descent.lua's COUNT_BANDS).
--
-- THE CHANGE GETS A BEAT. A readout nobody notices changing is fixed by giving it a moment rather than
-- by hanging a badge on it, so the mark that just filled ARRIVES: it rises into the row from below over
-- a quarter of a second while the ones already lit sit still. The row is horizontal and the arrival is
-- vertical on purpose -- something entering along the row's own axis reads as a fill rather than as an
-- addition. Paying it back plays the same beat downward. It runs once, on the first draw after the
-- number moved, and never loops.
--
-- IT TAKES NO INPUT AND HOLDS NO FOCUS. The Rift card underneath it is already selectable by mouse, key
-- and pad (ui/building_map.lua); the tally rides the plate rather than competing with it.
--
--   local meter = CountMeter.new()
--   ... meter:update(dt)
--   ... meter:draw(x, y, w, player)   -- centred in the given width; CountMeter.HEIGHT tall
--
-- IT TAKES THE PLAYER, NOT THE RUN. It used to take the run, which was the same reading while a descent
-- outlived every climb-out; the tally is the company's now (models/descent.lua's Descent.count), and the
-- plaza has to be able to draw it standing in a city with no expedition open.

local Colors = require("ui.colors")
local Descent = require("models.descent")
local Theme = require("ui.theme")

local CountMeter = {}
CountMeter.__index = CountMeter

-- One mark, and the two gaps. GROUP is the run of marks between the wider gaps -- five, because that is
-- the group size a reader counts in without being taught to.
local MARK_W, MARK_H = 6, 9
local GAP, GROUP_GAP, GROUP = 3, 12, 5

-- How far the arriving mark travels, and how long it takes. A quarter second is long enough to be seen
-- on a screen the player just walked onto and short enough that it is over before they reach for
-- anything.
local RISE, DUR = 8, 0.25

-- The phrase sits above the row. Whole widget height, so a caller can lay out around it.
local PHRASE_H = 20
CountMeter.HEIGHT = PHRASE_H + MARK_H

-- HOW FAR THE LAMPS HAVE GONE OUT, per band: the alpha of a flat darkening laid over the painted city
-- before the cards are drawn (states/hub.lua).
--
-- The bands are meant to be read off the CITY rather than off the number -- three of the four do nothing
-- mechanical, and what they are for is a player noticing the place is worse than it was without being
-- told. A darken is the cheapest true version of that and the one that cannot go stale: it needs no art
-- and no per-building state. Boarded windows and a thinner queue at the Crossing are the same idea
-- done properly, and they are art rather than code.
--
-- Nothing in the lowest band, which is the point of the lowest band.
CountMeter.CITY_DIM = { low = 0, climbing = 0.12, unpruned = 0.28, up = 0.40 }

-- THE ROW CLIMBS GREEN, YELLOW, ORANGE, RED, and it does so per MARK rather than per reading: mark i
-- wears the colour of the band a count of i falls into (Descent.bandAt), so the meter has a fixed
-- geography a player can learn. You can see the orange marks waiting three groups along before you have
-- lit any of them, which is what makes filling toward them mean something -- a meter that simply
-- restained its whole row on every band change would say "it is bad now" and never "it is about to be".
--
-- The colour boundaries ARE the band boundaries, so this ladder and the warning text and the city's
-- darkening all change on the same four counts rather than on three different schedules.
--
-- NO NEW HUES. Three of the four come straight out of ui/colors.lua's enamel families -- verdigris for
-- safe, bronze for the first warning, ember for the last -- and the middle step is the chrome's own
-- weapon accent, which sits exactly between bronze and ember. A threat readout inventing a sixth family
-- is the drift that file exists to stop.
--
-- Green is the game's ALLY/heal colour, and it is unambiguous here for a reason worth stating: this
-- meter never draws on the board, so it can never be mistaken for a friendly marker among units. On a
-- city card, green reads as the universal "nothing to do here", which is what a low tally is.
CountMeter.BAND_COLOR = {
    low      = Colors.SUPPORT,      -- verdigris
    climbing = Colors.STAMINA,      -- bronze
    unpruned = Theme.accentWeapon,  -- the chrome's warm orange
    up       = Colors.ENEMY,        -- ember
}

-- The darkening this company has earned, or nil when there is nothing to draw.
function CountMeter.cityDim(player)
    if not player then return nil end
    local a = CountMeter.CITY_DIM[Descent.countBand(player).id] or 0
    return a > 0 and a or nil
end

function CountMeter.new()
    local self = setmetatable({}, CountMeter)
    self.phraseFont = Theme.body(13)
    -- Nil rather than zero: the FIRST draw of a meter has nothing to animate from, so a fresh widget
    -- opening on a count of eleven shows eleven rather than playing eleven arrivals.
    self.shown = nil
    self.anim = nil
    return self
end

-- The width the row of marks occupies for a given maximum. Derived rather than a constant so moving
-- Descent.COUNT_MAX cannot leave a row that overflows its card in silence.
function CountMeter.rowWidth(max)
    max = max or Descent.COUNT_MAX
    local groups = math.ceil(max / GROUP)
    return max * MARK_W + (max - groups) * GAP + (groups - 1) * GROUP_GAP
end

-- Where mark `i` (1-based) starts, relative to the row's left edge.
local function markX(i)
    local before = i - 1
    local groupsBefore = math.floor(before / GROUP)
    return before * MARK_W + (before - groupsBefore) * GAP + groupsBefore * GROUP_GAP
end

function CountMeter:update(dt)
    if not self.anim then return end
    self.anim.t = self.anim.t + (dt or 0) / DUR
    if self.anim.t >= 1 then self.anim = nil end
end

-- Take the count now, starting a beat if it moved since the last draw. Split out from `draw` so a
-- caller that wants the beat to begin on entry rather than on the first frame drawn can say so.
function CountMeter:sync(player)
    local n = Descent.count(player)
    if self.shown and n ~= self.shown then
        self.anim = { from = self.shown, to = n, t = 0 }
    end
    self.shown = n
    return n
end

-- Draw centred in `w` at `x`, phrase first. `player` is the company whose tally this is; nothing is
-- drawn without one. The CALLER decides whether the meter belongs on screen at all
-- (Descent.everClimbedOut gates it), which is unchanged -- this only stops it drawing with no company.
function CountMeter:draw(x, y, w, player)
    if not player then return end
    local n = self:sync(player)
    local max = Descent.COUNT_MAX
    local band = Descent.countBand(player)

    -- MOST BANDS CARRY NO WORDS AT ALL (models/descent.lua's COUNT_BANDS). The marks are the readout;
    -- the warning is the only text this ever draws, and it appears near the top, where its ARRIVAL is
    -- the signal. It wears its own band's colour, so the words escalate with the row rather than sitting
    -- at one fixed alarm shade above marks that are still climbing toward it.
    if band.phrase then
        love.graphics.setFont(self.phraseFont)
        Theme.set(CountMeter.BAND_COLOR[band.id] or Theme.accentWeapon)
        love.graphics.printf(Theme.ellipsize(band.phrase, self.phraseFont, w), x, y, w, "center")
    end

    local rowW = CountMeter.rowWidth(max)
    local rowX = x + math.floor((w - rowW) / 2)
    -- The row sits at the same y whether or not the warning is above it. A meter that slid up when its
    -- text went away would be a readout that changes place, and the player would be re-finding it every
    -- time the number crossed a band instead of reading it.
    local rowY = y + PHRASE_H

    -- Which marks are mid-beat, and which way. Everything at or below `settled` is simply lit; the
    -- window between the two counts is the arrival (or the departure, on the way back down).
    local settled, moving = n, 0
    if self.anim then
        settled = math.min(self.anim.from, self.anim.to)
        moving = math.max(self.anim.from, self.anim.to)
    end

    for i = 1, max do
        local mx = rowX + markX(i)
        -- The mark's OWN band, not the run's: the ladder is a property of the position, so the row
        -- reads green through red whatever the tally happens to be standing at.
        local lit = CountMeter.BAND_COLOR[Descent.bandAt(i).id] or Theme.accentWeapon
        if i <= settled then
            Theme.set(lit)
            love.graphics.rectangle("fill", mx, rowY, MARK_W, MARK_H)
        elseif self.anim and i <= moving then
            local t = math.min(1, self.anim.t)
            local rising = self.anim.to > self.anim.from
            local a = rising and t or (1 - t)
            local dy = rising and (1 - t) * RISE or t * RISE
            Theme.set(lit, a)
            love.graphics.rectangle("fill", mx, rowY + dy, MARK_W, MARK_H)
        else
            -- Unlit stays the card's own border, receded. Ghosting each mark in its future colour was
            -- tried in the head and refused: an empty meter would then be a full rainbow, and the one
            -- thing this readout has to say at a glance is how far along it is.
            Theme.set(Theme.frame, 0.35)
            love.graphics.rectangle("fill", mx, rowY, MARK_W, MARK_H)
        end
    end

    love.graphics.setColor(1, 1, 1)
end

return CountMeter
