-- RELICS: the roguelike inner-loop content. Where a companion's OVERWORLD ABILITY (models/overworld_-
-- ability.lua) is keyed to WHO is in your party, a relic is FOUND on the expedition -- dropped by a
-- cache, an elite, a shrine, a crossroads gamble -- and carried only for THIS quest. It is the thing
-- that snowballs: pick up three or four across a run's ~8 nodes and the party you reach the boss with is
-- not the party you left the hub with. The across-runs power (gear, prestige, roster) already persists at
-- the hub; relics are the WITHIN-run power the game was missing.
--
-- Two moral tiers, on the seven-sins spine the world already turns on:
--   * VIRTUE -- a clean boon, no strings.
--   * VICE   -- more power for a standing cost (allies burn, max HP is spent, a wound never closes).
-- A Vice is the greed/safety dial made into an object you choose to pick up. Both are safe to design
-- boldly BECAUSE the meta is solved: a wipe costs the run's relics, never your gear or your progress.
--
-- This module is a REGISTRY + DISPATCHER, deliberately the twin of overworld_ability.lua:
--   * headless-safe (no love.graphics at require-time; RNG falls back to math.random)
--   * relics declare hooks in their DATA file (data/relics/<id>.lua). The overworld hooks fire on the
--     same four traversal events the abilities use -- "step", "encounterCleared", "battleStart",
--     "objectiveReached" -- so a relic and a companion perk compose without knowing about each other.
--   * a relic's hook gets (relic, bucket, ctx). `bucket` is its per-RUN scratch (auto-created, keyed by
--     the relic id), reset each quest like the fog; `ctx` carries the run + bound, headless-safe helpers
--     (restore / grantBoon / addGold / notify / party / grid / cell / spoils), the same shape a trait's
--     ctx takes, so a data-file hook composes effects without reaching into any model directly.
--
-- COMBAT-side relics don't need a hook at all: they name existing TRAITS (models/trait.lua), which the
-- battle attaches to the party's units at setup exactly as it attaches an item's traits -- so "first
-- strike crits" or "allies burn each turn" reuses the whole reactive-trait machinery for free. A relic
-- that wants a one-off opening effect (a barrier as the fight opens) uses ctx.grantBoon in its
-- battleStart hook instead, the same opening-boons seam Rowan/Saber/Ren spend their banked readiness
-- through. Battle setup reads Relic.grantedTraits / Relic.openingBoons off the run to apply both.

local Player = require("models.player")

local Relic = {}

Relic.defs = require("models.registry").load("data/relics", "data.relics")

-- ---------------------------------------------------------------------------
-- Registry queries
-- ---------------------------------------------------------------------------

function Relic.get(id) return Relic.defs[id] end

local function rnd(...)
    if love and love.math and love.math.random then return love.math.random(...) end
    return math.random(...)
end

-- Is `def` eligible to DROP in this context? Gated by minPrestige and an optional condition(ctx), the
-- same contract encounters use (models/encounter.lua), so the two selection systems read alike.
local function eligible(def, ctx)
    if def.minPrestige and (ctx.prestige or 1) < def.minPrestige then return false end
    if def.condition and not def.condition(ctx) then return false end
    return true
end

local function weightOf(def, ctx)
    local w = def.weight or 1
    if type(w) == "function" then w = w(ctx) end
    return w or 0
end

-- The relics eligible to drop for `ctx`, as { id, def, weight } entries (weight > 0). `ctx.alignment`
-- ("virtue"|"vice") and `ctx.affinity` ("combat"|"overworld") filter the pool so a Shrine can ask only
-- for Vices and a Reliquary only for the rare shelf. `ctx.exclude` (a held-state or id->true set) drops
-- what the run already holds, so a cache never hands you a duplicate.
function Relic.pool(ctx)
    ctx = ctx or {}
    local held = ctx.exclude and Relic._excludeSet(ctx.exclude) or {}
    local out = {}
    for id, def in pairs(Relic.defs) do
        if not held[id]
            and (not ctx.alignment or def.alignment == ctx.alignment)
            and (not ctx.affinity or def.affinity == ctx.affinity or def.affinity == "both")
            and (not ctx.tier or def.tier == ctx.tier)
            and eligible(def, ctx) then
            local w = weightOf(def, ctx)
            if w > 0 then out[#out + 1] = { id = id, def = def, weight = w } end
        end
    end
    return out
end

-- Normalise an exclude argument (a run relic-state, a list of ids, or an id->true set) to an id->true
-- set, so Relic.pool can be handed whichever is convenient at the call site.
function Relic._excludeSet(x)
    local set = {}
    if type(x) ~= "table" then return set end
    if x.held then for _, id in ipairs(x.held) do set[id] = true end; return set end
    for k, v in pairs(x) do
        if type(k) == "number" then set[v] = true else if v then set[k] = true end end
    end
    return set
end

-- Draw one relic id from `pool` (Relic.pool output) by weight, or nil if the pool is empty.
function Relic.roll(pool)
    if not pool or #pool == 0 then return nil end
    local total = 0
    for _, e in ipairs(pool) do total = total + e.weight end
    local r = rnd() * total
    for _, e in ipairs(pool) do
        r = r - e.weight
        if r <= 0 then return e.id end
    end
    return pool[#pool].id
end

-- ---------------------------------------------------------------------------
-- The run inventory (plain data, so it serialises into the run save beside abilityState)
-- ---------------------------------------------------------------------------

-- A fresh, empty relic-state for a run. `held` is the ordered list of relic ids the party carries this
-- quest; `scratch` namespaces each relic's per-run bucket by id (the twin of abilityState's per-char
-- buckets). Reset each quest in states/game.lua's enter, exactly like the fog and the ability scratch.
function Relic.newState()
    return { held = {}, scratch = {} }
end

function Relic.has(state, id)
    for _, held in ipairs(state and state.held or {}) do
        if held == id then return true end
    end
    return false
end

-- Grant `id` to the run. Relics are unique per run (a cleaner scratch and the usual roguelike rule), so
-- a re-grant is a no-op. Returns the def on a real grant, nil when it was a duplicate or unknown id.
function Relic.grant(state, id)
    if not (state and Relic.defs[id]) or Relic.has(state, id) then return nil end
    state.held = state.held or {}
    state.scratch = state.scratch or {}
    state.held[#state.held + 1] = id
    state.scratch[id] = state.scratch[id] or {}
    return Relic.defs[id]
end

-- Every held relic as { id, def } in the order taken.
function Relic.held(state)
    local out = {}
    for _, id in ipairs(state and state.held or {}) do
        local def = Relic.defs[id]
        if def then out[#out + 1] = { id = id, def = def } end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- Helpers shared with the dispatch ctx (mirrors overworld_ability.lua's, so relic hooks and ability
-- hooks reason about the party the same way)
-- ---------------------------------------------------------------------------

local function pool(char, stat)
    local s = char.stats and char.stats[stat]
    return type(s) == "table" and s or nil
end

local function restore(char, stat, amount)
    local p = pool(char, stat)
    if not (p and p.max) then return 0 end
    local before = p.current or 0
    p.current = math.min(p.max, before + amount)
    return p.current - before
end

local function mostWounded(party)
    local target, frac
    for _, c in ipairs(party or {}) do
        local hp = pool(c, "health")
        if hp and (hp.max or 0) > 0 then
            local f = (hp.current or 0) / hp.max
            if f < 1 and (not frac or f < frac) then frac = f; target = c end
        end
    end
    return target
end

-- The front line: whoever the player actually stood nearest the enemy in this fight's deployment phase.
-- The battle supplies it (states/battle.lua resolves the opening once placement is committed), because
-- placement is a per-battle decision made over the real board -- there is no standing arrangement here
-- to read. Falls back to the whole party, which is the right answer wherever no line has formed yet.
local function frontRow(supplied, party)
    if type(supplied) == "function" then supplied = supplied() end
    if type(supplied) == "table" and #supplied > 0 then return supplied end
    return party or {}
end

-- ---------------------------------------------------------------------------
-- Overworld dispatch
-- ---------------------------------------------------------------------------

-- The ctx a relic hook receives: the raw run fields plus bound, headless-safe helpers. `ctx.boons` is the
-- opening-boons queue -- grantBoon appends a { char, id, opts } there and battle setup drains it onto the
-- matching unit at spawn (the same seam the battle-affecting abilities spend through). Everything a hook
-- needs to touch the run flows through here, so a data file never requires a model directly.
local function ctxFor(ctx)
    local party = ctx.party or (ctx.player and ctx.player.party) or {}
    ctx.party = party
    ctx.boons = ctx.boons or {}

    ctx.restore = ctx.restore or function(char, stat, amount) return restore(char, stat, amount) end
    ctx.mostWounded = ctx.mostWounded or function() return mostWounded(party) end
    -- `ctx.frontRow` is normally supplied by the battle (the units actually standing on the forward line
    -- of the deploy zone). Bound here as a no-op fallback for a dispatch with no board -- everyone.
    local supplied = ctx.frontRow
    ctx.frontRow = function() return frontRow(supplied, party) end
    ctx.rnd = ctx.rnd or rnd
    ctx.notify = ctx.notify or function() end
    ctx.say = function(msg) ctx.notify(msg) end
    ctx.addGold = ctx.addGold or function(amount)
        if ctx.player and amount and amount ~= 0 then Player.addGold(ctx.player, amount) end
    end
    -- Take `amount` off a pool as a Vice's standing toll -- floored at 1, so a relic's price wounds but
    -- never fells (a wipe should come from the fight, not from carrying a cursed coin). Returns what was
    -- actually taken. The counterpart to restore, for the greedy half of the shelf.
    ctx.drain = ctx.drain or function(char, stat, amount)
        local p = pool(char, stat)
        if not (p and p.max) then return 0 end
        local before = p.current or 0
        p.current = math.max(1, before - (amount or 0))
        return before - p.current
    end
    -- Queue a status for a unit to open its next fight under (a barrier, haste, an empower). Applied by
    -- battle setup, so it never touches a live combat object here -- a refill/boon banked before the
    -- bell, exactly like the abilities' battleStart restores.
    ctx.grantBoon = ctx.grantBoon or function(char, id, opts)
        if char and id then ctx.boons[#ctx.boons + 1] = { char = char, id = id, opts = opts } end
    end
    return ctx
end

-- Fire `event` for every held relic whose def defines a hook for it. `ctx.state` is the run relic-state
-- (its held list + per-id scratch). Returns ctx (with ctx.boons filled) so a battleStart caller can drain
-- the queued opening boons.
function Relic.dispatch(event, ctx)
    ctx = ctxFor(ctx or {})
    local state = ctx.state
    if not state then return ctx end
    state.scratch = state.scratch or {}
    for _, id in ipairs(state.held or {}) do
        local def = Relic.defs[id]
        local hook = def and def[event]
        if hook then
            state.scratch[id] = state.scratch[id] or {}
            hook(def, state.scratch[id], ctx)
        end
    end
    return ctx
end

-- ---------------------------------------------------------------------------
-- Combat integration (read by battle setup)
-- ---------------------------------------------------------------------------

-- The trait ids every held combat-relic grants, to be attached to the party's units at battle setup
-- alongside their item traits (models/trait.lua). This is how "first strike crits" or "allies burn each
-- turn" reuses the whole reactive-trait system without a bespoke combat path. `scope` on the def picks
-- who wears it: "frontRow" limits it to the marching front line, anything else (default) is the whole
-- party -- battle setup honours it when it walks the units.
function Relic.grantedTraits(state)
    local out = {}
    for _, id in ipairs(state and state.held or {}) do
        local def = Relic.defs[id]
        for _, t in ipairs((def and def.traits) or {}) do
            out[#out + 1] = { trait = t, scope = def.scope or "party", relic = id }
        end
    end
    return out
end

-- Resolve every held combat-relic's traits to the ACTUAL party members that wear them this fight, as a
-- map { [char] = { traitId, ... } } keyed by char instance -- "party" scope to everyone, "frontRow" to
-- the line the player actually deployed forward, which the caller supplies (falling back to the whole
-- party, exactly as the opening boons resolve their front row). Built once the deployment phase commits
-- -- states/game.lua's resolveOpening -- and handed to states/battle.lua, which stamps each unit's
-- `relicTraits` off it by identity. `party` is the whole COMPANY, bench included: a party-scope relic is
-- worn by everyone who marched, and a benched member has to arrive already wearing it (Combat.rotate
-- carries the entry's relicTraits onto the unit it builds). Only `frontRow` scope narrows, to `front`.
function Relic.combatTraitsByChar(state, player, party, front)
    party = party or (player and player.party) or {}
    local out = {}
    for _, g in ipairs(Relic.grantedTraits(state)) do
        local targets = (g.scope == "frontRow") and frontRow(front, party) or party
        for _, c in ipairs(targets) do
            out[c] = out[c] or {}
            out[c][#out[c] + 1] = g.trait
        end
    end
    return out
end

-- Drain the opening-boons queue a battleStart dispatch built (Relic.dispatch(... ).boons), as a flat list
-- of { char, id, opts } for battle setup to stamp onto each named unit at spawn. A thin pass-through kept
-- here so callers have one name to reach for whether the boon came from a relic or an ability.
function Relic.openingBoons(dispatchCtx)
    return (dispatchCtx and dispatchCtx.boons) or {}
end

-- ---------------------------------------------------------------------------
-- Player-facing info (drives the run-relic UI strip + tooltips)
-- ---------------------------------------------------------------------------

-- The { name, blurb, tier, alignment, affinity, cost } a strip/tooltip needs for `id` (or a held entry's
-- def). Falls straight out of the blueprint; kept as one reader so the UI never touches def internals.
function Relic.info(id)
    local def = type(id) == "table" and id or Relic.defs[id]
    if not def then return nil end
    return {
        name = def.name or "Relic",
        blurb = def.blurb or "",
        tier = def.tier or "common",
        alignment = def.alignment or "virtue",
        affinity = def.affinity or "combat",
        cost = def.cost, -- a Vice's standing price, for the tooltip's warning line; nil for a Virtue
    }
end

-- A short banked-quantity for `id`'s scratch this run (given its bucket), or nil if nothing is pending --
-- the little counter a strip badge shows for a relic that accumulates toward a payoff. A relic declares
-- its own reader as def.banked(bucket) -> number|nil, so the model stays agnostic about what each counts.
function Relic.bankedCount(id, bucket)
    local def = Relic.defs[id]
    if not (def and def.banked and bucket) then return nil end
    local n = def.banked(bucket)
    return (n and n > 0) and n or nil
end

return Relic
