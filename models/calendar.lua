-- THE CALENDAR: the day, and what a day is worth.
--
-- IT USED TO BE A DEADLINE, and that is the thing to know before reading anything below. The demon lord
-- landed on day forty; there were more quests than there were days, so the campaign stopped being
-- "finish everything" and became "choose what to finish", and every rule the game had about commitment
-- -- the solo-line rule most of all -- bit because of it.
--
-- THE BOARD IT MEASURED IS GONE. Forty days were forty expeditions bought off a Quest Board, and the
-- board was retired: the descent is the campaign now (models/descent.lua). A run is not an expedition,
-- it is fifteen floors and every trip up and down between them, so a clock that counted expeditions had
-- nothing left to count -- and a countdown over a loop that does not spend it is pressure with no
-- decision underneath, which is the one thing a deadline may never be.
--
-- WHAT PRESSES INSTEAD IS THE COUNT (models/descent.lua, docs/the-count.md): what forms on the floors
-- the company is not standing on. It is deliberately not a schedule -- it moves both ways, it is paid
-- down by going deeper, and a company that presses on never watches it climb. What it prices is the one
-- decision in the loop that has an alternative, which is coming back up early. And at its ceiling the
-- stair stops being an exit: what is down there comes up it, with every general still unsealed beside
-- it, and THAT is the ending the fortieth day used to be -- reached by what the player did rather than
-- by a date (states/game.lua's ascent branch, and Calendar.generalsStanding below, which was written to
-- size exactly that fight).
--
-- SO WHAT IS LEFT HERE IS THE DAY ITSELF, which never was the deadline and is worth keeping without one:
--
--     the night     a day passes when a company walks into the stair (models/gate.lua's Gate.night).
--                   It used to mend as well -- a wounded body took a bed and was out of the company for
--                   a day a bone -- and that toll is deleted along with the Inn (models/wound.lua): a
--                   wound is a condition of the expedition now and the surface ends it for free. So the
--                   day is a day, and it is the axis below rather than a currency.
--     the axis      `day` is the number an encounter blueprint's `minDay` is authored against and the
--                   number Calendar.dangerLevel reads. A descent keeps its own clock and passes it
--                   outright (Descent.dangerLevel); what it borrows from here is the SCALE, mapping its
--                   fifteen floors onto Calendar.SPAN so the two ladders speak one unit.
--     standing      ...is not here and never was. How far into the story you are is quests finished
--                   (Player.questsCompleted), which is a thing you do rather than a thing done to you.
--
-- WHAT WAS DELETED, named so nobody goes looking: `remaining`, `isFinalDay` and `isOver`. There is no
-- last day, so there is nothing to be past. Anything that used to refuse on a spent calendar -- the
-- Inn's counter most of all -- refuses on its own terms now or does not refuse at all.
--
-- Pure model -- no love.graphics -- so it loads under the headless runner.

local Calendar = {}

-- THE LENGTH OF THE DAY AXIS, AND IT IS A SCALE RATHER THAN A BUDGET. Nothing runs out at forty and
-- Calendar.day is not capped by it: a company that spends a hundred nights at the Inn is on day a
-- hundred and one, and the world is no worse for it (dangerLevel holds at its endpoint).
--
-- It is forty because that is the axis every `minDay` in data/encounters was authored against, and
-- because the descent maps its depth onto it (states/game.lua) so a floor and a day can be compared at
-- all. Moving it re-reads both, plus the ramp below.
--
-- IT WAS `Calendar.DAYS`, which was an honest name for a budget and a lie about a scale.
Calendar.SPAN = 40

-- The level the WORLD fights at at the top of the axis. Anchored on what a company can actually reach
-- in forty days of fighting (models/experience.lua): a body earns something over forty experience a
-- day, which on the campaign curve arrives in the mid twenties, and the world is set a shade under
-- that.
--
-- THIS IS THE HEADLINE NUMBER, NOT WHAT ORDINARY STOCK FIGHTS AT. Growth.combatantLevel still applies
-- ENEMY_LEVEL_LAG (0.9) underneath, so a common body at the top of the axis spawns around 19 rather
-- than 22 -- measured, not assumed. The lag has lost its original meaning (it held enemies just behind
-- a party whose level was a global given, and no such number exists now) but it has kept a useful one:
-- it is the gap between the road's ordinary traffic and what the axis says the world is capable of,
-- which is what leaves room for an elite or a floorLevel to reach the headline and mean something by it.
Calendar.FINAL_DANGER = 22

-- The world's level on `day`. Linear from 1 at the bottom of the axis to FINAL_DANGER at the top.
--
-- Clamped at both ends: day 0 (a fresh save, before anything) reads as day 1 rather than as level 0,
-- and past the top of the axis it HOLDS rather than climbing -- which is what makes a night at the Inn
-- free of consequence now that nights are unbounded. A company that rests a great deal is not a company
-- the world hardens against; that was the deadline's job and the deadline is gone.
--
-- The descent does not read this at all: it carries its own dial and passes it as `enemyLevel` at every
-- fight (Descent.dangerLevel). This is the fallback for everything standing outside a run.
function Calendar.dangerLevel(day)
    local d = math.max(1, math.min(Calendar.SPAN, day or 1))
    if Calendar.SPAN <= 1 then return Calendar.FINAL_DANGER end
    local t = (d - 1) / (Calendar.SPAN - 1)
    return math.max(1, math.floor(1 + t * (Calendar.FINAL_DANGER - 1) + 0.5))
end

-- The day the player is standing on. One-based: a fresh save is on day 1.
function Calendar.day(player)
    return math.max(1, (player and player.day) or 1)
end

-- A night passes. THE ONE SEAM, and it has exactly one caller -- models/gate.lua's Gate.night, which is
-- what a night IS. That used to be three things (a day, a bone off everybody abed, and whoever that
-- finished walking out of a room) and is one now that the Inn is gone; the indirection stays because
-- "a night passes" is a fact about the loop and this file only knows about days.
--
-- Deliberately not idempotent and deliberately unguarded: a caller that spends twice for one night is a
-- bug that should show up as a day appearing, not be silently absorbed here. It used to refuse a day
-- past the deadline; there is no deadline, so it refuses nothing.
function Calendar.spend(player)
    if not player then return 1 end
    player.day = Calendar.day(player) + 1
    return player.day
end

-- How the last fight is composed: one general fewer beside him for each of the seven felled.
--
-- THIS IS WHAT REPLACED THE GATE'S SEVEN-OF-SEVEN LOCK. That gate could not survive a campaign that
-- ends before the seventh circle, so the count moved from being PERMISSION to being CONSEQUENCE: every
-- general you did not face is one who faces you at the end, all at once.
--
-- AND IT IS FINALLY READ. It has been threaded onto every composition ctx since the finale quest was
-- written and nothing has ever called it -- the day-forty finale it sized was retired with the board.
-- The breach is what it sizes now: at the count's ceiling the stair stops being an exit, and what comes
-- up it brings everyone still standing (models/descent.lua's Descent.breachComposition).
--
-- Returns the number still standing (0..7). A GENERAL IS DOWN BY ONE ROUTE, and it is the descent's:
-- her circle is sealed by felling her on her own floor, credited to `run.standing` keyed by the house's
-- VENDOR (Descent.clearFloor). The circles are the authority because that is the shorter statement of
-- the same fact -- there are seven of them because there are seven sins, and Descent.SINS says it once.
function Calendar.generalsStanding(player)
    local Descent = require("models.descent")
    local sealed = (player and player.descentRun and player.descentRun.standing) or {}
    local standing = 0
    for _, sin in ipairs(Descent.SINS) do
        if (sealed[sin.vendor] or 0) <= 0 then standing = standing + 1 end
    end
    return standing
end

return Calendar
