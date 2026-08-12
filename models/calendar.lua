-- THE CALENDAR: how long there is, and what spends it.
--
-- The campaign used to be a checklist. Ninety-two quests, all of them reachable, all of them walked by
-- both play policies (`. progression-report`), and nothing anywhere that made running one quest instead
-- of another cost anything. Every rule the game had about commitment -- the solo-line rule most of all,
-- which docs/progression.md settled as "a player may take one sin's line to its end without touching
-- the other six" -- was true and free, and a rule that is free is a rule nobody feels.
--
-- A deadline is what makes those rules bite. The demon lord returns on a fixed day. There are more
-- quests than there are days, so the campaign stops being "finish everything" and becomes "choose what
-- to finish", which is the decision the seven houses were built to offer and never got to ask.
--
-- THE UNIT IS AN EXPEDITION, AND ENTERING SPENDS IT. Not clearing the objective -- entering. Take the
-- boss, break off with a Smoke Bolt, or get wiped: the day is gone all three ways. That is the whole
-- greed dial. "Push on or go home with what I have" only means something if going home costs the same
-- day that pushing on would have, and it is why the hub is free (below).
--
-- THERE IS NO FAIL STATE. The last day is not a loss screen; it is the last battle, fought with
-- whatever company and whatever allies the player managed to assemble. You always get an ending. The
-- generals you felled are simply not standing beside him -- see Calendar.finaleStrength.
--
-- WHAT THE DAY IS *NOT*. It is not a second currency. Shopping, forging, the Loadout, mending a wound
-- and eating at the Cafe all cost nothing, deliberately: a hub that spent days would turn every visit
-- to a shelf into arithmetic, and the interesting decision is which expedition to take, not whether to
-- walk to a building.
--
-- WHAT REPLACED PRESTIGE. `player.prestige` is gone, and its two tangled jobs went to two different
-- numbers, because they were never the same question:
--
--     the difficulty dial   -> THE DAY (Calendar.day). Enemy level, encounter gating, head-count,
--                              loot band, the muster rating. The world hardens on the calendar rather
--                              than on the company, so a wasted week is a week the world pulled ahead.
--                              This is the load-bearing half of the deadline: scaling danger to the
--                              party instead would refund every day the player squandered.
--     campaign standing     -> QUESTS COMPLETED (Player.questsCompleted). Building unlocks, quest
--                              gates, conversation predicates. Those ask "how far into the story are
--                              you", which is a thing you do rather than a thing that happens to you.
--
-- Pure model -- no love.graphics -- so it loads under the headless runner.

local Calendar = {}

-- How many expeditions there are before he lands. Forty is derived rather than picked: a house's line
-- reaches its slot 10 in ten to thirteen quests including its zero-to-three on-ramp
-- (`. progression-report`), so forty days at roughly three quarters on story work is a little under
-- three lines -- which is the shape the solo-line rule describes, with room to forage.
--
-- It is the single number the whole difficulty curve is anchored on (Calendar.dangerLevel below and
-- models/experience.lua's STEP), so moving it means re-reading both.
Calendar.DAYS = 40

-- The level the WORLD fights at on the last day. Anchored on what the company can actually reach in
-- forty days of fighting (models/experience.lua): a body earns something over forty experience a day,
-- which on the campaign curve arrives at the deadline somewhere in the mid twenties. The world is set a
-- shade under that, so a player who spends their days fighting walks into the finale with an edge they
-- earned, and one who squandered them does not.
--
-- THIS IS THE HEADLINE NUMBER, NOT WHAT ORDINARY STOCK FIGHTS AT. Growth.combatantLevel still applies
-- ENEMY_LEVEL_LAG (0.9) underneath, so a common body on the last day spawns around 19 rather than 22 --
-- measured, not assumed. The lag has lost its original meaning (it held enemies just behind a party
-- whose level was a global given, and no such number exists now) but it has kept a useful one: it is
-- the gap between the road's ordinary traffic and what the calendar says the world is capable of, which
-- is what leaves room for an elite or a floorLevel to reach the headline and mean something by it.
Calendar.FINAL_DANGER = 22

-- The world's level on `day`. Linear from 1 on the first morning to FINAL_DANGER on the last, so the
-- ramp is legible -- a player can look at the calendar and know roughly what is out there.
--
-- Clamped at both ends: day 0 (a fresh save, before the first expedition) reads as day 1 rather than as
-- level 0, and nothing past the deadline climbs, because there is nothing past the deadline.
function Calendar.dangerLevel(day)
    local d = math.max(1, math.min(Calendar.DAYS, day or 1))
    if Calendar.DAYS <= 1 then return Calendar.FINAL_DANGER end
    local t = (d - 1) / (Calendar.DAYS - 1)
    return math.max(1, math.floor(1 + t * (Calendar.FINAL_DANGER - 1) + 0.5))
end

-- The day the player is standing on. One-based: a fresh save is on day 1 with every day still to spend.
function Calendar.day(player)
    return math.max(1, (player and player.day) or 1)
end

-- Expeditions left INCLUDING the one about to be taken. Zero once the deadline has passed.
function Calendar.remaining(player)
    return math.max(0, Calendar.DAYS - Calendar.day(player) + 1)
end

-- Is this the last day? The finale is fought on it, so the quest board says so and the hub stops
-- offering an ordinary expedition.
function Calendar.isFinalDay(player)
    return Calendar.day(player) >= Calendar.DAYS
end

-- Has the deadline passed -- i.e. has the finale been fought? Distinct from isFinalDay: on the last day
-- there is still one expedition to take.
function Calendar.isOver(player)
    return Calendar.day(player) > Calendar.DAYS
end

-- Spend a day. THE ONE SEAM, called when an expedition is ENTERED rather than when it resolves, so a
-- run walked out of costs exactly what a run completed does. Returns the new day.
--
-- Deliberately not idempotent and deliberately not guarded against overrun: a caller that spends twice
-- for one expedition is a bug that should show up as a day disappearing, not be silently absorbed here.
-- The one thing it will not do is spend a day that does not exist.
function Calendar.spend(player)
    if not player then return 1 end
    if Calendar.isOver(player) then return Calendar.day(player) end
    player.day = Calendar.day(player) + 1
    return player.day
end

-- How the last battle is composed: one general fewer beside him for each of the seven felled.
--
-- THIS IS WHAT REPLACED THE GATE'S SEVEN-OF-SEVEN LOCK. That gate could not survive a deadline -- seven
-- lines to their slot 10 is about seventy expeditions on its own, so the ending would have been
-- unreachable by construction. Deleting the lock without replacing it would have made the seven lines
-- decorative in the other direction, so the count moved from being PERMISSION to being CONSEQUENCE:
-- every general you did not face is one who faces you at the end, all at once.
--
-- Returns the number still standing (0..7). The finale's own blueprint decides what to do with it.
function Calendar.generalsStanding(player)
    local Quest = require("models.quest")
    local standing = 0
    for _, id in ipairs(Quest.GENERAL_QUESTS or {}) do
        if not (player and (player.completedQuests or {})[id]) then standing = standing + 1 end
    end
    return standing
end

return Calendar
