-- RELICS: the roguelike inner-loop content. Where a companion's OVERWORLD ABILITY (models/overworld_-
-- ability.lua) is keyed to WHO is in your party, a relic is FOUND on the expedition -- dropped by a
-- cache, bought off a merchant, bled for at a stone -- and carried only for THIS run. It is the thing
-- that snowballs: pick up a dozen across a descent's floors and the company you reach the bottom with is
-- not the company you left the hub with. The across-runs power (gear, prestige, roster) already persists
-- at the hub; relics are the WITHIN-run power the game was missing.
--
-- ONE SHELF. There is no Virtue and no Vice -- that axis was deleted, and this is the note that says why
-- so it does not grow back. A moral tier crossed with a rarity tier gave four combinations that each had
-- to mean something, and they did not: a common Virtue and a common Vice were the same size of effect
-- wearing different paint, which is how the shelf ended up with two byte-identical relics (the old Long
-- Watch and Reliquary Draught) that nobody could see were the same. A DOWNSIDE IS A PROPERTY, NOT A
-- CLASS: a relic that costs you something says so in `cost`, sits in the same pool as everything else,
-- and is never filtered on. Rarity is the only ladder, and it is also the colour (ui/relic_card.lua).
--
-- THE LADDER, and each rung is a different KIND of thing rather than a different size:
--   * COMMON    -- a gift. A flat always-on number, no strings. One relic per stat, plus the opening boons.
--   * UNCOMMON  -- a trade. A real gain at the price of a real loss (+3 damage, -3 defense).
--   * RARE      -- an inversion. A rule of the game rewritten (your health is pinned at 1).
--
-- EVERYTHING IS ALWAYS ON. The one property every relic on the shelf shares: it is felt on the board from
-- the first turn, with no condition to wait for and nothing to track. A reactive relic -- one that waits
-- for a would-be death, or a first kill, or a lucky roll -- is a relic the player cannot tell is working
-- across the ~30 party actions a tactics fight actually contains. That is also why NOTHING here rolls a
-- per-hit chance: Risk of Rain can price a 4% proc because it fires forty times a minute, and we cannot.
--
-- AND EVERYTHING STACKS. Relic.grant no longer refuses a duplicate; it increments a count, and every
-- magnitude resolves through Relic.magnitude as `base + (n-1) * step`. There is no `unique` flag and no
-- relic that wants one -- see THE RULE/MAGNITUDE SPLIT below, which is what let the last exception go.
--
-- This module is a REGISTRY + DISPATCHER, deliberately the twin of overworld_ability.lua:
--   * headless-safe (no love.graphics at require-time; RNG falls back to math.random)
--   * relics declare hooks in their DATA file (data/relics/<id>.lua). The overworld hooks fire on the
--     same four traversal events the abilities use -- "step", "encounterCleared", "battleStart",
--     "objectiveReached" -- so a relic and a companion perk compose without knowing about each other.
--   * a relic's hook gets (relic, bucket, ctx). `bucket` is its per-RUN scratch (auto-created, keyed by
--     the relic id), reset each run like the fog; `ctx` carries the run + bound, headless-safe helpers
--     (restore / grantBoon / addGold / notify / party / grid / cell / spoils), the same shape a trait's
--     ctx takes, so a data-file hook composes effects without reaching into any model directly.
--
-- FOUR WAYS A RELIC REACHES A FIGHT, in ascending order of how much they cost to author:
--   1. `bonus` / `maxBonus`  -- flat stats, folded onto every unit beside the meal in
--      Combat.applyUnitPassives. This is the whole common tier and half the uncommon one, and it inherits
--      the entire mitigation, breakdown and tooltip stack for free. A six-line data file with no hook.
--   2. `traits`              -- names an existing reflex (models/trait.lua), attached at battle setup
--      exactly as an item's traits are.
--   3. `rules`              -- the rare tier's inversions, read by combat setup once per fight.
--   4. a `battleStart` hook -- queues an opening boon (a barrier, haste) through ctx.grantBoon.
--
-- THE RULE/MAGNITUDE SPLIT, which is why nothing needs `unique`. A rare has two halves and they stack
-- differently. Its INVERSION is a rule: it fires once and does not repeat, because you cannot be more
-- unable to move or more pinned at one health -- so `rules` is read as a set, not scaled by count. Its
-- COMPENSATION is a magnitude, and magnitudes are what Relic.magnitude ladders. A second Rooted Oath does
-- not root you twice; it pays more range and more damage for the rooting you already took. The downside
-- is a one-time price and the upside is a ladder, which is also what makes a second copy the way a player
-- COMMITS to a build rather than a wasted draw.
--
-- PRECEDENCE, where two rules touch the same quantity. Three rares reach for the health pool -- the
-- Whetted Vow halves each maximum, the Yoked Company merges them into one bar, the Held Breath pins what
-- is left at 1 -- and a run can hold all three. Relic.RULE_ORDER fixes the order they resolve in
-- (maxima, then pooling, then the pin) so the last one applied is always the one whose text would read as
-- broken if it silently lost. tests/relic_spec.lua pins it.

local Player = require("models.player")

local Relic = {}

Relic.defs = require("models.registry").load("data/relics", "data.relics")

-- ---------------------------------------------------------------------------
-- The ladder
-- ---------------------------------------------------------------------------

-- Ordered cheapest-first. A def with no `tier` is a common, which is the right default for the rung
-- that is a plain number.
Relic.TIERS = { "common", "uncommon", "rare" }

-- HOW OFTEN EACH RUNG TURNS UP, as relative weight within a single draw. This is the "higher rarities
-- are a percentage chance to show up" rule, and it is the ONLY percentage in the relic system -- a drop
-- table is exactly where a probability belongs, and it is a different thing entirely from the per-hit
-- procs the combat side refuses.
--
-- 10 / 4 / 1 over a three-card slate deals roughly 2 commons and 1 uncommon on an average draw, with a
-- rare on about one card in six -- so a twelve-pickup run meets two or three of them. That is Hades'
-- number for a boon of the top rarity and it is the one worth landing on: rare enough that the run is
-- remembered by which one it found, common enough that a run is not decided by never seeing any.
Relic.TIER_WEIGHT = { common = 10, uncommon = 4, rare = 1 }

-- The order the rare tier's `rules` resolve in when a run holds several that touch the same quantity.
-- Read by combat setup (states/battle.lua) rather than enforced here: this module owns WHAT is held, the
-- battle owns what that does to a body. Anything not named here resolves after, in registry order, which
-- is safe because every other rule touches a quantity nothing else does.
Relic.RULE_ORDER = { "halveMaxHealth", "sharedPool", "pinHealth" }

function Relic.get(id) return Relic.defs[id] end

local function rnd(...)
    if love and love.math and love.math.random then return love.math.random(...) end
    return math.random(...)
end

-- ---------------------------------------------------------------------------
-- Stacking
-- ---------------------------------------------------------------------------

-- `base + (n-1) * step` for a relic held `n` times, which is the one arithmetic every magnitude on the
-- shelf goes through. `step` defaults to `base`, so a data file that writes only a base gets plain linear
-- stacking -- the right default for the flat-stat commons, which are most of the shelf.
--
-- n = 0 (not held) returns 0 rather than the base, so a caller can ask about any relic without first
-- checking whether it is carried.
function Relic.magnitude(n, base, step)
    n = n or 0
    if n <= 0 then return 0 end
    base = base or 0
    return base + (n - 1) * (step or base)
end

-- The figure a card prints at `n` copies. A ladder is USUALLY `{ base, step }` -- every gain and nearly
-- every price on this shelf climbs in a straight line -- but a def whose figure is a SHARE of something
-- the stack keeps shrinking (The Whetted Vow's health) does not, and stating it as the raw divisor
-- instead pushes the arithmetic onto the player. Such a def authors `function(n) -> number` in place of
-- the pair, and everything downstream reads the same way.
local function figureAt(scale, n)
    if type(scale) == "function" then return scale(n) end
    return Relic.magnitude(n, scale[1], scale[2])
end

-- ---------------------------------------------------------------------------
-- Drop pool
-- ---------------------------------------------------------------------------

-- Is `def` eligible to DROP in this context? Gated by minDay and an optional condition(ctx), the
-- same contract encounters use (models/encounter.lua), so the two selection systems read alike.
local function eligible(def, ctx)
    if def.minDay and (ctx.day or 1) < def.minDay then return false end
    if def.condition and not def.condition(ctx) then return false end
    return true
end

-- How much likelier a relic OF THIS CIRCLE is to turn up on this circle's floor.
--
-- The cheapest way to make the shuffle change how a run PLAYS rather than only what it looks like: a
-- Wrath floor keeps offering things that reward hitting, a Greed floor things that reward taking, and
-- two runs that drew their sins in a different order build differently even from the same shelf. Not
-- exclusive -- an off-circle relic still turns up, because a floor that could only ever offer one
-- flavour is a floor with no decision on it -- so this is a thumb on the scale and never a filter.
Relic.SIN_AFFINITY_BONUS = 4

local function weightOf(def, ctx)
    -- THE TIER IS THE WEIGHT, and a def's own `weight` is a multiplier on it rather than the whole
    -- story. Before, every relic authored its own absolute weight and the rarity badge was decoration;
    -- now the ladder does the work and `weight` is only for saying "this one, a little more often than
    -- its rung" -- or 0, which takes it off the rollable shelf entirely (Honed Edge is a rest reward,
    -- never a cache find).
    local w = def.weight
    if type(w) == "function" then w = w(ctx) end
    if w == nil then w = 1 end
    if w <= 0 then return 0 end
    w = w * (Relic.TIER_WEIGHT[def.tier or "common"] or 1)
    -- A relic that names a circle is weighted up on that circle's floor. `ctx.sin` is set only by a
    -- descent (states/game.lua reads it off the floor descriptor); the campaign passes none and every
    -- weight here is exactly what its rung says.
    if ctx and ctx.sin and def.sin == ctx.sin then
        w = w * Relic.SIN_AFFINITY_BONUS
    end
    return w
end

-- The relics eligible to drop for `ctx`, as { id, def, weight } entries (weight > 0). `ctx.tier` narrows
-- to one rung (the Weeping Stone sells a rung above the floor's roll). `ctx.exclude` (a held-state or
-- id->true set) drops what the run already holds -- OPT-IN now, and that inversion is the point: the
-- slate wants held relics IN the pool so a duplicate can be drawn and deepen what you carry.
function Relic.pool(ctx)
    ctx = ctx or {}
    local held = ctx.exclude and Relic._excludeSet(ctx.exclude) or {}
    local out = {}
    for id, def in pairs(Relic.defs) do
        if not held[id]
            and (not ctx.tier or def.tier == ctx.tier)
            and eligible(def, ctx) then
            local w = weightOf(def, ctx)
            if w > 0 then out[#out + 1] = { id = id, def = def, weight = w } end
        end
    end
    -- SORTED, because `pairs` over a registry is unspecified and two machines resolving the same run
    -- from the same seed have to draw the same relic or a descent stops replaying the same.
    table.sort(out, function(a, b) return a.id < b.id end)
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

-- Build a SLATE of up to `n` distinct relic ids for a pick-one-of-many offer (the Reliquary).
--
-- A PLAIN RARITY ROLL, and the composed slate that used to stand here is gone. It dealt one Vice against
-- two Virtues, which stopped meaning anything when the moral axis went; a later revision reserved one
-- card for a relic the run already held, so a duplicate was always on offer. Both were the same mistake
-- in different clothes -- deciding for the player what KIND of thing each card is. The weights already
-- say how often a rare should appear (Relic.TIER_WEIGHT); composing on top of them says it twice and
-- means the card you get is not the card the odds promised.
--
-- HELD RELICS STAY IN THE POOL. That is the whole of how stacking happens: three cards drawn off the
-- rung weights, and if one of them is something you carry, taking it deepens what you have. No reserved
-- slot, no guarantee -- the shelf is thirty-six deep and a twelve-pickup run will meet its own relics
-- often enough without being handed them.
--
-- Distinct within one slate (a card cannot appear twice on the same three), which is the only
-- composition left and is about legibility rather than odds. Returns fewer than `n` only if the whole
-- eligible pool is smaller than `n`, which the shipped shelf never is.
function Relic.slate(ctx, n)
    ctx = ctx or {}
    n = n or 3
    local taken, ids = {}, {}
    for i = 1, n do
        local sub = { exclude = taken }
        for k, v in pairs(ctx) do if k ~= "exclude" then sub[k] = v end end
        -- The caller's own exclusions (if any) still apply, on top of this slate's own distinctness.
        for id in pairs(Relic._excludeSet(ctx.exclude)) do sub.exclude[id] = true end
        local id = Relic.roll(Relic.pool(sub))
        if not id then break end
        taken[id] = true
        ids[#ids + 1] = id
    end
    return ids
end

-- ---------------------------------------------------------------------------
-- The run inventory (plain data, so it serialises into the run save beside abilityState)
-- ---------------------------------------------------------------------------

-- A fresh, empty relic-state for a run. `held` is the ordered list of DISTINCT relic ids the company
-- carries (the order they were first taken, which is the order the tray draws them); `counts` is how
-- many of each; `scratch` namespaces each relic's per-run bucket by id. Reset each run in
-- states/game.lua's enter, exactly like the fog and the ability scratch -- and carried between the
-- FLOORS of a descent, which is what makes a stack worth building.
function Relic.newState()
    return { held = {}, counts = {}, scratch = {} }
end

function Relic.has(state, id)
    return Relic.count(state, id) > 0
end

-- How many copies of `id` the run carries. The number every magnitude on the shelf is resolved against.
function Relic.count(state, id)
    if not (state and state.counts) then return 0 end
    return state.counts[id] or 0
end

-- Grant `id` to the run. A DUPLICATE IS THE POINT, not a refusal: a re-grant increments the count and
-- returns the def exactly as a first grant does, so no caller has to special-case "you already have
-- this". Returns the def and the NEW count, or nil for an unknown id.
function Relic.grant(state, id)
    if not (state and Relic.defs[id]) then return nil end
    state.held = state.held or {}
    state.counts = state.counts or {}
    state.scratch = state.scratch or {}
    local n = (state.counts[id] or 0) + 1
    if n == 1 then state.held[#state.held + 1] = id end
    state.counts[id] = n
    state.scratch[id] = state.scratch[id] or {}
    return Relic.defs[id], n
end

-- GIVE UP ONE COPY of `id`. The counterpart to grant, and the only removal the run has -- spent by the
-- Altar's trade (states/game.lua), which is what turns a relic with a downside from a permanent regret
-- into a debt that can be paid off.
--
-- Takes ONE copy, not the stack: a company that carries three Whetstone Tithes and trades one is down to
-- two, which is the only reading that makes sense of a shelf where depth is the point. The id leaves
-- `held` (and its scratch is dropped) only when the last copy goes, so the tray stops drawing it exactly
-- when the company stops carrying it.
--
-- Returns the new count, or nil if there was nothing to give.
function Relic.forget(state, id)
    local n = Relic.count(state, id)
    if n <= 0 then return nil end
    n = n - 1
    state.counts[id] = (n > 0) and n or nil
    if n == 0 then
        state.scratch[id] = nil
        for i, held in ipairs(state.held or {}) do
            if held == id then table.remove(state.held, i); break end
        end
    end
    return n
end

-- Every held relic as { id, def, count } in the order first taken.
function Relic.held(state)
    local out = {}
    for _, id in ipairs(state and state.held or {}) do
        local def = Relic.defs[id]
        if def then out[#out + 1] = { id = id, def = def, count = Relic.count(state, id) } end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- Combat integration: the flat-stat bags
-- ---------------------------------------------------------------------------

-- Fold every held relic's `bonus` into one { stat -> amount } bag, each scaled to how many copies are
-- held. This is what Combat.applyUnitPassives adds beside the grid's items and the company's meal, and
-- it is deliberately the same quantity: a relic's +2 defense has to be the same thing a coat's +2 is, or
-- the mitigation maths and the damage breakdown would each need a case of their own.
--
-- A def declares `bonus = { damage = 1 }` and, when a second copy is worth less (or more) than the
-- first, `bonusStep = { damage = 1 }`. Step defaults to base, which is plain linear stacking.
local function bag(state, field, stepField)
    local out = {}
    for _, entry in ipairs(Relic.held(state)) do
        for stat, base in pairs(entry.def[field] or {}) do
            local step = (entry.def[stepField] or {})[stat]
            out[stat] = (out[stat] or 0) + Relic.magnitude(entry.count, base, step)
        end
    end
    return out
end

function Relic.statBonus(state) return bag(state, "bonus", "bonusStep") end
function Relic.maxBonus(state) return bag(state, "maxBonus", "maxBonusStep") end
function Relic.resistBonus(state) return bag(state, "resist", "resistStep") end

-- The per-relic breakdown of the bonus to `stat`, as { label, value } rows named after the relic itself
-- -- so the damage-breakdown tooltip can point at "The Keen Edge" instead of a bare "Relics". Sums to
-- Relic.statBonus(state)[stat]. A relic held more than once names its count, because a row reading +3
-- against a relic whose card says +1 is a bug report waiting to happen.
function Relic.bonusBreakdown(state, stat)
    local out = {}
    for _, entry in ipairs(Relic.held(state)) do
        local base = (entry.def.bonus or {})[stat]
        if base then
            local step = (entry.def.bonusStep or {})[stat]
            local v = Relic.magnitude(entry.count, base, step)
            if v ~= 0 then
                local label = entry.def.name or entry.id
                if entry.count > 1 then label = label .. "  x" .. entry.count end
                out[#out + 1] = { label = label, value = v }
            end
        end
    end
    return out
end

-- Every stat's breakdown at once, as { [stat] = { {label, value}, ... } } -- what battle setup stamps
-- onto a unit beside the aggregated bag so Combat's damage-breakdown tooltip can name each relic without
-- reaching into a run. Built once per fight rather than per hover: the tooltip calls flatStat on every
-- frame the mouse is over a body, and walking the whole shelf there would be a per-frame allocation.
function Relic.bonusParts(state)
    local stats, out = {}, {}
    for _, entry in ipairs(Relic.held(state)) do
        for stat in pairs(entry.def.bonus or {}) do stats[stat] = true end
    end
    for stat in pairs(stats) do
        local rows = Relic.bonusBreakdown(state, stat)
        if #rows > 0 then out[stat] = rows end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- Combat integration: the rare tier's rules
-- ---------------------------------------------------------------------------

-- Every rule the held relics impose, as { [ruleName] = { relic = id, count = n, def = def } }.
--
-- A RULE FIRES ONCE, whatever the count -- that is the split this whole tier rests on. What the count
-- changes is the relic's MAGNITUDE, which the caller reads separately through Relic.magnitude. So a
-- second Rooted Oath appears here identically and pays a bigger number through its `bonus`.
--
-- Returned in Relic.RULE_ORDER for the rules named there (the three that reach for the health pool),
-- then the rest in registry-sorted order, so a battle applying them walks a stable, specified sequence.
function Relic.rules(state)
    local found, order = {}, {}
    for _, entry in ipairs(Relic.held(state)) do
        for name, value in pairs(entry.def.rules or {}) do
            if value ~= false and not found[name] then
                found[name] = { relic = entry.id, count = entry.count, def = entry.def, value = value }
                order[#order + 1] = name
            end
        end
    end
    local rank = {}
    for i, name in ipairs(Relic.RULE_ORDER) do rank[name] = i end
    table.sort(order, function(a, b)
        local ra, rb = rank[a] or math.huge, rank[b] or math.huge
        if ra ~= rb then return ra < rb end
        return a < b
    end)
    found.order = order
    return found
end

-- THE RULES, WITH THEIR MAGNITUDES ALREADY RESOLVED -- what combat actually consumes.
--
-- Relic.rules above answers "which inversions are in force and how deep"; this answers "what number
-- does each of them come to", which is the only question the battle has. Resolved ONCE at setup and
-- stamped on the units (as relicBonus.rules) and the combat, so nothing on a hot path -- a damage
-- preview, a stat read, a move overlay -- ever walks the shelf.
--
-- A rule that is a bare flag comes back `true`; a rule with a `ruleScale` comes back as its laddered
-- number. Absent rules are simply nil, so every consumer is one `if` against a table that is nil for
-- every enemy and for any fight fought carrying nothing.
--
-- `damageMultiplier` is the one that COMPOSES rather than replacing: two relics that both multiply the
-- company's damage (the Rooted Oath and the Unpaid Tithe) multiply together, because each is a separate
-- bargain the player made and taking both should pay for both. Every other rule is held by exactly one
-- relic on the shipped shelf, so first-wins (Relic.rules) is the whole story for them.
function Relic.resolvedRules(state)
    local out, mult = nil, nil
    for _, entry in ipairs(Relic.held(state)) do
        local def = entry.def
        for name, value in pairs(def.rules or {}) do
            if value ~= false then
                out = out or {}
                local scale = (def.ruleScale or {})[name]
                local resolved = scale and Relic.magnitude(entry.count, scale[1], scale[2]) or true
                if name == "damageMultiplier" then
                    mult = (mult or 1) * (type(resolved) == "number" and resolved or 1)
                elseif out[name] == nil then
                    out[name] = resolved
                end
            end
        end
    end
    if mult then out.damageMultiplier = mult end
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
--
-- `ctx.stacks` is how many copies of the relic being dispatched are held -- bound per relic in
-- Relic.dispatch, so a hook can ladder its own magnitude without being handed the whole state.
local function ctxFor(ctx)
    local party = ctx.party or (ctx.player and ctx.player.roster) or {}
    ctx.party = party
    ctx.boons = ctx.boons or {}

    -- THE UNPAID TITHE (a rare relic) gags every restore the company has: no camp, no larder, no
    -- post-fight heal. Enforced HERE, at the one helper every relic hook restores through, so the rule
    -- holds without each of those relics having to know the Tithe exists -- The Deep Larder and The Kept
    -- Vigil simply pay nothing and say nothing, which is what "recovers nothing" means.
    --
    -- Read off the run state rather than a unit, because this fires on the overworld where there are no
    -- units at all. The camp is gated separately, at its own button (states/game.lua's restHeal), since
    -- that one has to TELL the player why the offer is dead rather than silently healing zero.
    local noRecovery = ctx.state and Relic.resolvedRules(ctx.state)
    noRecovery = noRecovery and noRecovery.noRecovery
    ctx.restore = ctx.restore or function(char, stat, amount)
        if noRecovery then return 0 end
        return restore(char, stat, amount)
    end
    ctx.mostWounded = ctx.mostWounded or function() return mostWounded(party) end
    local supplied = ctx.frontRow
    ctx.frontRow = function() return frontRow(supplied, party) end
    ctx.rnd = ctx.rnd or rnd
    ctx.notify = ctx.notify or function() end
    ctx.say = function(msg) ctx.notify(msg) end
    ctx.addGold = ctx.addGold or function(amount)
        if ctx.player and amount and amount ~= 0 then Player.addGold(ctx.player, amount) end
    end
    -- Take `amount` off a pool as a relic's standing toll -- floored at 1, so a price wounds but never
    -- fells (a wipe should come from the fight, not from carrying a cursed coin). Returns what was
    -- actually taken. The counterpart to restore, for the half of the shelf that costs you something.
    ctx.drain = ctx.drain or function(char, stat, amount)
        local p = pool(char, stat)
        if not (p and p.max) then return 0 end
        local before = p.current or 0
        p.current = math.max(1, before - (amount or 0))
        return before - p.current
    end
    -- Queue a status for a unit to open its next fight under (a barrier, haste, an empower). Applied by
    -- battle setup, so it never touches a live combat object here.
    ctx.grantBoon = ctx.grantBoon or function(char, id, opts)
        if char and id then ctx.boons[#ctx.boons + 1] = { char = char, id = id, opts = opts } end
    end
    return ctx
end

-- Fire `event` for every held relic whose def defines a hook for it. `ctx.state` is the run relic-state.
-- Returns ctx (with ctx.boons filled) so a battleStart caller can drain the queued opening boons.
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
            -- How deep this relic is stacked, for a hook that ladders its own number. Bound per relic
            -- and restored after, so one hook cannot see another's count.
            ctx.stacks = Relic.count(state, id)
            ctx.mag = function(base, step) return Relic.magnitude(ctx.stacks, base, step) end
            hook(def, state.scratch[id], ctx)
        end
    end
    ctx.stacks, ctx.mag = nil, nil
    return ctx
end

-- ---------------------------------------------------------------------------
-- Combat integration: traits and opening boons
-- ---------------------------------------------------------------------------

-- The trait ids every held relic grants, to be attached to the party's units at battle setup alongside
-- their item traits (models/trait.lua). `scope` on the def picks who wears it: "frontRow" limits it to
-- the deployed front line, anything else (default) is the whole company.
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

-- Resolve every held relic's traits to the ACTUAL party members that wear them this fight, as a map
-- { [char] = { traitId, ... } } keyed by char instance -- "party" scope to everyone, "frontRow" to the
-- line the player actually deployed forward, which the caller supplies. Built once the deployment phase
-- commits (states/game.lua's resolveOpening) and handed to states/battle.lua, which stamps each unit's
-- `relicTraits` off it by identity. `party` is the whole COMPANY, bench included.
function Relic.combatTraitsByChar(state, player, party, front)
    party = party or (player and player.roster) or {}
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

-- Drain the opening-boons queue a battleStart dispatch built, as a flat list of { char, id, opts } for
-- battle setup to stamp onto each named unit at spawn.
function Relic.openingBoons(dispatchCtx)
    return (dispatchCtx and dispatchCtx.boons) or {}
end

-- ---------------------------------------------------------------------------
-- Player-facing info (drives the relic tray + tooltips)
-- ---------------------------------------------------------------------------

-- The { name, blurb, tier, cost, mark } a tray chip or tooltip needs for `id` (or a held entry's def).
-- Falls straight out of the blueprint; kept as one reader so the UI never touches def internals.
function Relic.info(id)
    local def = type(id) == "table" and id or Relic.defs[id]
    if not def then return nil end
    return {
        name = def.name or "Relic",
        blurb = def.blurb or "",
        tier = def.tier or "common",
        cost = def.cost, -- a standing price, for the tooltip's warning line; nil where there is none
        mark = def.mark, -- one or two letters the tray draws on the gem until icon art lands
    }
end

-- The line a tooltip prints for a relic held `n` times: its blurb with every `%d` magnitude resolved at
-- the CURRENT stack rather than the authored base. A def declares `scale = { base, step }` beside a
-- blurb containing one `%d`; without it the blurb is returned as written.
--
-- Reads at the current stack on purpose. A tray chip that says "+1 damage" over a relic held three times
-- is the same failure as a preview that promises a payout the beat never pays -- the number in front of
-- the player has to be the number the fight uses.
function Relic.blurbAt(id, n)
    local def = type(id) == "table" and id or Relic.defs[id]
    if not def then return "" end
    local blurb = def.blurb or ""
    local s = def.scale
    if not s then return blurb end
    -- A RELIC NOBODY HOLDS YET STILL READS AS A NUMBER. n = 0/nil is an OFFER surface -- the Merchant's
    -- shelf, a cache slate -- and the only honest reading there is what one copy does. Returning the
    -- authored string on a zero stack put a literal "%d" in front of the player, which is worse than
    -- vague: the one thing every card on this shelf promises is that its figures are figures.
    n = (n and n > 0) and n or 1
    local ok, out = pcall(function() return string.format(blurb, figureAt(s, n)) end)
    return ok and out or blurb
end

-- WHAT A RELIC COSTS IN GOLD, on the Merchant's shelf and at the Altar.
--
-- Priced off the RUNG rather than off the relic, and that is the whole of the model: rarity is already
-- the ladder that says how good a thing is (see the header), so a second ladder saying how much it costs
-- would be the same statement made twice and free to drift. One number per rung, scaled by depth --
-- a floor-eight purse is not a floor-one purse, and a price that never moved would be a real decision
-- for two floors and a rounding error for six.
--
-- Sized against what a floor actually pays. A cleared fight is worth roughly 20-30 gold (models/
-- spoils.lua) and a floor holds eight or so, so a common at ~60 is two or three fights, a rare at ~200 is
-- most of a floor's takings. That is the intended shape: a common is an impulse, a rare is the reason
-- you did not buy anything else.
Relic.PRICE = { common = 45, uncommon = 100, rare = 190 }

-- How much the price climbs per floor, as a share of the base. 8% compounding-free: floor one pays the
-- base, floor eight pays about one and a half times it, which tracks a purse that grows with depth
-- without ever making the shallow floors the only place worth shopping.
Relic.PRICE_DEPTH = 0.08

function Relic.price(id, depth)
    local def = type(id) == "table" and id or Relic.defs[id]
    if not def then return 0 end
    local base = Relic.PRICE[def.tier or "common"] or Relic.PRICE.common
    return math.floor(base * (1 + Relic.PRICE_DEPTH * math.max(0, (depth or 1) - 1)))
end

-- THE PRICE LINE, resolved at the current stack -- the exact twin of Relic.blurbAt, and it exists for
-- the same reason.
--
-- EVERY NUMBER ON A CARD IS A NUMBER, and no relic says "less" or "more". A player deciding whether to
-- take The Keen Edge is deciding whether three damage is worth three defense; "the company fights with
-- less defense" asks them to take that on faith, and there is no way to find out short of arithmetic on
-- a stat screen. Worse, it is the half of a TRADE the whole uncommon rung is built on -- a rung whose
-- prices are unreadable is a rung with no decisions on it.
--
-- And it has to LADDER, which is why this is a function rather than a static string. The Keen Edge costs
-- 3 defense at one copy and 5 at two; a fixed "-3 defense" would be a lie the moment a second is taken,
-- and it is precisely the lie the stack-aware blurb was written to prevent on the other half of the card.
--
-- A def declares `costScale = { base, step }` (or a `function(n)`, for a price that does not climb in a
-- straight line -- see figureAt) beside a `cost` containing one `%d`; without it the line is returned as
-- authored (for the prices that genuinely do not move -- a rule fires once).
function Relic.costAt(id, n)
    local def = type(id) == "table" and id or Relic.defs[id]
    if not def or not def.cost then return nil end
    local s = def.costScale
    if not s then return def.cost end
    n = (n and n > 0) and n or 1 -- an unheld relic quotes the price of its first copy, never a raw "%d"
    local ok, out = pcall(function() return string.format(def.cost, figureAt(s, n)) end)
    return ok and out or def.cost
end

-- A short banked-quantity for `id`'s scratch this run (given its bucket), or nil if nothing is pending.
-- A relic declares its own reader as def.banked(bucket) -> number|nil.
function Relic.bankedCount(id, bucket)
    local def = Relic.defs[id]
    if not (def and def.banked and bucket) then return nil end
    local n = def.banked(bucket)
    return (n and n > 0) and n or nil
end

return Relic
