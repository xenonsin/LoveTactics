-- BIOME WINDOWS: where the company may go today.
--
-- The calendar answers "how many days are there" (models/calendar.lua). This answers "and which
-- ground is reachable on this one". The table is authored in data/biome_windows.lua and never rolled
-- -- see the note there for why a learnable schedule is the point rather than a limitation.
--
-- WHY A QUEST NAMES A *SET* OF BIOMES. A house's line is a strict chain -- slot 5 names slot 4 -- so a
-- house has exactly ONE live quest at any moment, and the whole board is seven to twelve quests wide.
-- Pin each of them to a single ground and a day's swamp holds whichever houses' next slot happened to
-- be authored swamp, which is usually none. A quest that says "tundra or a castle's outworks" is not
-- vaguer than one that says "tundra"; it is a quest whose fiction survives being reachable.
--
-- THE FIELD IS `map.biomes`, A LIST. `map.biome`, the single value ninety-two files still author, is
-- read as a one-element list -- so the widening pass can land a house at a time instead of as one
-- ninety-two file commit, and a file that never gets widened keeps working. Both names are known here
-- and NOWHERE ELSE: everything downstream (models/overworld.lua, models/arena.lua, the encounter pool)
-- reads a single resolved `map.biome` off the runtime copy, stamped with whichever ground the player
-- actually travelled to.
--
-- Pure model -- no love.graphics -- so it loads under the headless runner.

local Calendar = require("models.calendar")

local BiomeWindow = {}

BiomeWindow.schedule = require("data.biome_windows")

-- The windows authored for `biomeId`, or an empty list for a ground with no row. Empty means CLOSED
-- rather than always-open: a biome nobody scheduled is one nobody meant to ship, and the spec fails on
-- it, which is louder than it quietly being reachable all forty days.
function BiomeWindow.windows(biomeId)
    return (biomeId and BiomeWindow.schedule[biomeId]) or {}
end

-- Every biome id the schedule knows, sorted. Sorted rather than in pairs order because this feeds the
-- board's tab row, and a tab order that reshuffles between frames is unusable.
function BiomeWindow.ids()
    local ids = {}
    for id in pairs(BiomeWindow.schedule) do ids[#ids + 1] = id end
    table.sort(ids)
    return ids
end

function BiomeWindow.isOpen(biomeId, day)
    for _, w in ipairs(BiomeWindow.windows(biomeId)) do
        if day >= w[1] and day <= w[2] then return true end
    end
    return false
end

-- The grounds reachable on `day`, sorted. THE tab row.
function BiomeWindow.openOn(day)
    local open = {}
    for _, id in ipairs(BiomeWindow.ids()) do
        if BiomeWindow.isOpen(id, day) then open[#open + 1] = id end
    end
    return open
end

-- Days left in the window the biome is currently inside, COUNTING TODAY -- so a window's last morning
-- reads "1 day left" rather than "0", which would say the opposite of what is true. nil when shut.
--
-- This is the number the board's tab draws, and it is the whole pressure: a leg you want sitting in a
-- ground with two days left is a decision, and the same leg with sixteen is not.
function BiomeWindow.daysLeft(biomeId, day)
    for _, w in ipairs(BiomeWindow.windows(biomeId)) do
        if day >= w[1] and day <= w[2] then return w[2] - day + 1 end
    end
    return nil
end

-- The next day this ground opens after `day`, or nil if it never does again. Not drawn anywhere yet --
-- the in-run schedule strip was deliberately deferred -- but `. biome-report` reads it to name how long
-- a closed house's work is out of reach, which is the number the authoring pass is tuned against.
function BiomeWindow.opensOn(biomeId, day)
    local soonest
    for _, w in ipairs(BiomeWindow.windows(biomeId)) do
        if w[1] > day and (not soonest or w[1] < soonest) then soonest = w[1] end
    end
    return soonest
end

-- ---------------------------------------------------------------------------
-- What a quest says about where it happens
-- ---------------------------------------------------------------------------

-- The grounds a quest's fiction allows, as a list. Reads the new `map.biomes` first, falls back to the
-- old single `map.biome`, and returns an empty list for a quest that names neither -- which is a real
-- and permitted state, see `destinations` below.
function BiomeWindow.biomesOf(def)
    local map = def and def.map
    if not map then return {} end
    if type(map.biomes) == "table" and #map.biomes > 0 then
        local out = {}
        for _, id in ipairs(map.biomes) do out[#out + 1] = id end
        return out
    end
    if map.biome then return { map.biome } end
    return {}
end

-- WHERE THIS QUEST MAY BE STARTED TODAY. The single availability seam: a quest is on the board exactly
-- when this returns something, and the board files it under each ground it names.
--
-- TWO EXEMPTIONS, BOTH FAIL-OPEN, because the failure mode of a window system is a quest that silently
-- stops existing -- and a quest that has vanished from the board is unfindable from inside the game.
--
--   the finale       ignores the schedule outright. The Gate Below is gated on the DAY
--                    (Calendar.isFinalDay) and on nothing else. A season table that could hide the
--                    ending is one bad edit away from a campaign with no last battle, and no test of
--                    the schedule's own shape would catch it -- so the exemption lives here, above
--                    the table, rather than being a row in it.
--   naming no ground is not an error. A quest with no `biomes` is reachable from EVERY open ground,
--                    the same tolerance Biome.get and models/sprite.lua already show a half-authored
--                    blueprint. It reads oddly on the board rather than disappearing from it.
--
-- Returns a list of biome ids. The caller starts the quest with `map.biome` stamped to whichever of
-- them the player travelled to.
function BiomeWindow.destinations(def, day)
    local named = BiomeWindow.biomesOf(def)

    if def and def.finale then
        -- Never filtered. It names the underworld and the underworld is where it is fought, open
        -- window or not.
        return #named > 0 and named or BiomeWindow.ids()
    end

    if #named == 0 then
        return BiomeWindow.openOn(day)
    end

    local out = {}
    for _, id in ipairs(named) do
        if BiomeWindow.isOpen(id, day) then out[#out + 1] = id end
    end
    return out
end

-- Is this quest takeable on `day` at all? The one predicate Quest.available asks.
function BiomeWindow.available(def, day)
    return #BiomeWindow.destinations(def, day) > 0
end

-- The soonest day this quest becomes takeable again, or nil if it is takeable now or never will be.
-- Feeds `. biome-report`'s starvation check: a live quest that no remaining day can reach is a line
-- the player has been locked out of, which is the one outcome the schedule must never produce.
function BiomeWindow.nextOpenDay(def, day)
    for d = day, Calendar.DAYS do
        if BiomeWindow.available(def, d) then return d end
    end
    return nil
end

return BiomeWindow
