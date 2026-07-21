-- Battle spoils: the gold and loot a won combat/elite fight hands over. Enemies carry no reward
-- data of their own and there is no drop-table authoring, so spoils are COMPUTED from the size of
-- the roster that was beaten and the company's prestige -- richer fights the deeper the run. An
-- encounter may override either half (rewardGold / loot on its blueprint), mirroring how a treasure
-- cache authors its own `loot` list (data/encounters/encounter_treasure.lua).
--
--   local s = Spoils.roll({ enemyUnits = battle.enemyUnits, prestige = 3, kind = "combat" })
--   -- s = { gold = 71, loot = { "consumable_healing_potion" } }
--
-- Pure logic, no love.graphics at require time -- loads under the headless test runner. RNG falls
-- back to math.random when love.math is unavailable, so the roll is exercisable outside a window.

local Item = require("models.item")

local Spoils = {}

local GOLD_PER_ENEMY = 8    -- base gold each defeated enemy is worth, before prestige/jitter
local ELITE_GOLD_MULT = 1.8 -- an elite fight pays out richer than a like-sized common one

-- love.math.random when running under LÖVE, else math.random. Same call signatures: () -> [0,1),
-- (m) -> [1,m], (m,n) -> [m,n]. Kept behind one helper so the whole module is engine-agnostic.
local function rnd(...)
    if love and love.math and love.math.random then return love.math.random(...) end
    return math.random(...)
end

-- Gold for beating `count` enemies at `prestige`. An override short-circuits the whole computation.
local function rollGold(count, prestige, kind, override)
    if override then return math.max(0, math.floor(override)) end
    local base = GOLD_PER_ENEMY * math.max(1, count) * math.max(1, prestige)
    local jitter = 0.85 + rnd() * 0.30 -- +/-15% so two identical fights don't pay identically
    local gold = base * jitter
    if kind == "elite" then gold = gold * ELITE_GOLD_MULT end
    return math.max(1, math.floor(gold + 0.5))
end

-- The drop pool: every PRICED item within a prestige-scaled price band. Price is the "shoppable"
-- marker -- natural weapons, bound relics and quest items have none, so they can never drop. Cheaper
-- items (and consumables) weight heavier, so the common reward is a potion, not the best sword you
-- could theoretically afford.
local function lootCandidates(maxPrice)
    local pool = {}
    for id, def in pairs(Item.defs) do
        if def.price and def.price > 0 and def.price <= maxPrice and not def.bound then
            local weight = 1 + math.max(0, maxPrice - def.price) / maxPrice -- ~1 (dear) .. ~2 (cheap)
            if def.type == "consumable" then weight = weight * 2 end
            pool[#pool + 1] = { id = id, weight = weight }
        end
    end
    return pool
end

-- Weighted draw of one id from a { id, weight } pool, or nil for an empty pool.
local function pick(pool)
    if #pool == 0 then return nil end
    local total = 0
    for _, e in ipairs(pool) do total = total + e.weight end
    local r = rnd() * total
    for _, e in ipairs(pool) do
        r = r - e.weight
        if r <= 0 then return e.id end
    end
    return pool[#pool].id -- float slop guard: the last entry mops up the remainder
end

-- 0-2 loot ids. An override list is used verbatim (unknown ids dropped so a typo can't crash the
-- later Item.instantiate). Otherwise: a likely first drop and an unlikely second, both richer and
-- more probable for an elite.
local function rollLoot(prestige, kind, override)
    if override then
        local out = {}
        for _, id in ipairs(override) do
            if Item.defs[id] then out[#out + 1] = id end
        end
        return out
    end
    local elite = kind == "elite"
    local maxPrice = 40 + math.max(1, prestige) * 60
    if elite then maxPrice = maxPrice * 1.5 end
    local pool = lootCandidates(maxPrice)
    local out = {}
    if rnd() < (elite and 0.90 or 0.55) then
        local id = pick(pool); if id then out[#out + 1] = id end
    end
    if rnd() < (elite and 0.45 or 0.18) then
        local id = pick(pool); if id then out[#out + 1] = id end
    end
    return out
end

-- Roll the spoils for a won fight.
--   opts.enemyUnits  the beaten roster (its length is the count); or pass opts.count directly
--   opts.prestige    the company's prestige (default 1)
--   opts.kind        "combat" | "elite" (elite pays richer); anything else treated as common
--   opts.rewardGold  encounter override: exact gold, skipping the computation
--   opts.loot        encounter override: an explicit id list, skipping the roll
function Spoils.roll(opts)
    opts = opts or {}
    local count = opts.count or (opts.enemyUnits and #opts.enemyUnits) or 1
    local prestige = opts.prestige or 1
    local kind = opts.kind or "combat"
    return {
        gold = rollGold(count, prestige, kind, opts.rewardGold),
        loot = rollLoot(prestige, kind, opts.loot),
    }
end

return Spoils
