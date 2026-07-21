-- Status effects: timed effects applied to a unit in combat, measured in *ticks* (the
-- initiative reduced when a new turn triggers -- i.e. the amount models/combat.lua's rebase
-- subtracts and folds into combat.clock). Pure logic (no love.graphics), so it loads under
-- the headless tests, mirroring models/combat.lua.
--
-- Blueprints live in data/status/<id>.lua and expose optional hook functions the combat
-- model calls at the right moments:
--   * onApply(ctx)        -- when the status is first applied / re-applied (stun bumps init)
--   * onExpire(ctx)       -- when its remaining ticks hit 0
--   * onTurnStart(ctx)    -- at the top of the affected unit's turn. For what is genuinely scoped to a
--                            TURN -- Defending and Invisible self-expiring at their owner's next one.
--                            A recurring effect does NOT belong here: see onTick.
--   * onTurnEnd(ctx)      -- as the affected unit's turn ends
--   * onTick(ctx)         -- every rebase, with ctx.elapsed = the ticks that just passed. The hook for
--                            a recurring effect (Burn, Poison, Regeneration): duration is measured in
--                            ticks, so an effect paid out per TURN is wrong twice over -- it can expire
--                            before a normal unit's next turn ever arrives and never fire at all, and
--                            it charges a slow unit no more than a fast one for the same elapsed time.
--                            Quote `magnitude` per turn and spread it with ctx.accrue.
--
-- and declare, among others:
--   * lingers = true      -- the status STAYS when the bearer leaves the zone that granted it (Burn,
--                            Poison, Wet). Without it a zone-granted status is ZONE-BOUND: it lasts
--                            exactly as long as the bearer stands in a live zone that grants it, and
--                            ends the instant it leaves or the zone dies (Regeneration, Mired,
--                            Inspiration). Only ever consulted for a status a zone granted -- one from
--                            a spell or a potion has no zone to leave and simply runs its duration.
--                            See models/hazard.lua, which owns the whole rule.
--   * onEnterTile(ctx)    -- the unit arrived on a tile by ground movement -- walked, shoved, or
--                            dragged, but never blinked or swapped (e.g. bleed damage)
--   * blocksMove = true   -- the unit cannot move on its turn (root)
--   * turnEndMoveCost(ctx)-> a move cost the unit pays at end of turn even if it stayed put
--                            (root: as if it had moved max spaces)
--
-- `ctx` carries { combat, unit, status, magnitude, moveBudget } plus bound, headless-safe
-- helpers (damage / applyStatus / unitsNear) so a data-file hook composes effects without
-- requiring this module or models/combat.lua directly. Combat helpers are pulled through a
-- LAZY require so there is no load-time require cycle (combat.lua requires this module).

local Registry = require("models.registry")

local Status = {}

Status.defs = Registry.load("data/status", "data.status")

-- How many ticks one turn is worth, for converting a def's readable PER-TURN magnitude into the
-- amount a single tick actually lands (see ctx.accrue). Mirrors Combat.DEFAULT_SPEED -- the cost of a
-- typical action, and so the rough length of a turn -- but is stated here rather than required, since
-- combat.lua requires this module and the dependency only runs one way.
--
-- It is a tuning yardstick, not a rule: nothing forces a turn to cost exactly this. A slow unit whose
-- turns are further apart genuinely takes more Burn between them, which is the point of pricing these
-- effects on the clock instead of on turns.
Status.TICKS_PER_TURN = 5

-- Build the effect context handed to a status def's hooks. Combat is required lazily
-- (at call time, not load time) so combat.lua -> status.lua stays a one-way dependency.
local function ctxFor(combat, unit, status)
    local Combat = require("models.combat")
    local ctx
    ctx = {
        combat = combat,
        unit = unit,
        status = status,
        magnitude = status.magnitude,
        moveBudget = Combat.moveBudget(unit),
        -- Convert a PER-TURN magnitude into the whole units to apply on THIS tick, banking the
        -- remainder on the status instance. Only meaningful from an `onTick` hook, which sets
        -- ctx.elapsed; elsewhere there are no elapsed ticks and it yields 0.
        --
        -- Defs keep quoting the readable per-turn number a designer tuned, while the effect lands
        -- smoothly across the clock. The banking is what makes that honest: a rebase can elapse a
        -- FRACTION of a tick, and Combat.dealFlatDamage floors a hit at 1, so spending
        -- `magnitude * elapsed` directly would round every sliver up to a whole point and sear a unit
        -- far harder than its magnitude claims. Carrying the fraction spends it only once a full point
        -- has really accrued, so the damage over a stretch of clock matches the rate no matter how
        -- that stretch is chopped into rebases.
        accrue = function(perTurn)
            local rate = (perTurn or 0) / Status.TICKS_PER_TURN
            status.debt = (status.debt or 0) + rate * (ctx.elapsed or 0)
            local whole = math.floor(status.debt)
            status.debt = status.debt - whole
            return whole
        end,
        -- `opts` reaches Combat.dealFlatDamage as authored -- notably `{ raw = true }`, which skips
        -- armor and tag resists the way a Penetrating Strike does. A status needs it because a
        -- lingering effect is not a blow being blocked: defense stats (6-10) dwarf any sane per-tick
        -- magnitude, so a mitigated tick floors at 1 and its magnitude stops meaning anything. Bleed
        -- uses it -- a breastplate turns a blade, but it does nothing about a wound already open.
        damage = function(tgt, amount, tags, opts)
            if not tgt then return 0 end
            return Combat.dealFlatDamage(combat, tgt, amount, tags, status.name or status.id, nil, opts)
        end,
        heal = function(tgt, amount)
            if not tgt then return 0 end
            return Combat.applyHeal(combat, tgt, amount)
        end,
        applyStatus = function(tgt, id, opts)
            if not tgt then return nil end
            return Status.apply(combat, tgt, id, opts)
        end,
        unitsNear = function(x, y, radius) return Combat.unitsNear(combat, x, y, radius) end,
        -- Write a line to the combat log. What a status uses to narrate something the player would
        -- otherwise have to infer from the numbers -- a sleeper being jolted awake by a blow, and the
        -- initiative that hands back with it. Mirrors the trait ctx's helper of the same name.
        log = function(kind, text) return Combat.logEvent(combat, kind, text) end,
        -- The living unit on a tile, or nil. What a hook that reads the board around its bearer needs.
        unitAt = function(x, y) return Combat.unitAt(combat, x, y) end,
        -- End this status now (e.g. Defending self-expiring at the owner's next turn start).
        expire = function() Status.remove(combat, unit, status.id) end,
        -- Put the bearer into another character's body / back into its own (models/transform.lua).
        -- A shape-granting status (Polymorph, Wild Shape) is the TIMER that owns its shape, exactly as
        -- Charm's status owns the side-flip it reverts: onApply wears it, onExpire takes it off. Since
        -- Status.remove and Status.cleanse both fire onExpire on EVERY removal path, a shape ends the
        -- same way whether it timed out, was Cured, or was dispelled -- there is no path that can
        -- strand a knight as a pig. Pulled lazily, as the combat helpers above are.
        transform = function(charId, opts)
            return require("models.transform").apply(combat, unit, charId, opts)
        end,
        revert = function()
            return require("models.transform").revert(combat, unit)
        end,
    }
    return ctx
end

-- ---------------------------------------------------------------------------
-- Status resistance. A status def opts in by declaring `resistible = "magical"|"physical"`, naming
-- the SCHOOL it arrives on; everything else lands unresisted exactly as before.
--
-- Resistance is DETERMINISTIC and it buys DURATION, never a coin flip. Nothing here rolls: the same
-- spell on the same target always produces the same number of ticks, so a player can read the board
-- and know what a cast will do. That is deliberate -- a hard-control status that lands "usually" is a
-- status whose counterplay is praying, and the one place this game already rolls (Charm) it rolls to
-- reward something the player did first (softening the victim).
--
-- Two levers cut the duration, and they multiply:
--
--   * The WARD -- how proof this body is against that school right now:
--         R = magicDefense (magical) or defense (physical), + any `statusResist` the grid grants
--         duration is scaled by RESIST_SOFT / (RESIST_SOFT + R)
--     A softcap curve rather than a subtraction, so magic defense never reaches literal immunity on
--     its own and never stops being worth another point. (Damage mitigation subtracts flatly instead;
--     it can afford to, because it floors at 1 and a 1-damage hit is still a hit. A duration that
--     floors at 1 tick would make every ward a rounding error.)
--
--   * DIMINISHING RETURNS -- how many times this exact status has already landed on this body THIS
--     BATTLE: the nth application is halved n times (full, half, quarter, ...).
--     This is the part that answers "being turned into a pig forever is not a game". However badly a
--     target loses the first exchange, the same spell buys the caster less every time, and it takes a
--     bounded number of casts before it buys nothing at all.
--
-- Below a single tick the status DOES NOT LAND -- a duration of 0 is not a status, it is a wasted
-- cast. That is the hard ceiling the DR curve drives every repeat toward, and it is reached by
-- arithmetic rather than by an `immune` flag anyone has to remember to set.
-- ---------------------------------------------------------------------------

-- The half-duration point of the ward curve: a target whose resist rating equals this takes a status
-- for half its authored length. Tuned against the mid-game defensive stats (magicDefense 6-12), so a
-- bare body resists a little and a warded one resists a lot without either ever being untouchable.
Status.RESIST_SOFT = 12

-- Which defensive stat wards which school. A status arriving on neither is not resistible at all.
Status.RESIST_STAT = { magical = "magicDefense", physical = "defense" }

-- `unit`'s resist rating against `school`: the matching defense stat plus any flat `statusResist` the
-- grid grants. Both are read through Combat.flatStat, so armor bonuses and stat-moving statuses fold
-- in for free -- which is what lets the Skeptic's Harness ward its wearer with an ordinary
-- `bonus = { statusResist = N }` and no plumbing of its own.
function Status.resistRating(unit, school)
    local Combat = require("models.combat")
    local stat = Status.RESIST_STAT[school]
    local ward = stat and Combat.flatStat(unit, stat) or 0
    return ward + Combat.flatStat(unit, "statusResist")
end

-- How many times status `id` has been applied to `unit` this battle -- including the applications that
-- were shrugged off entirely. A refusal still teaches the body the shape of the spell, so spamming a
-- status a target is already immune to can never reset its immunity.
function Status.timesAfflicted(unit, id)
    return (unit._afflicted and unit._afflicted[id]) or 0
end

-- The ticks status `id` ACTUALLY lasts on `unit`, given its authored `duration` (see the contract
-- above). Returns `duration` untouched for a status that isn't resistible. A result below 1 means the
-- status does not land at all. Pure -- it counts nothing and spends nothing -- so a tooltip can quote
-- the real number a cast would buy before the player commits to it.
function Status.resistedDuration(unit, id, duration)
    local def = Status.defs[id]
    local school = def and def.resistible
    if not school or not duration or duration <= 0 then return duration end
    local rating = Status.resistRating(unit, school)
    local ward = Status.RESIST_SOFT / (Status.RESIST_SOFT + math.max(0, rating))
    local dr = 0.5 ^ Status.timesAfflicted(unit, id)
    return math.floor(duration * ward * dr + 0.5)
end

-- The ticks a fresh application of status `id` (with `opts`) would ADD to `unit`'s initiative -- the
-- shove DOWN the turn order a hard-control status lands (Stun, Freeze, Sleep). Positive = a later turn.
-- 0 for a status that doesn't touch initiative, or one so resisted it wouldn't land at all. Pure: it
-- counts nothing and spends nothing, so the timeline PREVIEW (states/battle.lua) can float a ghost of
-- the delayed target's next turn WITHOUT running the effect, reading the same number the live shove
-- lands by.
--
-- A def opts in with `shovesInitiative`, naming the field the shove reads: "magnitude" (Stun/Freeze --
-- a fixed delay, tunable per cast via opts) or "duration" (Sleep, whose shove IS its resisted remaining
-- -- see status_sleep.lua's "THE ONE NUMBER"). Keep this agreeing with the def's own onApply: the two
-- are the preview and the live halves of one delay.
function Status.initiativeShove(unit, id, opts)
    opts = opts or {}
    local def = Status.defs[id]
    local src = def and def.shovesInitiative
    if not src then return 0 end
    if src == "duration" then
        -- Sleep: the shove is exactly the ticks the ward and diminishing returns let it buy -- below a
        -- single tick it doesn't land, and shoves nothing (mirrors the < 1 refusal in Status.apply).
        local effective = Status.resistedDuration(unit, id, opts.duration or def.duration or 0)
        return (effective and effective >= 1) and effective or 0
    end
    -- "magnitude": a fixed delay, the opts value winning (Jolt/Thunder Storm tune the stun size) over
    -- the def's default. Stun/Freeze aren't resistible, so this is the whole shove.
    return opts.magnitude or def.magnitude or 0
end

-- Build a fresh status instance from a blueprint id. `opts` may override duration/magnitude.
function Status.instantiate(id, opts)
    opts = opts or {}
    local def = Status.defs[id]
    assert(def, "unknown status id: " .. tostring(id))
    return {
        id = id,
        name = def.name,
        remaining = opts.duration or def.duration or 0,
        magnitude = opts.magnitude or def.magnitude,
        -- The ZONE that granted this status, if any (e.g. "hazard_heal") -- stamped by the zone itself
        -- (models/hazard.lua), never by hand, and only onto a status that does not declare `lingers`.
        -- Its presence is what makes this instance zone-bound: it never ages (see Status.tick), and it
        -- lasts exactly as long as a live zone of this id sits under its bearer, ending the beat
        -- Hazard.reap finds none. nil for a status applied by anything else (a spell, a potion), which
        -- has no ground to leave and simply counts down.
        source = opts.source,
        -- Fractional carry for ctx.accrue: the part of a per-turn magnitude that has built up but not
        -- yet added to a whole point. Set lazily on first use.
        debt = nil,
        def = def,
    }
end

-- The active status of `id` on `unit`, or nil.
function Status.get(unit, id)
    for _, s in ipairs(unit.statuses or {}) do
        if s.id == id then return s end
    end
    return nil
end

function Status.has(unit, id)
    return Status.get(unit, id) ~= nil
end

-- Remove status `id` from `unit` (no-op if absent), firing the def's onExpire teardown as it leaves.
-- A status that unwinds unit state on its way out (Charm restoring the side it flipped) therefore
-- reverts on EVERY removal path -- a Cure, a barrier consumed, a self-expire -- not only a natural
-- countdown. The instance is pulled from the list BEFORE onExpire runs, so a hook that itself calls
-- remove/expire for the same id can't double-fire. Needs `combat` to build the hook's context.
function Status.remove(combat, unit, id)
    local list = unit.statuses
    if not list then return end
    for i = #list, 1, -1 do
        if list[i].id == id then
            local s = table.remove(list, i)
            if s.def.onExpire then s.def.onExpire(ctxFor(combat, unit, s)) end
        end
    end
end

-- Strip every DEBUFF from `unit` (a status whose def sets `debuff = true`: Burn, Wet, Stun, Root,
-- Silenced, Frozen, Mired). Buffs (Regeneration, Aegis, a barrier) are left untouched. Returns the
-- number removed. Backs Cure (data/items/ability/ability_cure.lua) through Combat.cleanse; an aura
-- debuff simply re-applies next entry if the unit is still standing in what caused it.
function Status.cleanse(combat, unit)
    local list = unit.statuses
    if not list then return 0 end
    local removed = 0
    for i = #list, 1, -1 do
        if list[i].def.debuff then
            local s = table.remove(list, i)
            removed = removed + 1
            -- Fire the teardown so a cleansed debuff unwinds its unit-state (Charm reverts the side it
            -- flipped) exactly as a natural expiry would.
            if s.def.onExpire then s.def.onExpire(ctxFor(combat, unit, s)) end
        end
    end
    return removed
end

-- Sum the flat stat bonus for `name` contributed by every active status on `unit` (0 if none). Two
-- sources add in: a static `statBonus[name]` on the def (Aegis's fixed +defense/+magicDefense), and
-- the per-instance `magnitude` when the def routes it to this stat via `magnitudeStat = name`
-- (Defending's +defense, whose size the granting shield tunes). Folded into combat's flatStat.
function Status.statBonus(unit, name)
    local total = 0
    for _, s in ipairs(unit.statuses or {}) do
        local bonus = s.def.statBonus
        if bonus and bonus[name] then total = total + bonus[name] end
        if s.def.magnitudeStat == name and s.magnitude then total = total + s.magnitude end
    end
    return total
end

-- Reduction to `unit`'s ability RANGE, summed from every active status's `rangeMalus` (0 if none).
-- Range is per-ability, not a flat stat, so a range-cutting status (Blind) can't ride statBonus the
-- way a movement cut (Cripple) does; Combat.abilityRange subtracts this and floors the reach at 1, so
-- a blinded unit can still strike an adjacent foe. The single reader keeps targeting, the range
-- highlights and the enemy AI's planning all honouring the shortened sight at once.
function Status.rangeMalus(unit)
    local total = 0
    for _, s in ipairs(unit.statuses or {}) do
        if s.def.rangeMalus then total = total + s.def.rangeMalus end
    end
    return total
end

-- Extra pre-mitigation damage `unit` takes from a hit carrying `tags`, summed from every active
-- status's `vulnerable = { tag = N }` bag (0 if none). Folded into Combat.mitigatedDamage so a
-- vulnerability lands on both real hits and the damage preview alike (e.g. Wet -> +lightning damage).
function Status.vulnerability(unit, tags)
    local total = 0
    for _, s in ipairs(unit.statuses or {}) do
        local vuln = s.def.vulnerable
        if vuln then
            for _, t in ipairs(tags or {}) do total = total + (vuln[t] or 0) end
        end
    end
    return total
end

-- Multiplier applied to every ability cost the unit pays, from each active status's
-- `costMultiplier` (1 when none). Multiplicative so two haste-like buffs compound rather than
-- cancel. Folded into Combat.abilityCost, the single source of truth for what an ability costs.
function Status.costMultiplier(unit)
    local m = 1
    for _, s in ipairs(unit.statuses or {}) do
        if s.def.costMultiplier then m = m * s.def.costMultiplier end
    end
    return m
end

-- Can the opposing side pick this unit as a target? False while any active status sets
-- `untargetable` (Invisible). Read by Combat.abilityTargets and the enemy AI's target scans;
-- friendly and self casts ignore it, so an ally can still heal an invisible friend.
function Status.untargetable(unit)
    for _, s in ipairs(unit.statuses or {}) do
        if s.def.untargetable then return true end
    end
    return false
end

-- The barrier status on `unit` that would negate an incoming hit of the given school (`magical`
-- true -> a magical barrier, false -> a physical one), or nil. A barrier def carries
-- `negates = "physical"|"magical"`; the first matching one is returned so Combat.dealFlatDamage can
-- consume it and the damage preview can read the negation. Mirrors Status.untargetable in shape --
-- a single flag scanned across the unit's active statuses.
function Status.barrierAgainst(unit, magical)
    local want = magical and "magical" or "physical"
    for _, s in ipairs(unit.statuses or {}) do
        if s.def.negates == want then return s end
    end
    return nil
end

-- Every active ILLUSION on `unit` (a status whose def sets `illusion = true`), as a list -- empty when
-- there are none, and for a nil unit. What Combat.dispel tears down: an illusion is a LIE TOLD ABOUT A
-- BODY, and anything that lifts illusions should lift all of them rather than a list of ids someone has
-- to remember to extend.
--
-- Two kinds carry the flag today and they are the same kind on inspection: Invisible (a body that is
-- there and says it isn't) and the shapes -- Polymorph, Wild Shape (a body that is one thing and says
-- it's another). Snapshotted into a list rather than removed in place, so the caller can strip them
-- without mutating a table it is walking.
--
-- Note what this deliberately does NOT make dispellable: a barrier, a mirror, Aegis, Regeneration. Those
-- are real things done to a real body -- warding is not deceit -- and a spell that swept them away too
-- would be a dispel-magic, which is a different (and much broader) card than the one this game has.
function Status.illusionsOn(unit)
    local out = {}
    for _, s in ipairs((unit and unit.statuses) or {}) do
        if s.def.illusion then out[#out + 1] = s end
    end
    return out
end

-- The mirror status on `unit` that would turn a single-target hit of the given school back at whoever
-- threw it (`magical` true -> Reflect Magic, false -> Reflect Steel), or nil. Mirrors
-- Status.barrierAgainst exactly in shape -- a def carries `reflects = "physical"|"magical"` and the
-- first match wins -- but not in economics: a barrier is a CHARGE that a blow spends, while a mirror is
-- a WINDOW that answers every single-target blow of its school for as long as it lasts. That is why a
-- mirror is only ever short, and only ever single-target.
function Status.reflectorAgainst(unit, magical)
    local want = magical and "magical" or "physical"
    for _, s in ipairs(unit.statuses or {}) do
        if s.def.reflects == want then return s end
    end
    return nil
end

-- Spend ONE hit from `barrier` (whatever Status.barrierAgainst just returned), removing the ward once
-- its last hit is gone. A barrier's `magnitude` is the number of blows it can swallow -- 1 for the
-- base ward, more once the spell granting it is forged up (data/items/ability/ability_*_barrier.lua
-- author `hits` per level) -- so an upgrade buys COVERAGE rather than a bigger number, which is the
-- only axis a thing that negates hits outright has to grow along.
--
-- The single writer for spending a ward, so the hit that consumes the last charge and the hit that
-- merely dents a stack take the same path. Returns the hits left standing.
function Status.consumeBarrier(combat, unit, barrier)
    barrier.magnitude = (barrier.magnitude or 1) - 1
    if barrier.magnitude <= 0 then Status.remove(combat, unit, barrier.id) end
    return math.max(0, barrier.magnitude)
end

-- Does any active status keep this unit on its feet through a blow that would kill it? True while
-- any active status sets `preventsDeath` (Fury's berserk window). Read by Combat.dealFlatDamage,
-- which floors the survivor at 1 HP instead of dropping it. Mirrors Status.silenced in shape.
function Status.preventsDeath(unit)
    for _, s in ipairs(unit.statuses or {}) do
        if s.def.preventsDeath then return true end
    end
    return false
end

-- Does any active status make this unit's GROUND carry `tag`? A status may declare `tileTags`
-- (Wet -> "conductable"): standing there, its bearer makes the tile answer to that tag exactly as
-- water terrain or a Rain cloud on the same cell would. Read by Combat.tileHasTag, which asks all
-- three sources at once -- so a soaked knight and a river conduct the same bolt.
function Status.hasTileTag(unit, tag)
    for _, s in ipairs(unit.statuses or {}) do
        for _, t in ipairs(s.def.tileTags or {}) do
            if t == tag then return true end
        end
    end
    return false
end

-- Is this unit silenced -- unable to spend mana on an ability? True while any active status sets
-- `silencesMana`. Read by Combat.itemBlockReason, the single gate for a refused mana cast.
function Status.silenced(unit)
    for _, s in ipairs(unit.statuses or {}) do
        if s.def.silencesMana then return true end
    end
    return false
end

-- Is this unit cut off from magic entirely -- unable to work ANY magic, mana-priced or not? True while
-- any active status sets `deniesMagic` (Magic Denied, worn by the Skeptic's Harness and inflictable by
-- anything else that wants it). Read by Combat.itemBlockReason, the single gate for a refused cast.
--
-- Mirrors Status.silenced in shape but not in reach, and the difference is the whole reason both exist:
-- Silence gags the INCANTATION, so it refuses an ability paid for in mana and nothing else -- a
-- silenced mage can still swing an enchanted blade. Denial refuses the CRAFT, so it also refuses
-- anything tagged `magical` however it is paid for (see Combat.isMagicItem). Silence is an affliction
-- that wears off; denial is a position that doesn't.
function Status.deniesMagic(unit)
    for _, s in ipairs(unit.statuses or {}) do
        if s.def.deniesMagic then return true end
    end
    return false
end

-- Is this unit disarmed -- unable to use a crafted weapon? True while any active status sets
-- `disablesWeapon`. Read by Combat.itemBlockReason, the single gate for a refused weapon, exactly as
-- Status.silenced gates a refused mana cast. The bare `unarmed` fallback is exempt there, so a
-- disarmed unit can still punch.
function Status.disarmed(unit)
    for _, s in ipairs(unit.statuses or {}) do
        if s.def.disablesWeapon then return true end
    end
    return false
end

-- Is this unit's reflexes shut down -- unable to REACT to anything? True while any active status sets
-- `disablesReactions` (the hard-control statuses: Stun, Frozen, and any future Sleep). Read by
-- models/trait.lua to suppress a disabled unit's triggered reactions -- counters, thorns, a dodge, a
-- smoke-blink -- so a stunned or frozen fighter takes the blow it would normally answer. Mirrors
-- Status.silenced / Status.disarmed in shape: a single flag scanned across the unit's active statuses.
function Status.disablesReactions(unit)
    for _, s in ipairs(unit.statuses or {}) do
        if s.def.disablesReactions then return true end
    end
    return false
end

-- Apply status `id` to `unit`. One instance per id: re-applying refreshes the remaining
-- duration to the longer of old/new and re-runs onApply (so re-stunning bumps again). Runs
-- the def's onApply hook. Returns the (possibly refreshed) status instance.
function Status.apply(combat, unit, id, opts)
    opts = opts or {}
    local def = Status.defs[id]
    assert(def, "unknown status id: " .. tostring(id))
    unit.statuses = unit.statuses or {}

    -- A resistible status buys only the ticks this body's ward and its own history let it (see the
    -- resistance contract above). Copied rather than mutated: `opts` is frequently a table owned by an
    -- item blueprint (an aura's `status.opts`, passed straight through), and writing the shortened
    -- duration into it would quietly re-author the item for the rest of the run.
    if def.resistible then
        local wanted = opts.duration or def.duration or 0
        local effective = Status.resistedDuration(unit, id, wanted)
        -- Counted BEFORE the refusal below, so an application that lands nothing still deepens the
        -- diminishing returns -- you cannot reset a target's immunity by casting into it.
        unit._afflicted = unit._afflicted or {}
        unit._afflicted[id] = (unit._afflicted[id] or 0) + 1
        if effective < 1 then
            if combat and not def.hideLog then
                local Combat = require("models.combat")
                Combat.logEvent(combat, "status", string.format("%s shrugs off %s.",
                    (unit.char and unit.char.name) or "Unit", def.name or id))
            end
            return nil
        end
        local scaled = {}
        for k, v in pairs(opts) do scaled[k] = v end
        scaled.duration = effective
        opts = scaled
    end

    local status = Status.get(unit, id)
    local isNew = status == nil
    if status then
        status.remaining = math.max(status.remaining, opts.duration or def.duration or 0)
        if opts.magnitude then status.magnitude = opts.magnitude end
    else
        status = Status.instantiate(id, opts)
        unit.statuses[#unit.statuses + 1] = status
    end
    if def.onApply then def.onApply(ctxFor(combat, unit, status)) end
    -- Log only a fresh application (a refresh of an existing status would just spam the panel).
    -- A `hideLog` status announces nothing at all: Invisible would otherwise write the very line
    -- the Decoy that granted it is trying to keep out of the log.
    if isNew and not def.hideLog then
        local Combat = require("models.combat")
        Combat.logEvent(combat, "status",
            string.format("%s is afflicted with %s.", (unit.char and unit.char.name) or "Unit", def.name or id))
    end

    -- Fire the standing-reaction hook for a status landing (Trait.onStatusApplied), on BOTH sides of
    -- the event: the RECIPIENT (a ward that cleanses a debuff the moment it lands) and, when the cast
    -- carried its caster through `opts.applier`, the APPLIER (a relic that rewards inflicting a debuff).
    -- Pulled lazily so status.lua -> trait.lua stays a call-time edge with no load cycle. Guarded on
    -- `combat` so a dry run (which never passes one) can't reach the reaction machinery.
    if combat then
        -- `def` is deliberately NOT threaded as an event field: the trait ctx already binds ctx.def to
        -- the reacting TRAIT's blueprint, and a hook reads the landed status through ctx.status(.def).
        local Trait = require("models.trait")
        Trait.onStatusApplied(combat, unit,
            { status = status, applier = opts.applier, recipient = unit, role = "recipient" })
        local applier = opts.applier
        if applier and applier ~= unit and applier.alive then
            Trait.onStatusApplied(combat, applier,
                { status = status, applier = applier, recipient = unit, role = "applier" })
        end

        -- A hard-control or forced-movement status shatters a channel the recipient was winding up.
        -- `interruptsChannel = true` always breaks it (Stun, Freeze); `"mana"` breaks only a mana-cost
        -- channel (Silence gags the incantation but leaves a stamina channel alone). The onApply above
        -- already fired, so a stun's own initiative shove still lands even as the channel it cancels goes.
        local ic = def.interruptsChannel
        if ic and unit.channel then
            local Combat = require("models.combat")
            -- ANY mana in the channel's price counts: a working half-paid in stamina is still an
            -- incantation, and silence gags it (see Item.costs -- a cast may draw on several pools).
            if ic == true or (ic == "mana" and require("models.item").costsStat(unit.channel.ab, "mana")) then
                Combat.interruptChannel(combat, unit, def.name or id)
            end
        end
    end
    return status
end

-- Run the clock forward `elapsed` ticks over every status: fire each one's `onTick` for the stretch it
-- was actually alive, then age it and expire (firing onExpire for) any that run out. Called from
-- Combat.rebase with the rebase amount (the ticks that just elapsed).
--
-- Three rules make this correct, and each of them is a bug if you drop it:
--
--   * TICK FIRST, AGE SECOND, and tick over `min(elapsed, remaining)` -- the slice of the rebase the
--     status was alive for. Durations are in ticks and a single rebase routinely elapses more of them
--     than a status has left (Burn lasts 3; a turn costs ~5), so ageing first would delete a Burn
--     before it ever burned. Slicing is what keeps the last partial stretch honest rather than
--     rounding it up to a full rebase's worth.
--   * A ZONE-BOUND status (one a zone stamped with its `source`) is never aged at all: it lasts
--     exactly as long as its zone holds it, and Hazard.reap ends it -- on the beat its bearer steps
--     clear, or the zone dies. Ageing it would put it on two clocks at once and let a Sanctuary's
--     Regeneration lapse under a unit still standing in the Sanctuary. Its `remaining` stays untouched
--     as the backstop it is: the SAME status from something that is not a zone (a potion) carries no
--     source, has no ground to leave, and simply runs its duration here.
--   * Only what EXISTED when the tick began is aged. A hook is free to grant a status mid-tick, and it
--     must not be docked ticks that elapsed before it was applied; it starts counting at the next
--     rebase, with its full duration.
--
-- Ageing deliberately walks dead units too (a corpse's statuses still wind down), but an onTick effect
-- is something the bearer DOES, so only the living do it.
function Status.tick(combat, elapsed)
    if not elapsed or elapsed <= 0 then return end

    -- Snapshot before anything fires: which statuses this tick governs, and how much of `elapsed` each
    -- of them lives through.
    local entries = {}
    for _, unit in ipairs(combat.units) do
        for _, s in ipairs(unit.statuses or {}) do
            local slice = elapsed
            if not s.source then slice = math.min(elapsed, s.remaining) end
            entries[#entries + 1] = { unit = unit, status = s, slice = slice }
        end
    end

    for _, e in ipairs(entries) do
        if e.unit.alive and e.status.def.onTick and e.slice > 0 then
            local ctx = ctxFor(combat, e.unit, e.status)
            ctx.elapsed = e.slice
            e.status.def.onTick(ctx)
        end
    end

    for _, e in ipairs(entries) do
        local s = e.status
        if not s.source then
            s.remaining = s.remaining - elapsed
            if s.remaining <= 0 then
                -- Through Status.remove, so a status that unwinds unit state on its way out (Charm
                -- restoring the side it flipped) reverts on a natural expiry exactly as it does on a
                -- Cure. The announcement stays here: remove() is the silent mechanism, and only this
                -- path is the status quietly running out of time.
                Status.remove(combat, e.unit, s.id)
                if not s.def.hideLog then
                    local Combat = require("models.combat")
                    Combat.logEvent(combat, "status", string.format("%s's %s wears off.",
                        (e.unit.char and e.unit.char.name) or "Unit", s.name or s.id))
                end
            end
        end
    end
end

-- Run a named ctx hook ("onTurnStart" / "onTurnEnd" / "onEnterTile") for every status on `unit`.
-- Iterates a snapshot so a hook that mutates the status list can't corrupt the walk.
local function runHook(combat, unit, hook)
    local snapshot = {}
    for _, s in ipairs(unit.statuses or {}) do snapshot[#snapshot + 1] = s end
    for _, s in ipairs(snapshot) do
        if s.def[hook] then s.def[hook](ctxFor(combat, unit, s)) end
    end
end

function Status.onTurnStart(combat, unit)
    runHook(combat, unit, "onTurnStart")
end

function Status.onTurnEnd(combat, unit)
    runHook(combat, unit, "onTurnEnd")
end

-- The bearer just arrived on a tile UNDER ITS OWN WEIGHT -- it walked there, or it was shoved,
-- pulled, or trampled there. Fired from Combat.enterTile, the one chokepoint every position change
-- routes through, but only for ground movement: a blink, a swap, and a summon's arrival deliberately
-- do NOT fire it (see the `reason` gate there). The hook a per-tile effect hangs on -- Bleed, which
-- costs the afflicted unit blood for every step it takes and nothing at all for standing still.
function Status.onEnterTile(combat, unit)
    runHook(combat, unit, "onEnterTile")
end

-- The bearer just DEALT `amount` post-mitigation damage to someone. Fired from Combat.dealDamage
-- (where the attacker is known), so a status can record what its bearer does while it is active --
-- the general "accumulate state, resolve on expiry" mechanism (Fury banks damage dealt, then heals
-- a share of it in onExpire). The hook receives the same ctx as the others, plus `ctx.amount`.
-- Iterates a snapshot so a hook that mutates the status list can't corrupt the walk.
function Status.onDealDamage(combat, unit, amount)
    local snapshot = {}
    for _, s in ipairs(unit.statuses or {}) do snapshot[#snapshot + 1] = s end
    for _, s in ipairs(snapshot) do
        if s.def.onDealDamage then
            local ctx = ctxFor(combat, unit, s)
            ctx.amount = amount
            s.def.onDealDamage(ctx)
        end
    end
end

-- The bearer just TOOK `amount` post-mitigation damage and survived. The mirror of Status.onDealDamage
-- above ("what its bearer does" vs "what is done to its bearer"), fired from Combat.dealFlatDamage
-- beside Trait.onDamaged -- so, like that hook, it sees only a survivor and never the damage preview.
--
-- What a status hangs on to END ITSELF when its fiction says a blow would break it: Sleep, which is
-- deep until something hits you and then is not. Deliberately a status hook rather than a trait one:
-- the rule belongs to the sleep, not to the sleeper, so it travels with the status onto anyone it
-- lands on. The hook receives the usual ctx plus `ctx.amount` and `ctx.tags`.
function Status.onDamaged(combat, unit, amount, tags)
    local snapshot = {}
    for _, s in ipairs(unit.statuses or {}) do snapshot[#snapshot + 1] = s end
    for _, s in ipairs(snapshot) do
        if s.def.onDamaged then
            local ctx = ctxFor(combat, unit, s)
            ctx.amount, ctx.tags = amount, tags
            s.def.onDamaged(ctx)
        end
    end
end

-- Does any active status forbid this unit from moving this turn (root)?
function Status.blocksMove(unit)
    for _, s in ipairs(unit.statuses or {}) do
        if s.def.blocksMove then return true end
    end
    return false
end

-- The largest end-of-turn move cost any active status forces on the unit even if it stayed
-- put (root: the full movement budget). 0 when no status charges one.
function Status.forcedMoveCost(combat, unit)
    local cost = 0
    for _, s in ipairs(unit.statuses or {}) do
        if s.def.turnEndMoveCost then
            cost = math.max(cost, s.def.turnEndMoveCost(ctxFor(combat, unit, s)) or 0)
        end
    end
    return cost
end

return Status
