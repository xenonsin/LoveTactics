-- Class growth: the level-up half of the character progression system. Characters do not carry
-- individual XP -- every roster member's level tracks the player's global `prestige` (see
-- Player.syncLevels). What makes two same-level characters differ is HOW you played them: each
-- character banks technique under the class or discipline of every item it casts
-- (Character.recordTechnique, fired from Combat.useItem), and each level-up apportions its stat gains
-- across everything banked since the last one. A knight you keep casting Fireball with grows into a
-- battlemage, in proportion to how much Fireball. Inspired by Fire Emblem growth rates + FFT job
-- emergence, realized through the "anyone can carry anything" gear philosophy (models/item.lua).
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

-- How fast an ENEMY's output climbs per level. Both of the tables the common enemy stock grows on --
-- fighter (the NEUTRAL_CLASS default) and champion -- carry `damage = 3`, so this is the rate every
-- scaled attacker's swing gains on you.
--
-- It matters because mitigation is SUBTRACTIVE with a floor of 1 (Combat.mitigatedDamage): incoming
-- damage is `blow - defense`, so a class whose pool and armour together grow slower than the blow does
-- gets relatively frailer every level, and is eventually one-shot. That is not a tuning wobble, it is
-- divergence -- it always arrives, the only question is at which level. Before this rule landed, a mage
-- (health +2, no defense growth at all) was one-shot by a champion-table attacker at level 13.
Growth.ENEMY_DAMAGE_GROWTH = 3

-- How closely ordinary enemies track the player's level. Below 1 they lag, and the company sits
-- permanently ahead of the common stock -- which is the only way stat scaling can express "we have
-- grown", because it CANNOT express "we are pulling away".
--
-- That limit is structural, not a tuning failure, and it is worth stating so nobody spends an
-- afternoon looking for the knob: with both sides growing linearly and mitigation subtracting, the
-- exchange converges to a constant. Every lag setting merely picks WHICH constant. Measured against
-- the live combat model, hits an enemy needs to fell a knight:
--
--     player level      1:1      x0.9     x0.8
--          10            8        10       13
--          46            7        10       14
--
-- The one policy that genuinely diverges is a hard ceiling -- stop scaling enemies at level N -- and it
-- diverges catastrophically: once the player's defense passes the frozen blow, damage falls to the
-- floor of 1 and a knight needs 302 hits. That is the original no-scaling bug wearing a hat, so a
-- ceiling is deliberately NOT how this is done.
--
-- 0.9 is a felt edge without free fights. Real growth within a run comes from gear, abilities,
-- disciplines and roster -- the things stat curves cannot flatten.
Growth.ENEMY_LEVEL_LAG = 0.9

-- The survivability a growth table buys per level: pool plus armour, on one damage channel.
-- `magical` reads the magic side (health + magicDefense) instead of the physical one.
function Growth.survivability(def, magical)
    if not def then return 0 end
    return (def.health or 0) + (def[magical and "magicDefense" or "defense"] or 0)
end

-- THE RULE, enforced over every table by tests/growth_spec.lua: a class must gain at least as much
-- survivability per level as a scaled enemy gains attack. Meet it and time-to-kill holds flat at every
-- level and at any LEVEL_CAP; miss it and the class has an expiry date.
--
-- Deliberately a floor, not an equality. A knight buying far more than the minimum is a knight, and the
-- exchange stays stable because the surplus only slows the fight -- it never inverts it.
function Growth.meetsSurvivabilityFloor(def, magical)
    return Growth.survivability(def, magical) >= Growth.ENEMY_DAMAGE_GROWTH
end

-- A character's ceiling, and how fast prestige walks toward it. Levels are DERIVED from the player's
-- global prestige (Player.syncLevels) rather than earned per character, so without a cap a character's
-- level is just the campaign's prestige total. Prestige is now a flat count of quests completed
-- (Quest.PRESTIGE_PER_QUEST), so that total is exactly 92 -- and New Game+ carries it forward
-- (Player.newGamePlus resets only the quest ledger), so a second run reaches 184.
--
-- At 2 prestige per level the campaign ends at level 46, comfortably UNDER the cap. That is deliberate:
-- a cap reached before the last quest leaves a dead stretch where finishing a quest grants nothing,
-- which is exactly what a cap should avoid. The remaining levels are headroom New Game+ grows into, so
-- the ceiling does its real job -- bounding a prestige total that otherwise never stops -- without ever
-- being felt as a wall on a first playthrough.
--
-- 2, not 3, because the payout flattened. The campaign used to pay 138 prestige over those same 92
-- quests (1, 2 or 3 apiece, back-loaded) and 3-per-level landed level 46. Flat 1s pay 92, so holding
-- 3 would have quietly ended the campaign at level 31; 2 reproduces the old endpoint exactly. What
-- changed is not the destination but the REGULARITY -- a level every second quest, always, instead of
-- scattered wherever the authored weights happened to cross a threshold.
Growth.LEVEL_CAP = 50
Growth.PRESTIGE_PER_LEVEL = 2

-- The level a character sits at for a given global prestige. The single owner of that mapping: the
-- roster, enemy scaling (states/battle.lua), and the advancement bar all read levels through here, so
-- there is one curve to retune rather than three.
function Growth.levelForPrestige(prestige)
    local raw = 1 + math.floor(((prestige or 1) - 1) / Growth.PRESTIGE_PER_LEVEL)
    return math.max(1, math.min(Growth.LEVEL_CAP, raw))
end

-- Prestige still owed before the next level lands, and how far into the current step we are -- what the
-- post-quest advancement bar fills (ui/panels/advancement.lua). Returns `into, span` where `into` is
-- 0..span-1, or nil at the cap, which has no next level to fill toward and must not render as a bar
-- frozen just short of full.
function Growth.prestigeIntoLevel(prestige)
    if Growth.levelForPrestige(prestige) >= Growth.LEVEL_CAP then return nil end
    return ((prestige or 1) - 1) % Growth.PRESTIGE_PER_LEVEL, Growth.PRESTIGE_PER_LEVEL
end

-- ---------------------------------------------------------------------------
-- Enemy scaling
-- ---------------------------------------------------------------------------

-- The level a combatant the player did not bring fights at. Enemies and escorted allies are minted
-- from blueprints and grown through the SAME tables the roster uses -- an enemy knight at level 12 is
-- computed exactly like a player knight at level 12 -- so there is no second balance surface to keep
-- in sync. Without this they stayed at blueprint level 1 forever while the roster climbed, which is
-- what let a demon grunt fall to the 1-damage floor against a knight by prestige 9.
--
-- A FLOOR is authored, and scaling takes over above it. Two independent floors, because they say
-- different things:
--
--   `def.floorLevel` on a blueprint   this CREATURE is never weaker than this, wherever it turns up.
--                                     A champion that reads as a wall early keeps that identity in
--                                     every encounter, without each quest having to remember to say so.
--   `battleFloor` on a fight          this FIGHT is never easier than this, whoever walks into it.
--                                     Keeps a story beat from being walked on a replay or in New Game+.
--
-- Whichever of the two floors and the player's tracked level is highest wins. Clamped to LEVEL_CAP so
-- everything stays inside the range the survivability floor above is verified over.
--
-- `scaling = false` opts out entirely -- no floor, no climb, blueprint-exact. Reserved for units whose
-- precise arithmetic is load-bearing rather than merely tuned (the prologue's grunt, whose claw maths
-- the parry lesson is built on).
function Growth.combatantLevel(def, playerLevel, battleFloor)
    if def and def.scaling == false then return 1 end

    -- Ordinary stock lags; anything that declares a floor of its own is a NAMED thing -- an elite, a
    -- boss, a fight's centrepiece -- and tracks the player exactly. That split is the whole reason the
    -- lag is safe to have: the trash becomes a victory lap and the named fight is still a fight.
    local tracked = playerLevel or 1
    if not (def and def.floorLevel) then
        tracked = 1 + math.floor(Growth.ENEMY_LEVEL_LAG * (tracked - 1))
    end

    local level = math.max((def and def.floorLevel) or 1, battleFloor or 1, tracked)
    return math.max(1, math.min(Growth.LEVEL_CAP, level))
end

-- Mint a combatant already grown to the level this fight puts it at. The counterpart to
-- Character.instantiate for everyone who is not on the player's roster.
function Growth.spawn(id, playerLevel, battleFloor)
    local char = Character.instantiate(id)
    Growth.resolve(char, Growth.combatantLevel(Character.defs[id], playerLevel, battleFloor))
    return char
end

local function isResourceStat(name)
    for _, stat in ipairs(Character.RESOURCE_STATS) do
        if stat == name then return true end
    end
    return false
end

-- Every key in `tally` holding a positive amount, SORTED. Sorted because what follows sums floats over
-- them, and float addition is not associative: `pairs()` order holds still within one build and is
-- promised by nothing across two, so an unsorted sum is the same character with different stats on
-- another machine. models/build.lua promises `(id, tally, level)` rebuilds identically anywhere and
-- models/state_hash.lua compares peers mid-duel, so that is a real failure, not a theoretical one.
local function sortedKeys(tally)
    local keys = {}
    for key, amount in pairs(tally or {}) do
        if (amount or 0) > 0 then keys[#keys + 1] = key end
    end
    table.sort(keys)
    return keys
end

-- The class leading a usage tally, with `innate` (the blueprint's own class) as both tie-breaker and
-- fallback. Shared by the readings below so they can never drift apart in how they settle a tie.
local function leaderOf(tally, innate)
    local best, bestCount = nil, 0
    for class, count in pairs(tally or {}) do
        -- A tie settles by name. The innate class breaks a genuine tie below, but only when it is
        -- itself one of the leaders -- two OTHER classes level with each other leave that check
        -- unfired, and "first-seen" over pairs() is not an answer: the order holds still within one
        -- build and is promised by nothing across two. This picks the growth table a level-up
        -- applies, so an unstable reading is the same character with different stats on another
        -- machine, which is also how a normalized duel roster would fail to agree with itself.
        if count > bestCount or (count == bestCount and best and class < best) then
            best, bestCount = class, count
        end
    end
    -- A tie (or no casts): prefer the character's own innate class if it is itself among the leaders,
    -- otherwise use it as the declared fallback.
    if innate and (tally or {})[innate] == bestCount then
        best = innate
    end
    return best or innate or Growth.NEUTRAL_CLASS
end

-- What this character IS, over its whole career: the most-earned key across the cumulative ledger.
-- The player-facing TITLE (ui/panels/party.lua), and singular on purpose -- "Growing as Knight and a
-- bit of Mage" is not a title. What a level-up actually applies is the blend below.
function Growth.dominantClass(char)
    return leaderOf(char.technique, char.class)
end

-- What this character has earned toward its next level, per key: the delta since the last level-up
-- (Character.techniqueSinceLevel). Reading the cumulative ledger here instead would price a change of
-- direction against the character's entire history -- a veteran taking up a new discipline would have
-- to out-cast everything it had ever done before one level followed it, so experimenting would get
-- steadily more expensive the longer a character survived. Against the recent reading the cost of
-- turning is constant: one level's worth of casting buys one level, at level 3 or level 40 alike.
function Growth.sinceLevel(char)
    local since = {}
    for _, key in ipairs(sortedKeys(char and char.technique)) do
        local delta = Character.techniqueSinceLevel(char, key)
        if delta > 0 then since[key] = delta end
    end
    return since
end

-- The single key leading that reading. Kept as the HEADLINE for a level-up summary ("as Knight") and
-- for the growthBy ledger's fallback; the stats themselves are blended, not credited to it.
function Growth.creditClass(char)
    return leaderOf(Growth.sinceLevel(char), char.class)
end

-- How one level's growth is apportioned: `{ [key] = share }` summing to 1 over what this character has
-- been casting since it last levelled.
--
-- THIS REPLACES WINNER-TAKE-ALL. A level used to be credited entirely to the leader and the rest of the
-- reading discarded, so casting knight 11 and mage 10 threw away all ten mage casts -- 51% of the play
-- deciding 100% of the level, with no gradient anywhere: every cast worthless except the one that
-- crossed the threshold. Now every cast moves the blend, which is also what makes the number on the
-- character sheet mean something. It used to be purely ordinal (only `count > bestCount` was ever
-- read), so "Knight 14" meant "more than 11" and nothing else.
--
-- Falls back to the innate class at share 1.0 when nothing has been cast -- the same fallback chain
-- leaderOf uses (innate, else NEUTRAL_CLASS), so an enemy minted by Growth.spawn with no ledger at all
-- grows exactly as it did before.
function Growth.shares(char)
    local since = Growth.sinceLevel(char)
    local keys = sortedKeys(since)

    local total = 0
    for _, key in ipairs(keys) do total = total + since[key] end
    if total <= 0 then
        return { [leaderOf(nil, char and char.class)] = 1 }, 1
    end

    local shares = {}
    for _, key in ipairs(keys) do shares[key] = since[key] / total end
    return shares, total
end

-- Bake `gains` (whole points, per stat) into `char`: add to the running total (char.growth) and to the
-- live stat -- the resource `.max` for health/mana/stamina, the number itself for everything else.
local function bake(char, gains)
    char.growth = char.growth or {}
    for stat, amount in pairs(gains) do
        char.growth[stat] = (char.growth[stat] or 0) + amount

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
end

-- Apply one level's worth of `class` growth to `char`, whole and undiluted. The single-class path,
-- kept for callers that mean exactly one table. Returns the per-stat gains applied; unknown class is a
-- no-op.
function Growth.applyLevel(char, class)
    local def = Growth.defs[class]
    if not def then return {} end

    local gains = {}
    for stat, amount in pairs(def) do gains[stat] = amount end
    bake(char, gains)
    return gains
end

-- Apply one level's worth of BLENDED growth: each stat is the share-weighted sum across the class
-- tables, and whatever does not come out a whole number is CARRIED in char.growthCarry rather than
-- rounded away. Over a career the carry pays out in full, so a 50/50 knight/mage is exactly half of
-- each table's total and not a rounding artefact of either.
--
-- Whole numbers at every step because the stats they bake into are integers and a save stores the
-- accumulated delta (see the module header). Carrying rather than rounding is what lets the shares be
-- fractional without the stats ever being.
--
-- The survivability floor needs no separate defence here: survivability is LINEAR in a growth table
-- (Growth.survivability sums two of its fields), so a convex combination of tables that each clear
-- Growth.meetsSurvivabilityFloor clears it too. Blending cannot reopen the hole that rule closes.
function Growth.applyLevelBlend(char, shares)
    char.growthCarry = char.growthCarry or {}
    local carry = char.growthCarry

    -- Sorted, for the reason sortedKeys exists: this sums floats.
    local keys = {}
    for key in pairs(shares or {}) do keys[#keys + 1] = key end
    table.sort(keys)

    -- Accumulate the fractional gain per stat, then spend the whole part and keep the remainder.
    for _, key in ipairs(keys) do
        local def = Growth.defs[key]
        if def then
            local share = shares[key]
            for stat, amount in pairs(def) do
                carry[stat] = (carry[stat] or 0) + amount * share
            end
        end
    end

    local gains = {}
    for stat, pending in pairs(carry) do
        local whole = math.floor(pending)
        if whole ~= 0 then
            gains[stat] = whole
            carry[stat] = pending - whole
        end
    end
    bake(char, gains)
    return gains
end

-- Catch `char` up to `targetLevel`. Idempotent: never runs backward, so calling it again at the same
-- level does nothing. Returns { fromLevel, toLevel, class, shares, levels, gains } when the character
-- actually advanced, or nil when it was already caught up. `class` is the headline (the leading key);
-- `shares` is how the gains were actually apportioned.
--
-- The advance is apportioned across EVERYTHING cast since the last level (Growth.shares), and the
-- reading is then checkpointed, so the next level measures from here rather than from zero. Three
-- consequences worth knowing:
--
--   * Every cast moves the result. The old rule credited the whole level to the leader and discarded
--     the rest, so there was no gradient anywhere -- only the cast that crossed the threshold mattered,
--     and 51% of the play decided 100% of the level.
--   * A blend emerges WITHIN a level, not merely across a career, and still in whole numbers: the
--     fractions ride in char.growthCarry until they add up to a point (Growth.applyLevelBlend).
--   * Levels already credited are never revisited, so a stat can only ever go UP. Re-apportioning
--     history against the current reading would be the alternative, and it would mean a character that
--     changed direction could LOSE max health on a level-up -- unshippable.
--
-- The checkpoint is a SNAPSHOT of the ledger, not a wipe of it. The ledger is also the wallet and the
-- career title now (Character.recordTechnique), so clearing it would pay for a level by deleting money
-- and history; "consumed" is expressed as "the delta is measured from here".
--
-- A multi-level jump (a quest paying several prestige, a roster catching up on load) applies the same
-- share vector once PER LEVEL rather than as one batch, so the carry accumulates level by level and
-- three levels at once land exactly where three separate levels would.
function Growth.resolve(char, targetLevel)
    char.level = char.level or 1
    if char.level >= targetLevel then return nil end

    local fromLevel = char.level
    local since = Growth.sinceLevel(char)
    local shares = Growth.shares(char)
    local class = leaderOf(since, char.class) -- the headline for a level-up summary

    -- Checkpoint: from here on the level-up reading is the delta above these amounts.
    char.techniqueAtLevel = char.techniqueAtLevel or {}
    for key, amount in pairs(char.technique or {}) do
        char.techniqueAtLevel[key] = amount
    end

    local totalGains = {}
    while char.level < targetLevel do
        char.level = char.level + 1
        for stat, amount in pairs(Growth.applyLevelBlend(char, shares)) do
            totalGains[stat] = (totalGains[stat] or 0) + amount
        end
    end

    -- The per-key ledger of levels credited: monotonic, and the only record of HOW a character was
    -- built rather than merely how far. Credited in SHARES, so a level split 52/48 books 0.52 and 0.48
    -- instead of booking the whole level to the winner -- which keeps this ledger agreeing with the
    -- stats it summarizes. Discipline.level floors it for the shelf gate.
    local levels = char.level - fromLevel
    char.growthBy = char.growthBy or {}
    for key, share in pairs(shares) do
        char.growthBy[key] = (char.growthBy[key] or 0) + share * levels
    end

    return { char = char, fromLevel = fromLevel, toLevel = char.level, class = class,
             shares = shares, levels = levels, gains = totalGains }
end

return Growth
