-- Tactical AI: how a unit that isn't being driven by a human decides what to do with its turn.
--
-- Pure model (no love.*, no mutation of combat), so it loads and runs under the headless tests --
-- the same contract models/combat.lua keeps. It pulls Combat through a lazy require inside the
-- functions that need it, because combat.lua requires THIS module for Combat.planEnemyAction.
--
-- ---------------------------------------------------------------------------
-- Three layers, because there are three different questions
-- ---------------------------------------------------------------------------
--
-- The temptation is to build one mechanism and make it do everything. Three well-known systems
-- each solved a different third of this problem, and collapsing them loses whichever third you
-- drop:
--
--   POSTURE   "do I engage at all, and where do I want my body to be?"     (Fire Emblem)
--   RULES     "what KIND of thing am I trying to do right now?"            (FF12 gambits)
--   SCORING   "which tile / item / target actually executes that intent?"  (FF Tactics)
--
-- A gambit list alone has no positional judgement -- FF12 is not a grid game, and a rule that says
-- "attack the nearest foe" cannot tell a good tile from a lethal one. A scoring function alone is
-- opaque: nobody can author it, and the player certainly can't. A posture alone is a mood, not a
-- decision. So all three are here, layered, and each is allowed to be simple because the other two
-- are carrying their own share.
--
-- The ordering rule that keeps this legible: RULES ARE HARD, SCORING IS SOFT. The rule list is
-- scanned strictly top to bottom and the first rule that matches and can actually be executed wins
-- outright -- exactly the property that makes a gambit list debuggable, and the reason a player can
-- reason about their own list at all ("rule 3 fired because 1 and 2 didn't"). Scoring never
-- overrules a rule; it only chooses among the candidates the winning rule already admitted. If
-- scoring were allowed to outrank the list, the list would stop meaning anything and the whole
-- player-facing half of this feature would become a lie.
--
-- ---------------------------------------------------------------------------
-- The plan descriptor
-- ---------------------------------------------------------------------------
--
-- AI.plan returns exactly what Combat.planEnemyAction has always returned, because states/battle.lua
-- executes it and the tutorial's scripted overrides produce the same shape:
--
--   { move = { x, y } | nil, item = <item>, tx, ty }   -- act (optionally after walking there)
--   { move = { x, y } }                                -- reposition only
--   { wait = true }                                    -- nothing worth doing
--
-- ...plus `reason`, a short human-readable string naming what decided it. That field is not
-- decoration and should not be dropped as an optimisation: a priority system whose choices can't be
-- read back is a priority system nobody can author against. It is the difference between tuning
-- this and guessing at it.

local Status = require("models.status")
local Hazard = require("models.hazard")
local Trait = require("models.trait")

local AI = {}

-- How many of the best-looking candidates get the expensive risk pass (Trait.counterPreview per
-- stand tile, plus the threat-map exposure lookup). Ability previews are memoised by (item, target)
-- and so are cheap enough to run across the board; counter risk depends on WHERE the blow is thrown
-- from, so it can't be shared between tiles and is budgeted instead. 16 is well past the point where
-- the ranking stops changing on the board sizes this game uses.
AI.RISK_BUDGET = 16

local function manhattan(ax, ay, bx, by)
    return math.abs(ax - bx) + math.abs(ay - by)
end

local function hp(unit)
    local h = unit and unit.char and unit.char.stats and unit.char.stats.health
    if type(h) == "table" then return h.current or 0, h.max or 1 end
    return h or 0, h or 1
end

local function hpFraction(unit)
    local cur, max = hp(unit)
    if max <= 0 then return 0 end
    return cur / max
end

-- ---------------------------------------------------------------------------
-- Weights
-- ---------------------------------------------------------------------------

-- Score terms, in the units the scorer works in (roughly "points of health"). Damage and healing
-- enter at face value, so every other weight below is readable as an exchange rate against them:
-- KILL = 40 says "finishing something is worth about forty points of chip damage", which is the
-- single judgement that most defines how the AI reads, and the first number to reach for when it
-- feels too timid or too reckless.
--
-- A posture overrides any subset of these (see AI.POSTURES), which is what makes an archer play
-- differently from a berserker without either of them needing its own code path.
AI.WEIGHTS = {
    DAMAGE       = 1.0,
    HEAL         = 1.0,
    KILL         = 40,    -- FFT's dominant term: a corpse stops taking turns
    FRIENDLY_FIRE = 2.5,  -- harm to my own side counts MORE than the same harm to theirs
    STATUS       = 3,     -- flat, per status a hit would land: it does something, we don't price what
    COUNTER      = 1.2,   -- damage thrown back at me, per point -- slightly dearer than damage dealt
    EXPOSURE     = 1.5,   -- per enemy that could reach the tile I would end my turn on
    HAZARD       = 4,     -- Hazard.tileBias, already signed for my side (fire negative, sanctuary +)
    SPEND        = 0.15,  -- per point of a resource cost, so a mage doesn't nuke a woodlouse
    STEPS        = 0.25,  -- mild: keeps motion sensible without making the AI lazy
    TARGET_PREF  = 6,     -- bonus when a candidate matches the rule's stated targeting preference
}

-- ---------------------------------------------------------------------------
-- Condition vocabulary
-- ---------------------------------------------------------------------------
--
-- A rule's `when` is a declarative table -- { subject, test, value } -- rather than a Lua predicate,
-- and that is a deliberate constraint rather than a limitation to apologise for. It has to survive a
-- save file, render as a sentence in the Tactics tab, and be editable from two dropdowns and a
-- number. A closure does none of those. The same trade is already settled elsewhere in this codebase
-- the same way: models/trait.lua declares `counter = { reach = "melee", ... }` as data and keeps
-- hooks for the genuinely strange cases. `whenFn` is that escape hatch here, for NPC-only content
-- the player-facing UI never has to draw.
--
-- A subject resolves to a LIST of units. A test decides whether that list satisfies the condition --
-- taking the list rather than one unit so that a counting test ("at least 2 foes clustered") is
-- expressible in the same grammar as a per-unit one, instead of needing a second mechanism.

local function foes(ctx)
    local out = {}
    for _, u in ipairs(ctx.combat.units) do
        if u.alive and u.side ~= ctx.unit.side and not Status.untargetable(u) then out[#out + 1] = u end
    end
    return out
end

local function allies(ctx)
    local out = {}
    for _, u in ipairs(ctx.combat.units) do
        if u.alive and u.side == ctx.unit.side then out[#out + 1] = u end
    end
    return out
end

local function nearest(ctx, list)
    local best, bestD
    for _, u in ipairs(list) do
        local d = manhattan(ctx.unit.x, ctx.unit.y, u.x, u.y)
        if not bestD or d < bestD then best, bestD = u, d end
    end
    return best
end

local function weakest(list)
    local best, bestF
    for _, u in ipairs(list) do
        local f = hpFraction(u)
        if not bestF or f < bestF then best, bestF = u, f end
    end
    return best
end

local function one(u) return u and { u } or {} end

AI.SUBJECTS = {
    ["self"]           = function(ctx) return { ctx.unit } end,
    ["any_foe"]        = function(ctx) return foes(ctx) end,
    ["any_ally"]       = function(ctx) return allies(ctx) end,
    ["nearest_foe"]    = function(ctx) return one(nearest(ctx, foes(ctx))) end,
    ["nearest_ally"]   = function(ctx) return one(nearest(ctx, allies(ctx))) end,
    ["foe_lowest_hp"]  = function(ctx) return one(weakest(foes(ctx))) end,
    ["ally_lowest_hp"] = function(ctx) return one(weakest(allies(ctx))) end,
    -- Whoever the arena's objective actually names -- the escorted charge on a `protect` map, the
    -- mark on an `assassinate` one. This is how a rule reaches the objective without the rule
    -- author needing to know which kind of map they are standing on.
    ["objective_unit"] = function(ctx) return one(AI.objectiveUnit(ctx.combat, ctx.unit)) end,
}

-- Each test takes (ctx, list, value) and answers yes/no for the list as a whole.
local function anyOf(list, pred)
    for _, u in ipairs(list) do if pred(u) then return true end end
    return false
end

AI.TESTS = {
    ["always"]        = function(_, list) return #list > 0 end,
    ["exists"]        = function(_, list) return #list > 0 end,
    ["hp_pct_below"]  = function(_, list, v) return anyOf(list, function(u) return hpFraction(u) < (v or 1) end) end,
    ["hp_pct_above"]  = function(_, list, v) return anyOf(list, function(u) return hpFraction(u) > (v or 0) end) end,
    ["has_status"]    = function(_, list, v) return anyOf(list, function(u) return Status.has(u, v) end) end,
    ["lacks_status"]  = function(_, list, v) return anyOf(list, function(u) return not Status.has(u, v) end) end,
    ["within"]        = function(ctx, list, v)
        return anyOf(list, function(u) return manhattan(ctx.unit.x, ctx.unit.y, u.x, u.y) <= (v or 1) end)
    end,
    ["count_at_least"] = function(_, list, v) return #list >= (v or 1) end,
    -- "Can I hit it from where I stand right now, with anything I'm carrying?" -- the difference
    -- between a rule that fires when a foe is merely near and one that fires when it is actually
    -- reachable this instant.
    ["in_reach"] = function(ctx, list)
        local Combat = require("models.combat")
        for _, item in ipairs(ctx.items) do
            for _, t in ipairs(Combat.abilityTargets(ctx.combat, ctx.unit, item)) do
                for _, u in ipairs(list) do if u == t then return true end end
            end
        end
        return false
    end,
}

-- What a rule can ask for. A closed set, for the same reason the subjects and tests are: the Tactics
-- tab has to offer these as a dropdown, and a typo has to be catchable by a test sweep rather than
-- by a battle going strange.
--   attack  -- a hostile ability, at a foe
--   support -- a friendly ability, at an ally (or self)
--   cast    -- either; the form an item's own block usually wants, since the item knows which it is
--   retreat -- break off toward the ally most in need of cover
--   wait    -- spend the turn deliberately
AI.ACTIONS = {
    attack = true, support = true, cast = true, retreat = true, wait = true,
}

-- ---------------------------------------------------------------------------
-- Ordered vocabulary, for the Tactics tab
-- ---------------------------------------------------------------------------
--
-- The tables above are keyed sets, which is right for asking "is this a real subject?" and wrong for
-- a dropdown: `pairs` has no order, so a UI built on it would shuffle its options between runs and a
-- player would never learn where anything is. These lists are the authoritative ORDER, arranged so
-- the most-reached-for option is first. Every name here must exist in the matching set above, and
-- tests/ai_spec.lua checks that in both directions -- a vocabulary entry the UI can't offer is as
-- much a bug as an option that resolves to nothing.
AI.SUBJECT_ORDER = {
    "nearest_foe", "any_foe", "foe_lowest_hp",
    "self", "any_ally", "nearest_ally", "ally_lowest_hp",
    "objective_unit",
}
AI.TEST_ORDER = {
    "exists", "in_reach", "within", "hp_pct_below", "hp_pct_above",
    "count_at_least", "has_status", "lacks_status", "always",
}
AI.ACTION_ORDER = { "attack", "support", "cast", "retreat", "wait" }
AI.PRIORITY_ORDER = { "emergency", "urgent", "high", "normal", "low", "fallback" }
AI.TARGET_PREF_ORDER = { "nearest", "lowest_hp", "most_wounded", "lethal", "self", "objective" }

-- Which tests take a `value`, and what shape it is. A test that takes none must not show a value
-- field at all -- an editor offering "exists 0.4" is offering nonsense.
AI.TEST_VALUE = {
    within         = { kind = "tiles",   min = 1,   max = 12,  step = 1,    default = 2 },
    hp_pct_below   = { kind = "percent", min = 0.05, max = 1,  step = 0.05, default = 0.5 },
    hp_pct_above   = { kind = "percent", min = 0.05, max = 1,  step = 0.05, default = 0.5 },
    count_at_least = { kind = "count",   min = 1,   max = 8,   step = 1,    default = 2 },
    has_status     = { kind = "status",  default = "status_burn" },
    lacks_status   = { kind = "status",  default = "status_burn" },
}

-- A blank rule, for "+ Add rule". Deliberately the most ordinary thing a player could want, so the
-- first thing they see after adding is a rule that already reads as a sentence and already works.
function AI.newRule()
    return {
        enabled = true,
        priority = "normal",
        act = "attack",
        targetPref = "nearest",
        when = { subject = "nearest_foe", test = "exists" },
    }
end

-- Does `rule`'s condition hold? An unrecognised subject or test is a data error and says so rather
-- than quietly evaluating to true -- a typo'd gambit that silently always fires is the single most
-- expensive kind of bug this system could have, because it looks like working behavior.
function AI.matches(ctx, rule)
    if not rule then return false end
    if rule.whenFn then
        local ok, res = pcall(rule.whenFn, ctx)
        return ok and res and true or false
    end
    local cond = rule.when
    if not cond then return true end -- an unconditional rule
    local subject = AI.SUBJECTS[cond.subject]
    local test = AI.TESTS[cond.test]
    assert(subject, "AI rule names an unknown subject: " .. tostring(cond.subject))
    assert(test, "AI rule names an unknown test: " .. tostring(cond.test))
    return test(ctx, subject(ctx), cond.value) and true or false
end

-- Render a rule as a sentence. The single formatting choke point, so that the Tactics tab, the
-- combat-log reason line and any later localisation pass all read the same words.
-- A value in the units its test actually means: a fraction reads as a percentage, a distance reads as
-- tiles. "hp below 0.4" is data; "hp below 40%" is a sentence, and the rows in the Tactics tab have to
-- be sentences or nobody will read them.
function AI.describeValue(test, value)
    if value == nil then return nil end
    local spec = AI.TEST_VALUE[test]
    local kind = spec and spec.kind
    if kind == "percent" then return math.floor(value * 100 + 0.5) .. "%" end
    if kind == "tiles" then return value .. (value == 1 and " tile" or " tiles") end
    if kind == "status" then
        local def = require("models.status").defs[value]
        return (def and def.name) or tostring(value)
    end
    return tostring(value)
end

function AI.describeRule(rule)
    if not rule then return "(no rule)" end
    local when = "always"
    if rule.whenFn then
        when = rule.label or "(scripted)"
    elseif rule.when then
        local c = rule.when
        when = (c.subject or "?") .. " " .. (c.test or "?")
        local v = AI.describeValue(c.test, c.value)
        if v then when = when .. " " .. v end
        when = (when:gsub("_", " "))
    end
    local act = (rule.act or "attack"):gsub("_", " ")
    -- Name the item where one is pinned: "cast Heal" is the sentence the player wrote, and "cast"
    -- alone would hide the most specific thing about the rule.
    if rule.item then act = act .. " " .. (AI.itemName(rule.item) or "?") end
    if rule.targetPref then act = act .. " " .. (rule.targetPref:gsub("_", " ")) end
    -- The band leads, because when two rules could both fire the reader's first question is which
    -- one gets the turn, and that is the answer.
    return AI.priorityName(rule) .. ": if " .. when .. " then " .. act
end

-- ---------------------------------------------------------------------------
-- Postures
-- ---------------------------------------------------------------------------
--
-- A posture answers the engagement question Fire Emblem's AI is built around, and supplies the
-- default rule list for a unit that declares nothing more specific. `engage` gates whether the unit
-- will act on a foe at all this turn; `move` says what it does when no rule produced an action.
--
-- `rules` here are the built-in defaults. Phase 2 layers item- and character-authored rules on top
-- of them; nothing about the scan below needs to change for that to work, which is the point of
-- routing even the default behavior through the rule list rather than hard-coding it.

local ATTACK_RULE  = { act = "attack",  when = { subject = "any_foe",  test = "exists" } }
local SUPPORT_RULE = { act = "support", when = { subject = "any_ally", test = "hp_pct_below", value = 0.6 },
                       targetPref = "lowest_hp" }

AI.POSTURES = {
    -- Walks at the enemy and hits the best thing it can reach. The historical behavior, now with
    -- judgement about which thing that is.
    aggressive = {
        rules = { SUPPORT_RULE, ATTACK_RULE },
        move = "approach",
        engage = function() return true end,
    },

    -- Holds until the fight comes to it, then commits. This is Fire Emblem's activation rule, and it
    -- is what lets a map be authored with quiet corners: a room full of `defensive` guards is a room
    -- the player can choose when to open, rather than a timer.
    defensive = {
        rules = { SUPPORT_RULE, ATTACK_RULE },
        -- `approach`, not `hold` -- the holding is `engage`'s job, and doing it twice would mean a
        -- unit that has been shot at still refuses to walk toward whoever shot it. Once provoked, a
        -- defender commits like anyone else; the posture is about WHEN the fight starts, not about
        -- fighting it at arm's length. (AI.plan only consults `move` when engage has passed.)
        move = "approach",
        engage = function(ctx)
            if hpFraction(ctx.unit) < 1 then return true end -- someone already shot at me
            local Combat = require("models.combat")
            for _, item in ipairs(ctx.items) do
                if #Combat.abilityTargets(ctx.combat, ctx.unit, item) > 0 then return true end
            end
            return false
        end,
    },

    -- Never leaves the tile it was put on. A sentry, a turret, a boss that owns a throne room.
    holdGround = {
        rules = { ATTACK_RULE },
        move = "hold",
        rooted = true,
        engage = function() return true end,
    },

    -- Leashed: pursues within `leash` tiles of where it started and goes home once past it. The
    -- posture that makes a patrol readable -- the player can bait it out and see it disengage.
    guard = {
        rules = { SUPPORT_RULE, ATTACK_RULE },
        move = "leash",
        leash = 4,
        engage = function() return true end,
    },

    -- Wants distance. Same rules as an aggressor, opposite footwork: EXPOSURE is dear and closing is
    -- actively penalised, so an archer that can shoot from six tiles will not stroll to three.
    skirmish = {
        rules = { SUPPORT_RULE, ATTACK_RULE },
        move = "kite",
        weights = { EXPOSURE = 5, STEPS = 0.1, COUNTER = 2.5 },
        engage = function() return true end,
    },

    -- Reads its allies before its enemies. Nothing in the old planner ever pointed a heal at
    -- anything, so an enemy healer's kit was decoration; this is the posture that makes it a threat.
    support = {
        rules = {
            { act = "support", when = { subject = "any_ally", test = "hp_pct_below", value = 0.9 },
              targetPref = "lowest_hp" },
            ATTACK_RULE,
        },
        move = "regroup",
        weights = { HEAL = 1.8, EXPOSURE = 3 },
        engage = function() return true end,
    },

    -- Plays the map rather than the bodies: goes for whoever the objective names, and falls back to
    -- ordinary aggression on a map whose objective has no unit to point at (a plain killAll).
    objective = {
        rules = {
            { act = "attack", when = { subject = "objective_unit", test = "exists" },
              targetPref = "objective" },
            ATTACK_RULE,
        },
        move = "objective",
        engage = function() return true end,
    },
}

AI.DEFAULT_POSTURE = "aggressive"

function AI.posture(unit)
    local name = unit and unit.char and unit.char.archetype
    return AI.POSTURES[name] or AI.POSTURES[AI.DEFAULT_POSTURE], name or AI.DEFAULT_POSTURE
end

-- The unit the arena's objective points at, from `unit`'s point of view: the mark it must kill, or
-- the charge it must cut down (an escort objective names a party-side protectee, which to an enemy
-- is precisely the thing worth killing). Nil on an objective with no positional handle.
function AI.objectiveUnit(combat, unit)
    local obj = combat.objective
    if not obj then return nil end
    local id = obj.target or obj.protect
    if not id then return nil end
    for _, u in ipairs(combat.units) do
        if u.alive and u.char.id == id and not u.summoned and u.side ~= unit.side then return u end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Candidate enumeration
-- ---------------------------------------------------------------------------
--
-- A candidate is one complete answer to "stand HERE, use THIS, aimed at THAT". Enumerating them is
-- the only genuinely new search in this module, and the cost model is worth stating because it is
-- what keeps it affordable:
--
--   * Combat.previewAbility is the expensive call -- it replays the ability's real effect closure --
--     but its result depends on (item, aim cell), NOT on where the caster stands. So it is memoised
--     across every stand tile that can reach the same target with the same item, which collapses the
--     dominant cost from tiles x items x targets down to items x targets.
--   * Trait.counterPreview genuinely does depend on the stand tile (that is the whole point of its
--     fromX/fromY parameter), so it can't be shared, and is instead run only over the top
--     AI.RISK_BUDGET candidates after the cheap ranking has already thrown out the obvious losers.

local function itemsFor(combat, unit)
    local Combat = require("models.combat")
    local out = {}
    for _, item in ipairs(Combat.abilityItems(unit.char)) do
        if not Combat.itemBlockReason(unit, item) then out[#out + 1] = item end
    end
    -- The bare-handed strike goes last: it is free, so it can never be filtered out above, and a unit
    -- that can't pay for a single ability can still throw a punch. Sorting it last means a real
    -- weapon is preferred whenever the scores tie.
    if unit.char.unarmed then out[#out + 1] = unit.char.unarmed end
    return out
end

-- Every (stand tile, item, target) triple this unit could legally execute this turn. `opts.tiles`
-- restricts the stand tiles (a rooted posture passes just the origin); `opts.support` selects which
-- half of the kit is under consideration.
function AI.candidates(combat, unit, items, tiles, wantSupport)
    local Combat = require("models.combat")
    local out = {}
    for _, tile in ipairs(tiles) do
        for _, item in ipairs(items) do
            local ab = item.activeAbility
            if ab and Combat.isSupportAbility(ab) == wantSupport then
                local range = Combat.abilityRange(combat, unit, ab, tile.x, tile.y)
                    + Combat.adjacencyRangeBonus(unit.char, item)
                local minRange = Combat.abilityMinRange(ab)
                for _, t in ipairs(combat.units) do
                    -- Who is a legal mark for this half of the kit. A support cast wants my own side
                    -- (including me); a strike wants theirs, and can't see an Invisible foe.
                    local legal = t.alive and (wantSupport
                        and t.side == unit.side
                        or (not wantSupport and t.side ~= unit.side and not Status.untargetable(t)))
                    if legal then
                        local d = manhattan(tile.x, tile.y, t.x, t.y)
                        if d <= range and d >= minRange
                            and (not ab.requiresSight
                                 or Combat.hasLineOfSight(combat, tile.x, tile.y, t.x, t.y)) then
                            out[#out + 1] = {
                                x = tile.x, y = tile.y, steps = tile.steps or 0,
                                item = item, target = t, tx = t.x, ty = t.y,
                                moved = tile.x ~= unit.x or tile.y ~= unit.y,
                            }
                        end
                    end
                end
            end
        end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- Scoring
-- ---------------------------------------------------------------------------

-- What the ability would actually do, as a single number from `unit`'s point of view: damage and
-- kills on their side count for me, damage on mine counts against me, and healing counts wherever it
-- lands on my own side. Read off Combat.previewAbility, so an AoE is priced by everyone it truly
-- catches -- which is what stops a fireball from being aimed into a huddle of its caster's friends.
local function outcomeScore(combat, unit, cand, w, previews)
    local Combat = require("models.combat")
    local memo = cand.item.id or tostring(cand.item)
    local k = memo .. "@" .. cand.tx .. "," .. cand.ty
    local preview = previews[k]
    if preview == nil then
        preview = Combat.previewAbility(combat, unit, cand.item, cand.tx, cand.ty) or false
        previews[k] = preview
    end
    if not preview then return 0, false end

    local score, lethal = 0, false
    for _, e in ipairs(preview.order or {}) do
        -- Everything below flips on one question -- is this body on my side? -- so it is asked once
        -- and each term reads as the pair of exchange rates it actually is.
        local friendly = e.unit.side == unit.side
        score = score + (e.damage or 0) * (friendly and -w.FRIENDLY_FIRE or w.DAMAGE)
        score = score + (e.heal or 0) * (friendly and w.HEAL or -w.HEAL)
        score = score + #(e.statuses or {}) * (friendly and 0 or w.STATUS)
        if e.lethal then
            score = score + (friendly and -w.KILL or w.KILL)
            lethal = lethal or not friendly
        end
    end
    return score, lethal
end

-- Cheap first pass: outcome, footing and price, with no positional risk term yet. Everything here is
-- either memoised or arithmetic, so it can be run across the whole candidate set.
function AI.scoreCandidate(combat, unit, cand, w, previews)
    local Combat = require("models.combat")
    local score, lethal = outcomeScore(combat, unit, cand, w, previews)
    cand.lethal = lethal
    -- Kept apart from the running total on purpose. `outcome` is "does this action DO anything to
    -- anybody", and it alone decides whether the action is worth taking at all; everything added
    -- below is about choosing between actions already worth taking. Folding the two together is the
    -- obvious shortcut and it is wrong: a sword costs stamina and draws a parry, so its net score is
    -- routinely negative, and a unit that demands a positive net simply refuses to fight.
    cand.outcome = score

    score = score + Hazard.tileBias(combat, cand.x, cand.y, unit.side) * w.HAZARD
    score = score - (cand.steps or 0) * w.STEPS

    for _, s in ipairs(Combat.abilitySpend(unit, cand.item.activeAbility) or {}) do
        score = score - (s.amount or 0) * w.SPEND
    end

    return score
end

-- Second pass, over the shortlist only: what standing there gets me hit by. Both terms need the
-- stand tile, which is exactly why they can't ride along in the cheap pass.
function AI.riskScore(combat, unit, cand, w, threat)
    local risk = 0

    -- What this specific blow, thrown from this specific tile, would earn me in return. A killing
    -- blow is answered by nothing (the hook-driven reflexes fire from Trait.onDamaged, which a
    -- corpse never reaches), so a lethal candidate skips the counter term entirely rather than
    -- being taxed for a riposte that will never be thrown.
    if not cand.lethal then
        local ok, answers = pcall(Trait.counterPreview, combat, cand.target, unit,
            { fromX = cand.x, fromY = cand.y })
        if ok then
            for _, a in ipairs(answers or {}) do
                risk = risk + (a.damage or 0) * w.COUNTER
            end
        end
    end

    -- ...and what everyone ELSE could do to me for ending my turn here. Read off the same
    -- Combat.threatMap the player's purple danger overlay is drawn from, so the AI is respecting
    -- the very zone the game teaches the player to respect.
    local src = threat[cand.x .. "," .. cand.y]
    if src then risk = risk + #src * w.EXPOSURE end

    return -risk
end

-- ---------------------------------------------------------------------------
-- Movement fallbacks
-- ---------------------------------------------------------------------------

-- The tile to walk to when no rule produced an action, per the posture's `move` mode. Returns a
-- plan descriptor or nil. Never returns a move that fails to improve the unit's situation, so a
-- unit with nothing to do stands still instead of pacing.
local function fallbackMove(ctx, mode)
    local Combat = require("models.combat")
    local unit, combat = ctx.unit, ctx.combat
    if mode == "hold" then return nil end

    local goal
    if mode == "objective" then
        goal = AI.objectiveUnit(combat, unit) or nearest(ctx, foes(ctx))
    elseif mode == "regroup" then
        -- Toward the ally most in need of me, not toward the fight.
        goal = weakest(allies(ctx)) or nearest(ctx, foes(ctx))
    else
        goal = nearest(ctx, foes(ctx))
    end
    if not goal then return nil end

    local anchorX = unit.anchorX or unit.x
    local anchorY = unit.anchorY or unit.y
    local leash = ctx.posture.leash
    local here = manhattan(unit.x, unit.y, goal.x, goal.y)

    -- A kiter with nothing in range still has to close -- standing off from a foe it cannot shoot is
    -- not skirmishing, it is abstaining. Kiting is expressed in the EXPOSURE weight when it HAS a
    -- shot; the walk itself is an ordinary approach.
    local best
    for _, node in pairs(Combat.reachable(combat, unit)) do
        if not (mode == "leash" and manhattan(node.x, node.y, anchorX, anchorY) > leash) then
            local d = manhattan(node.x, node.y, goal.x, goal.y)
            local bias = Hazard.tileBias(combat, node.x, node.y, unit.side)
            if not best or d < best.d
                or (d == best.d and bias > best.bias)
                or (d == best.d and bias == best.bias and node.steps < best.steps) then
                best = { x = node.x, y = node.y, d = d, bias = bias, steps = node.steps }
            end
        end
    end

    -- Off the leash and unable to get closer to anything: go home.
    if mode == "leash" and manhattan(unit.x, unit.y, anchorX, anchorY) > leash then
        local home
        for _, node in pairs(Combat.reachable(combat, unit)) do
            local d = manhattan(node.x, node.y, anchorX, anchorY)
            if not home or d < home.d then home = { x = node.x, y = node.y, d = d } end
        end
        if home and home.d < manhattan(unit.x, unit.y, anchorX, anchorY) then
            return { move = { x = home.x, y = home.y }, reason = "leash: returning to post" }
        end
    end

    if best and best.d < here then
        return { move = { x = best.x, y = best.y }, reason = mode .. ": closing on " .. (goal.char.name or "target") }
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Preemption
-- ---------------------------------------------------------------------------

-- Compulsions that sit ABOVE the rule list and are not negotiable: a taunted unit does not get to
-- consult its tactics, that is what being taunted means. Lifted wholesale out of the old
-- Combat.planEnemyAction so its behavior is preserved exactly. Returns a plan, or nil to continue on
-- to the ordinary decision.
function AI.preempt(combat, unit)
    local Combat = require("models.combat")
    local taunt = Status.get(unit, "status_taunt")
    if not (taunt and taunt.taunter and taunt.taunter.alive and taunt.taunter.side ~= unit.side) then
        return nil
    end

    local tt = taunt.taunter
    local weapon = Combat.defaultWeapon(unit.char)
    if weapon then
        local ab = weapon.activeAbility
        for _, t in ipairs(Combat.abilityTargets(combat, unit, weapon)) do
            if t.x == tt.x and t.y == tt.y then
                return { item = weapon, tx = tt.x, ty = tt.y, reason = "taunted" }
            end
        end
        local minRange = Combat.abilityMinRange(ab)
        local best
        for _, node in pairs(Combat.reachable(combat, unit)) do
            local range = Combat.abilityRange(combat, unit, ab, node.x, node.y)
                + Combat.adjacencyRangeBonus(unit.char, weapon)
            local d = manhattan(node.x, node.y, tt.x, tt.y)
            if d <= range and d >= minRange
                and (not (ab and ab.requiresSight) or Combat.hasLineOfSight(combat, node.x, node.y, tt.x, tt.y))
                and (not best or node.steps < best.steps) then
                best = { x = node.x, y = node.y, steps = node.steps }
            end
        end
        if best then
            return { move = { x = best.x, y = best.y }, item = weapon, tx = tt.x, ty = tt.y,
                     reason = "taunted" }
        end
    end

    -- Out of reach even after moving: shamble toward the taunter.
    local dest
    for _, node in pairs(Combat.reachable(combat, unit)) do
        local d = manhattan(node.x, node.y, tt.x, tt.y)
        if not dest or d < dest.dist or (d == dest.dist and node.steps < dest.steps) then
            dest = { x = node.x, y = node.y, dist = d, steps = node.steps }
        end
    end
    if dest and dest.dist < manhattan(unit.x, unit.y, tt.x, tt.y) then
        return { move = { x = dest.x, y = dest.y }, reason = "taunted" }
    end
    return { wait = true, reason = "taunted, out of reach" }
end

-- ---------------------------------------------------------------------------
-- The rule list
-- ---------------------------------------------------------------------------

-- Where a unit's rules come from, in the order a tie is broken:
--
--   1. PLAYER   char.aiRules      -- authored in the Loadout screen's Tactics tab
--   2. ITEM     ability.ai        -- rides on the item, so handing an NPC a weapon hands it the
--                                    tactics for that weapon too. This is the whole point of the
--                                    feature: content authors give a bandit a bomb and it starts
--                                    lobbing it at clusters, with nothing else to write.
--   3. CHARACTER char.ai          -- blueprint-authored, for behavior specific to one body (a boss)
--   4. POSTURE  archetype defaults -- the floor everyone stands on
--
-- `priority` is the primary sort and is explicit for a reason: three independent authors are
-- contributing to one list and none of them can see the others, so position-in-file cannot be the
-- ordering. Lower runs first. The source ranking above only breaks TIES, and declaration order
-- breaks ties within a source, which together make the sort total -- two runs of the same battle
-- must not produce different rule orders.
AI.SOURCE_RANK = { player = 1, item = 2, character = 3, posture = 4 }

-- A rule may name the item it wants used, and there are two ways it can arrive:
--
--   * an ITEM's own block carries the live item table (resolved when the list is built -- a rule
--     that came off a spell means that spell, and says so by identity)
--   * a PLAYER or CHARACTER rule names an item by ID string ("ability_heal"), because it has to
--     survive a save file and be pickable from a dropdown
--
-- The id is deliberately NOT a grid slot, even though `defaultActionSlot` -- the one existing
-- per-character player setting -- is exactly that. The difference is what the player meant. Pinning a
-- default action means "whatever I keep in this cell"; a tactics rule means "cast Heal", and this
-- screen's entire purpose is rearranging the grid for adjacency auras. A slot-based rule would
-- silently change which spell it fires every time the player optimised their layout, and would do so
-- without a word on screen.
--
-- Returns nil when the character isn't carrying it -- which is a real and expected state (the item
-- was stowed, sold, or spent), and is handled the same way an unaffordable item is: the rule is
-- skipped entirely rather than firing with whatever else is to hand.
function AI.resolveItem(char, ref)
    if ref == nil then return nil end
    if type(ref) ~= "string" then return ref end -- already a live item
    local Combat = require("models.combat")
    for _, item in ipairs(Combat.abilityItems(char)) do
        if item.id == ref then return item end
    end
    -- The bare fists are a legitimate thing to name -- they cost nothing and are always available --
    -- but they never appear in the grid, so they are looked up separately.
    if char.unarmed and char.unarmed.id == ref then return char.unarmed end
    return nil
end

-- The display name for a rule's item reference, without needing the character to be carrying it --
-- so the Tactics tab can still label a rule whose item has been stowed.
function AI.itemName(ref)
    if ref == nil then return nil end
    if type(ref) ~= "string" then return ref.name or "?" end
    local def = require("models.item").defs[ref]
    return (def and def.name) or ref
end

-- Priority is authored as a NAME, not a number. A bare `priority = 20` is unreadable at the point it
-- matters most -- in a data file, months later, deciding whether the rule you are adding should come
-- before or after one you can't see -- and two authors picking numbers independently have no way to
-- agree. A name says what the rule is FOR, and the ordering follows from that rather than from
-- whoever guessed a smaller integer.
--
-- The gaps are deliberate: a raw number is still accepted for the rare case that wants to slot
-- between two levels, and leaving room means doing so never requires renumbering anything else.
AI.PRIORITY = {
    -- I am about to die. Drink the potion, break off, do not trade blows.
    emergency = 10,
    -- Someone else is about to die, or a chance appears that will not come round again.
    urgent    = 20,
    -- Worth doing before the ordinary business of the turn: the expensive spell, the opening gambit.
    high      = 40,
    -- The ordinary business of the turn. Posture defaults live here, so a rule that names nothing
    -- competes with "attack whatever is in reach" and wins only on the source ranking.
    normal    = 100,
    -- Do this if nothing better presented itself.
    low       = 200,
    -- The floor. Reposition, regroup, idle.
    fallback  = 400,
}

AI.DEFAULT_PRIORITY = "normal"

-- Resolve a rule's authored priority to the number the sort runs on. Accepts a name (preferred), a
-- raw number (an escape hatch for slotting between levels), or nothing.
function AI.priorityOf(rule)
    local p = rule and rule.priority
    if p == nil then return AI.PRIORITY[AI.DEFAULT_PRIORITY] end
    if type(p) == "number" then return p end
    local level = AI.PRIORITY[p]
    assert(level, "AI rule names an unknown priority: " .. tostring(p)
        .. " (expected one of emergency/urgent/high/normal/low/fallback, or a number)")
    return level
end

-- The name of the band a priority falls in, for the reason line and the Tactics tab. An exact match
-- reads back as itself; a raw number reads as the band it sits in, so a hand-tuned 25 still explains
-- itself as "urgent" rather than as a bare integer nobody can place.
function AI.priorityName(rule)
    local value = AI.priorityOf(rule)
    local best, bestValue
    for name, level in pairs(AI.PRIORITY) do
        if level <= value and (not bestValue or level > bestValue) then best, bestValue = name, level end
    end
    return best or "normal"
end

-- An item's rules are written from the item's own point of view, so a rule that names no `item` is
-- understood to mean "this one". Resolved here rather than at the use site so an authored block can
-- stay as short as `ai = { { when = ..., act = "cast" } }`.
local function collect(out, rules, source, item)
    if not rules then return end
    -- Accept a lone rule table as well as a list of them, so the common one-rule case doesn't have
    -- to be wrapped in braces it gains nothing from.
    if rules.act or rules.when or rules.whenFn then rules = { rules } end
    for i, rule in ipairs(rules) do
        -- `enabled == false` switches a rule off without deleting it -- the player toggles rows in the
        -- Tactics tab to see what a list does without them, which is most of how anyone debugs one.
        -- Only an explicit false counts: a rule that never mentions `enabled` is on, so no authored
        -- data file has to say so.
        if rule.enabled ~= false then
            out[#out + 1] = {
                rule = rule, ref = rule.item or item,
                priority = AI.priorityOf(rule),
                rank = AI.SOURCE_RANK[source] or 9,
                order = i,
            }
        end
    end
end

-- The ordered rules this unit decides by, merged from all four sources.
--
-- Each entry is { rule, item, missing }:
--   item    -- the live item this rule must use, or nil for "anything in the kit"
--   missing -- true when the rule NAMED an item the character isn't carrying. Distinct from a plain
--              nil item, and the distinction matters: "use anything" and "use the Heal I no longer
--              have" must not resolve to the same behavior, or losing an item silently widens a
--              rule instead of disabling it.
function AI.rulesFor(unit)
    local Combat = require("models.combat")
    local posture = AI.posture(unit)
    local char = unit.char
    local out = {}

    collect(out, char.aiRules, "player")
    for _, item in ipairs(Combat.abilityItems(char)) do
        local ab = item.activeAbility
        collect(out, ab and ab.ai, "item", item)
    end
    collect(out, char.ai, "character")
    collect(out, posture.rules, "posture")

    table.sort(out, function(a, b)
        if a.priority ~= b.priority then return a.priority < b.priority end
        if a.rank ~= b.rank then return a.rank < b.rank end
        return a.order < b.order
    end)

    local rules = {}
    for i, e in ipairs(out) do
        -- Carry the resolved item alongside the rule rather than mutating the rule table: an item
        -- blueprint's `ai` block is shared by every copy of that item ever instantiated, and writing
        -- through to it would bind the first wielder's weapon to everyone else's rule. The same
        -- reasoning is why a player's id string is resolved HERE and not written back over itself --
        -- the save file holds the id, and the live item is a fact about this turn.
        local item = AI.resolveItem(char, e.ref)
        rules[i] = { rule = e.rule, item = item, missing = e.ref ~= nil and item == nil }
    end
    return rules
end

-- How well a candidate matches the rule's stated targeting preference. A preference is a BIAS and
-- not a filter: "go for the weakest" should lose to a lethal blow on someone else, and would not if
-- it were allowed to discard candidates before scoring ever saw them.
local function prefBonus(ctx, rule, cand, w)
    local pref = rule.targetPref
    if not pref then return 0 end
    local t = cand.target
    if pref == "nearest" then
        local n = nearest(ctx, foes(ctx))
        return (t == n) and w.TARGET_PREF or 0
    elseif pref == "lowest_hp" or pref == "most_wounded" then
        local side = (t.side == ctx.unit.side) and allies(ctx) or foes(ctx)
        return (t == weakest(side)) and w.TARGET_PREF or 0
    elseif pref == "lethal" then
        return cand.lethal and w.TARGET_PREF or 0
    elseif pref == "self" then
        return (t == ctx.unit) and w.TARGET_PREF or 0
    elseif pref == "objective" then
        return (t == AI.objectiveUnit(ctx.combat, ctx.unit)) and w.TARGET_PREF or 0
    end
    return 0
end

-- ---------------------------------------------------------------------------
-- The decision
-- ---------------------------------------------------------------------------

function AI.plan(combat, unit)
    local Combat = require("models.combat")

    local pre = AI.preempt(combat, unit)
    if pre then return pre end

    local posture, postureName = AI.posture(unit)
    local items = itemsFor(combat, unit)
    local ctx = { combat = combat, unit = unit, items = items, posture = posture }

    -- Stand tiles: always where I am, plus everywhere I could walk to unless the posture is rooted.
    local tiles = { { x = unit.x, y = unit.y, steps = 0 } }
    if not posture.rooted then
        for _, node in pairs(Combat.reachable(combat, unit)) do
            tiles[#tiles + 1] = { x = node.x, y = node.y, steps = node.steps }
        end
    end

    -- A posture's weights override the defaults term by term, so it only has to name the handful it
    -- actually cares about. Built fresh each plan rather than by hanging a metatable on the posture's
    -- own table, which would quietly make a module constant mutable.
    local w = setmetatable({}, { __index = AI.WEIGHTS })
    for k, v in pairs(posture.weights or {}) do w[k] = v end
    local previews = {}
    local threat -- built lazily: a unit that never reaches the risk pass never pays for it
    local engaged = posture.engage(ctx)

    for index, entry in ipairs(AI.rulesFor(unit)) do
        local rule = entry.rule
        local act = rule.act or "attack"
        local isAction = act == "attack" or act == "support" or act == "cast"

        -- A rule that names an item is about THAT item and nothing else -- "when three foes cluster,
        -- throw the bomb" must not be satisfied by drawing a sword instead. A rule that names none
        -- considers the whole kit.
        --
        -- `missing` (named an item the character no longer carries) collapses to the same empty set
        -- as "carried but unusable", and deliberately so: both mean this rule cannot act, and the
        -- next one should get the turn. What neither may do is quietly fall back to the full kit.
        local usable = items
        if entry.missing then
            usable = {}
        elseif entry.item then
            usable = Combat.itemBlockReason(unit, entry.item) and {} or { entry.item }
        end

        if isAction and #usable > 0 and AI.matches(ctx, rule) then
            -- A posture that hasn't engaged yet may still look after itself and its allies; what it
            -- won't do is start a fight. That asymmetry is the whole of "hold until provoked".
            local mayAct = act ~= "attack" or engaged
            if mayAct then
                local pool = {}
                if act ~= "attack" then
                    for _, c in ipairs(AI.candidates(combat, unit, usable, tiles, true)) do pool[#pool + 1] = c end
                end
                if act ~= "support" then
                    for _, c in ipairs(AI.candidates(combat, unit, usable, tiles, false)) do pool[#pool + 1] = c end
                end

                if #pool > 0 then
                    for _, c in ipairs(pool) do
                        c.score = AI.scoreCandidate(combat, unit, c, w, previews)
                        c.score = c.score + prefBonus(ctx, rule, c, w)
                    end
                    -- Ties are broken toward standing still, then by board position, so that an
                    -- otherwise even choice is made the same way every run. A comparator that left
                    -- ties genuinely unordered would make this module's tests flap.
                    local function better(a, b)
                        if a.score ~= b.score then return a.score > b.score end
                        if a.steps ~= b.steps then return a.steps < b.steps end
                        if a.x ~= b.x then return a.x < b.x end
                        if a.y ~= b.y then return a.y < b.y end
                        if a.tx ~= b.tx then return a.tx < b.tx end
                        return a.ty < b.ty
                    end
                    table.sort(pool, better)

                    -- Risk pass over the shortlist. Only now is the threat map worth building.
                    threat = threat or select(2, Combat.threatMap(combat, unit.side, unit))
                    local shortlist = {}
                    for i = 1, math.min(#pool, AI.RISK_BUDGET) do
                        local c = pool[i]
                        c.score = c.score + AI.riskScore(combat, unit, c, w, threat)
                        shortlist[#shortlist + 1] = c
                    end
                    table.sort(shortlist, better)

                    local pick = shortlist[1]
                    -- Gate on `outcome`, not on the net score: an action has to accomplish something
                    -- to be worth a turn, but it does not have to be a bargain. See scoreCandidate.
                    if pick and pick.outcome > 0 then
                        return {
                            move = pick.moved and { x = pick.x, y = pick.y } or nil,
                            item = pick.item, tx = pick.tx, ty = pick.ty,
                            reason = string.format("%s rule %d (%s) -> %s, score %.1f",
                                postureName, index, AI.describeRule(rule),
                                pick.target.char.name or "target", pick.score),
                        }
                    end
                end
            end
        elseif act == "retreat" and AI.matches(ctx, rule) and not posture.rooted then
            local away = fallbackMove(ctx, "regroup")
            if away then away.reason = "rule " .. index .. ": retreat" return away end
        elseif act == "wait" and AI.matches(ctx, rule) then
            return { wait = true, reason = "rule " .. index .. ": wait" }
        end
    end

    -- No rule produced an action. Walk per the posture, or stand.
    if engaged and not posture.rooted then
        local move = fallbackMove(ctx, posture.move)
        if move then return move end
    end
    return { wait = true, reason = postureName .. ": nothing worth doing" }
end

-- A one-line account of why a plan is what it is, for the combat log and for authoring. Never nil.
function AI.explain(plan)
    if not plan then return "no plan" end
    return plan.reason or (plan.wait and "wait" or "act")
end

return AI
