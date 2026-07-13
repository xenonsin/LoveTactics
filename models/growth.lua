-- Class growth: the level-up half of the character progression system. Characters do not carry
-- individual XP -- every roster member's level tracks the player's global `prestige` (see
-- Player.syncLevels). What makes two same-level characters differ is HOW you played them: each
-- character tallies which class's items it casts (Character.recordUse, fired from Combat.useItem),
-- and on each level-up it gains the stats of its MOST-USED class. A knight you keep casting Fireball
-- with grows into a battlemage. Inspired by Fire Emblem growth rates + FFT job emergence, realized
-- through the "anyone can carry anything" gear philosophy (models/item.lua).
--
-- Growth is DETERMINISTIC (fixed per-level gains per class, no RNG) -- prestige-lockstep gives no way
-- to grind away a bad roll, so permanence favors predictability. Gains are BAKED into char.stats
-- (into `.max` for resource stats) and the running total kept in char.growth, so a save that stores
-- only the accumulated delta re-bakes on load without replaying history.
--
-- Blueprints live in data/growth/<class>.lua -- a flat table of per-level stat gains, one file per
-- Item.CLASSES entry. Pure logic (no love.graphics), so it loads under the headless tests.

local Registry = require("models.registry")
local Character = require("models.character")

local Growth = {}

Growth.defs = Registry.load("data/growth", "data.growth")

-- The growth class used when a character has never cast a class-tagged item and declares no innate
-- `class` (a class-less summon, say). Must name a real data/growth/<id>.lua file.
Growth.NEUTRAL_CLASS = "fighter"

local function isResourceStat(name)
    for _, stat in ipairs(Character.RESOURCE_STATS) do
        if stat == name then return true end
    end
    return false
end

-- The class whose growth table a level-up should apply: the character's most-cast class. Ties and an
-- empty tally fall back to the innate blueprint `class`, then the neutral default -- so every
-- character always resolves to some real growth table.
function Growth.dominantClass(char)
    local best, bestCount = nil, 0
    for class, count in pairs(char.classUse or {}) do
        -- Strict `>` keeps the first-seen leader on a tie; the innate class breaks a genuine tie below.
        if count > bestCount then best, bestCount = class, count end
    end
    -- A tie (or no casts): prefer the character's own innate class if it is itself among the leaders,
    -- otherwise use it as the declared fallback.
    if char.class and (char.classUse or {})[char.class] == bestCount then
        best = char.class
    end
    return best or char.class or Growth.NEUTRAL_CLASS
end

-- Apply one level's worth of `class` growth to `char`: add each stat gain to the running total
-- (char.growth) and bake it into the live stat (the resource `.max` for health/mana/stamina).
-- Returns the per-stat gains applied, for a level-up summary. An unknown class is a no-op.
function Growth.applyLevel(char, class)
    local def = Growth.defs[class]
    if not def then return {} end

    char.growth = char.growth or {}
    local gains = {}
    for stat, amount in pairs(def) do
        char.growth[stat] = (char.growth[stat] or 0) + amount
        gains[stat] = amount

        local live = char.stats and char.stats[stat]
        if type(live) == "table" and isResourceStat(stat) then
            -- Resource pool: raise the ceiling. `current` is refilled to max on hub entry
            -- (Player.restore), so nudging it up here keeps a just-leveled unit from reading as hurt.
            live.max = live.max + amount
            live.current = math.min((live.current or live.max) + amount, live.max)
        elseif type(live) == "number" then
            char.stats[stat] = live + amount
        end
    end
    return gains
end

-- Catch `char` up to `targetLevel`, resolving one level-up at a time (each reads the tally as it
-- stands, so a multi-level prestige jump can grow across more than one class). Idempotent: never runs
-- backward, so calling it again at the same level does nothing. Returns { fromLevel, toLevel, class,
-- gains } when the character actually advanced, or nil when it was already caught up.
function Growth.resolve(char, targetLevel)
    char.level = char.level or 1
    if char.level >= targetLevel then return nil end

    local fromLevel = char.level
    local totalGains = {}
    local lastClass
    while char.level < targetLevel do
        char.level = char.level + 1
        local class = Growth.dominantClass(char)
        lastClass = class
        for stat, amount in pairs(Growth.applyLevel(char, class)) do
            totalGains[stat] = (totalGains[stat] or 0) + amount
        end
    end

    return { char = char, fromLevel = fromLevel, toLevel = char.level, class = lastClass, gains = totalGains }
end

return Growth
