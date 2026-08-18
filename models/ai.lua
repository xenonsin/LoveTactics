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
-- ...plus `strike = true` on the one action that is aimed at a THING rather than a body: a wall or a
-- prop standing between this unit and where it is trying to get (see AI.clearing). The battle state
-- routes that one through Combat.strikeObject instead of Combat.useItem, because a barrier is not a
-- target an ability can be "used on".
--
-- ...plus `reason`, a short human-readable string naming what decided it. That field is not
-- decoration and should not be dropped as an optimisation: a priority system whose choices can't be
-- read back is a priority system nobody can author against. It is the difference between tuning
-- this and guessing at it.

local Status = require("models.status")
local Hazard = require("models.hazard")
local Prop = require("models.prop")
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
    STANDOFF     = 0,     -- see AI.riskScore: only a kiter buys distance INSIDE a zone it can't leave
    HAZARD       = 4,     -- Hazard.tileBias + Prop.tileBias, already signed for my side (fire and a
                          -- live powder keg negative, sanctuary positive)
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
    local Combat = require("models.combat") -- lazily, as everywhere else here: models.combat requires us
    local best, bestD
    for _, u in ipairs(list) do
        -- Body to body, so a wide unit (on either side) is judged by its nearest cell, not its anchor.
        local d = Combat.unitGap(ctx.unit, u)
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
        local Combat = require("models.combat") -- lazily, as everywhere else here
        return anyOf(list, function(u) return Combat.unitGap(ctx.unit, u) <= (v or 1) end)
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
--
-- An acting rule may also carry `windup = n`: how deep to hold a CHARGEABLE wind-up (models/item.lua's
-- Item.windupRange), in total ticks, clamped by Combat.useItem to the ability's own range. Omitted, the
-- cast opens at the ability's floor -- which is what every enemy did before this existed, and why a
-- boss carrying a chargeable signature could only ever snap it at the minimum. It is a per-RULE number
-- rather than a scored one because the decision is "what is this rule for": a rule that fires at a
-- rooted foe wants the deepest hold on the board, and the same weapon aimed at something that can
-- still walk wants the shallowest, and no amount of tile scoring can tell those two apart.
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
    -- No band prefix any more: which rule gets the turn is answered by WHERE it sits in the list, so
    -- the sentence says what the rule does and the list says when it is reached.
    return "if " .. when .. " then " .. act
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

-- `desc` is the posture in the PLAYER's words, shown beside the name wherever a posture is offered
-- as a choice (ui/tactics_editor.lua's archetype list). It lives here, next to the behavior it
-- describes, because a description kept in the widget drifts from the code the first time somebody
-- changes an engage rule -- and this is the one field on the table that has to keep agreeing with the
-- other five.
AI.POSTURES = {
    -- Walks at the enemy and hits the best thing it can reach. The historical behavior, now with
    -- judgement about which thing that is.
    aggressive = {
        desc = "Goes looking for the fight. Closes on the enemy and hits the best thing it can reach,"
            .. " without waiting to be provoked.",
        rules = { SUPPORT_RULE, ATTACK_RULE },
        move = "approach",
        engage = function() return true end,
    },

    -- Holds until the fight comes to it, then commits. This is Fire Emblem's activation rule, and it
    -- is what lets a map be authored with quiet corners: a room full of `defensive` guards is a room
    -- the player can choose when to open, rather than a timer.
    defensive = {
        desc = "Waits. It holds where it stands until the fight comes to it -- struck, or with someone"
            .. " on the ground it was posted to hold -- and then commits without abandoning that post.",
        rules = { SUPPORT_RULE, ATTACK_RULE },
        -- `defend`, not `approach`: a defender walks to its POST and stops there. The old `approach`
        -- was written for a posture that had nothing to defend -- once provoked it committed like an
        -- aggressor and chased, which on a map with an objective means abandoning the only tile that
        -- mattered to go trade blows somewhere else. See AI.post and fallbackMove's `defend` mode.
        -- With no post to take (a plain killAll) it degrades to exactly that old approach.
        move = "defend",
        defends = true, -- AI.plan reads a post for this posture, and leashes its stand tiles to it
        engage = function(ctx)
            if hpFraction(ctx.unit) < 1 then return true end -- someone already shot at me
            -- Somebody is on the ground I am here to hold. A post being contested IS the fight
            -- starting, whether or not the contester has come within my own reach yet.
            if ctx.post then
                for _, other in ipairs(ctx.combat.units) do
                    if other.alive and other.side ~= ctx.unit.side
                        and AI.atPost(other.x, other.y, ctx.post) then return true end
                end
            end
            local Combat = require("models.combat")
            for _, item in ipairs(ctx.items) do
                -- HOSTILE reach only. Counting a support item here meant a unit engaged because it
                -- could drink its own potion (an `ally` ability's target list includes the caster),
                -- so every defender carrying one activated on turn 1 and the posture never actually
                -- held anything -- masking, for as long as the campaign kit carried a potion, the
                -- fact that a stripped draft body freezes instead.
                if not Combat.isSupportAbility(item.activeAbility)
                    and #Combat.abilityTargets(ctx.combat, ctx.unit, item) > 0 then return true end
            end
            return false
        end,
    },

    -- Never leaves the tile it was put on. A sentry, a turret, a boss that owns a throne room.
    holdGround = {
        desc = "Never leaves the tile it starts on. It strikes whatever comes into reach and lets"
            .. " everything else walk past: a sentry, a turret, a boss on its throne.",
        rules = { ATTACK_RULE },
        move = "hold",
        rooted = true,
        engage = function() return true end,
    },

    -- Leashed: pursues within `leash` tiles of where it started and goes home once past it. The
    -- posture that makes a patrol readable -- the player can bait it out and see it disengage.
    guard = {
        desc = "Chases, but only so far. It pursues within four tiles of where it started and walks"
            .. " home once past that, so it can be baited off its ground and seen to give up.",
        rules = { SUPPORT_RULE, ATTACK_RULE },
        move = "leash",
        leash = 4,
        engage = function() return true end,
    },

    -- Wants distance. Same rules as an aggressor, opposite footwork: EXPOSURE is dear and closing is
    -- actively penalised, so an archer that can shoot from six tiles will not stroll to three.
    --
    -- STANDOFF is the only posture that buys it (see AI.riskScore). EXPOSURE is a count and therefore
    -- a cliff -- once a foe is quick enough to threaten every tile, it is the same number everywhere
    -- and stops arguing for range at all. STANDOFF is the slope underneath it, and it is what keeps
    -- this archer shooting from four tiles instead of closing to punch when it cannot get clear.
    skirmish = {
        desc = "Wants the distance its weapon has. It shoots from as far out as it can and gives"
            .. " ground rather than closing: an archer who can hit from six tiles will not stroll to"
            .. " three.",
        rules = { SUPPORT_RULE, ATTACK_RULE },
        move = "kite",
        weights = { EXPOSURE = 5, STEPS = 0.1, COUNTER = 2.5, STANDOFF = 6 },
        engage = function() return true end,
    },

    -- Reads its allies before its enemies. Nothing in the old planner ever pointed a heal at
    -- anything, so an enemy healer's kit was decoration; this is the posture that makes it a threat.
    support = {
        desc = "Reads its allies before its enemies. It heals whoever is worst off first, and only"
            .. " turns on the enemy when nobody needs it.",
        rules = {
            { act = "support", when = { subject = "any_ally", test = "hp_pct_below", value = 0.9 },
              targetPref = "lowest_hp" },
            ATTACK_RULE,
        },
        move = "regroup",
        weights = { HEAL = 1.8, EXPOSURE = 3 },
        engage = function() return true end,
    },

    -- Walks for the exit and nothing else. The escortee's posture: it never starts a fight, never
    -- steps aside to trade a blow -- it spends every turn closing on the ground the objective names,
    -- and leaves the killing to whoever is escorting it. The empty rule list is the whole point: with
    -- no rule to fire, AI.plan drops straight to `advance`, so the column is a clock the party has to
    -- keep the road ahead of, not a combatant that can be baited into stopping.
    --
    -- The opposite of `defensive`, which is the other half of an escort's design space: a defensive
    -- charge is a thing you stand around, an advancing one is a clock you cannot pause. Slot 1 of the
    -- Bastion's line uses both -- the column presses on up the mountain, and digs in at the gate.
    escort = {
        desc = "Walks for the objective and nothing else. It never starts a fight and never stops to"
            .. " trade a blow, which makes it a clock rather than a combatant.",
        rules = {},
        move = "advance",
        engage = function() return true end,
    },

    -- Plays the map rather than the bodies: goes for whoever the objective names, and falls back to
    -- ordinary aggression on a map whose objective has no unit to point at (a plain killAll).
    objective = {
        desc = "Plays the map rather than the bodies. It goes for whoever the objective names and"
            .. " walks past easier targets to get there; on a map that names nobody, it fights like an"
            .. " aggressor.",
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

-- The order the postures are OFFERED in. Not the declaration order and deliberately not alphabetical:
-- it runs from the posture that goes looking for the fight to the one that will not have it at all, so
-- the list reads as a scale and a player scanning it can stop where their answer is. Every posture
-- belongs here -- one missing from this list is one the player cannot choose (tactics_editor_spec
-- checks the two agree).
AI.POSTURE_ORDER = {
    "aggressive", "objective", "skirmish", "support", "guard", "defensive", "holdGround", "escort",
}

-- A posture's name as the UI says it: `holdGround` is one word to Lua and two to a reader, and the
-- absence of a posture is a name of its own rather than a blank.
function AI.postureLabel(name)
    if not name then return "default" end
    return (tostring(name):gsub("(%l)(%u)", "%1 %2"):gsub("_", " "):lower())
end

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
-- Sparing the escortee
-- ---------------------------------------------------------------------------
--
-- The body a `protect` clause names is the softest thing on the board by construction -- a survivor
-- with 24 health and no armour, a wagon that cannot swing back -- and the scorer prices a soft body
-- exactly the way it should: a blow that lands 10 through a villager's coat beats one that scrapes 2
-- off a knight's, and STEPS is a quarter-point a tile, so four tiles of walking buys that trade
-- outright. Every demon on the board therefore ignores the wall the player just built and converges on
-- the one body the player cannot move, which is the best play available and an unreadable fight to be
-- on the wrong side of. The escort maps of the flight leg and the relief of Highwatch all played that
-- way, and the encounters' own comments describe the behavior they were authored for -- "aggressive
-- demons walk for the nearest enemy" -- rather than the behavior they got.
--
-- So the escortee is SPARED: it is not a mark this unit may walk past somebody to reach. Not a weight,
-- because a weight is a knob that has to be re-guessed every time a protectee's health changes, and
-- because what is wanted here is not "the caravan is worth less" -- it is worth the whole battle --
-- but "you have to come through me first", which is a statement about geometry and reads as one.
-- Nothing nearer than the escortee, and it is fair game again: screening it is the player's job, and a
-- gap left open is supposed to cost.
--
-- ...IN THE CAMPAIGN ONLY. Across a draft or a duel there is a person on the other side playing to
-- win, and going for the body that ends the match is simply the right move -- handicapping the
-- opponent because their win condition is fragile would be the game cheating on the player's behalf.
-- `combat.versus` is what tells the two apart (see Combat.new).

-- The body the map's `protect` clause names, seen from `unit`'s side of the board: the escortee whose
-- death ends the battle outright (Combat.resolveObjective). Deliberately narrower than
-- AI.objectiveUnit, which also answers to an assassination's `target` -- a mark is a foe like any
-- other and nobody is asking the AI to spare one.
function AI.protectee(combat, unit)
    local id = combat.objective and combat.objective.protect
    if not id then return nil end
    for _, u in ipairs(combat.units) do
        if u.alive and u.char.id == id and not u.summoned and u.side ~= unit.side then return u end
    end
    return nil
end

-- The body `unit` leaves alone this turn, or nil -- which is the answer on almost every board, since
-- most maps protect nobody. Read ONCE per plan and carried on the ctx: it is a fact about where the
-- unit is standing at the top of its turn, and re-asking it per candidate would let a unit walk two
-- tiles toward the caravan, find the caravan nearest from there, and hit it after all.
function AI.spared(combat, unit)
    if combat.versus then return nil end
    local body = AI.protectee(combat, unit)
    if not body then return nil end

    local Combat = require("models.combat")
    -- Body to body, the same measure `nearest_foe` is resolved by, so "the nearest foe" means one
    -- thing across the module and a wide body is judged by its closest cell either way.
    local gap = Combat.unitGap(unit, body)
    for _, u in ipairs(combat.units) do
        if u.alive and u ~= body and u.side ~= unit.side and not Status.untargetable(u)
            and Combat.unitGap(unit, u) < gap then
            return body -- somebody is standing closer: the escortee is screened
        end
    end
    return nil -- nothing nearer, so the escortee IS the nearest foe and there is nothing to spare it from
end

-- A rule that NAMES the objective means it. `targetPref = "objective"` and the `objective_unit`
-- subject are both an author writing down "go for the thing this map is about" -- the `objective`
-- posture is nothing else -- and sparing is a default, not a veto over what somebody wrote.
local function namesObjective(rule)
    return rule.targetPref == "objective"
        or (rule.when ~= nil and rule.when.subject == "objective_unit")
end

-- The nearest tile of the ground the objective names. Read through Combat.objectiveGround rather
-- than off `obj.tiles` directly, because the ground an objective is decided on is not always the
-- authored region: a `control` node follows its own moving waypoint and a `defend` follows the body
-- it is fought over. Reading the raw field saw only the authored kind, so an AI on a draft control
-- map was blind to the very tile the match is scored on.
--
-- This is the positional handle an escort needs and `objectiveUnit` cannot give: a wagon column is
-- not walking toward a body, it is walking toward the exit.
--
-- Nil when the objective names no ground (killAll, assassinate, survive), which is what makes the
-- `advance` mode fall back to ordinary approach instead of freezing.
function AI.objectiveTile(combat, unit)
    return AI.nearestTile(unit, require("models.combat").objectiveGround(combat))
end

-- The nearest of `tiles` to `unit`, or nil for an empty list. Board order decides a tie, so two
-- clients walking the same list pick the same tile.
function AI.nearestTile(unit, tiles)
    local best, bestD
    for _, t in ipairs(tiles or {}) do
        local d = manhattan(unit.x, unit.y, t.x, t.y)
        if not bestD or d < bestD then best, bestD = t, d end
    end
    return best
end

-- ---------------------------------------------------------------------------
-- The post: what a defender is standing there FOR
-- ---------------------------------------------------------------------------
--
-- `defensive` is not "hits back when hit" -- it is the posture of a unit assigned to something. What
-- that something is comes first from the OBJECTIVE, because the objective knows what the fight is
-- about: on an assassination the boss's guards are there for the boss, on a control map the bodies
-- around the node are there for the node. Without that reading a defender is just an aggressor with a
-- broken activation rule -- it stands wherever it was spawned and calls it a defence, which is what
-- left a drafted knight rooted in a corner of a control match.
--
-- ...and when the objective names nothing at all -- a killAll, which is most maps -- the side itself
-- is asked instead (AI.charge): there is still obviously somebody a squad cannot afford to lose, and
-- a wall that plants itself in front of its own healer is playing the same game either way. Only when
-- nobody qualifies is there no post, and then this is the hold-until-provoked posture it always was.
--
-- A post is `{ tiles, radius, what }`: the ground being held and how far off it the holder may stand.

-- How far from a BODY it guards a defender will station itself. Two tiles is a picket around the
-- charge rather than a huddle on top of it -- close enough that anything reaching the charge has to
-- come through the guard, loose enough that a throne room's guards do not all crowd one doorway.
AI.POST_RADIUS = 2

-- The living body on `unit`'s own side with this blueprint id, or nil.
--
-- Matched through a transform for the same reason Combat's assassinate check is: a general who sheds
-- its human body for its demon one is the same unit in a new shape, and its guards must not lose
-- their post the moment it phases.
local function allyNamed(combat, unit, id)
    if not id then return nil end
    local Transform = require("models.transform")
    for _, u in ipairs(combat.units) do
        if u.alive and u.side == unit.side and not u.summoned then
            local original = Transform.originalChar(u)
            if u.char.id == id or (original and original.id == id) then return u end
        end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Who is worth guarding: the charge ranking
-- ---------------------------------------------------------------------------
--
-- A bodyguard whose charge is a hard-coded id is only ever right for one battle. On a map the
-- objective names nobody -- a plain killAll, which is most of them -- there is still obviously
-- somebody the side cannot afford to lose, and every reader of the board can point at them: the
-- healer, the boss, the unarmed charge, the player's own body. `guards = "priority"` is a unit
-- saying "I stand in front of whoever that is", and this ranking answers it.
--
-- What qualifies is what a body CANNOT DO FOR ITSELF, never how dangerous it is. A hitter that can
-- swing back is not a charge however valuable it is -- guarding it would just be two units standing
-- where one was. So a plain fighter scores zero, and a side of nothing but fighters produces no
-- charge at all: the guard keeps the ordinary hold-until-provoked behavior rather than inventing an
-- assignment. That refusal is the point. Without it every defensive unit on the map picks the
-- nearest warm body and the posture stops meaning anything.
--
-- Every term is a STABLE fact -- id, boss flag, what the kit contains, max health. Deliberately not
-- current hp, not distance, not who is winning: a guard that re-picks its charge as the fight moves
-- oscillates between two posts and defends neither, which reads on screen as a unit pacing in a
-- circle while its side dies around it.
AI.CHARGE_WEIGHTS = {
    -- The `protect` clause: the one term allowed above the avatar, and it earns that by being the
    -- same KIND of fact rather than a bigger version of a smaller one. `obj.protect` is not the map
    -- naming somebody interesting -- it is a LOSS CONDITION (Combat.resolveObjective returns "loss"
    -- outright the moment that body falls, whatever the win type is), and the body it names is by
    -- construction one nobody is steering: an escorted caravan, a witness, a driver on rails.
    --
    -- So the tie-break against AVATAR is not "which body is worth more" but "which body can do
    -- anything about it". Both deaths end the battle; the player has a hand on their own and can
    -- simply walk out of the fire, and the caravan has nobody at all. A bodyguard who stands in
    -- front of the one body already being driven, while the one on rails is swarmed across the
    -- board, is guarding the wrong thing -- and that is exactly what the escort legs of the relief
    -- of Highwatch played like before this term existed.
    PROTECT      = 250,
    -- The player's own body ends the run when it falls, so nothing outranks it but the clause above
    -- -- deliberately larger than every other term ADDED TOGETHER, because a boss-healer ally would
    -- otherwise out-total it and walk Rowan away from the one body the game is about.
    AVATAR       = 200,
    BOSS         = 60,   -- the fight is authored around it
    OBJECTIVE    = 50,   -- the body the map names on our side WITHOUT staking the battle on it: an
                         -- assassination's mark, a `reach` objective's walker. Heard, never decisive
    SUPPORT      = 40,   -- the healer. Kill it and the whole side dies slower but just as surely
    NONCOMBATANT = 30,   -- carries nothing hostile: an escortee, a driver, a witness
    FRAGILE      = 10,   -- a tie-break SLOPE among bodies that already qualify, never a qualification
}

-- The avatar is the created player character (data/characters/character_avatar.lua) -- named here
-- rather than sniffed for, because "is this the player's body" has exactly one answer and a guessed
-- one (lowest hp? first in the party?) would be wrong on the day it mattered.
AI.AVATAR_ID = "character_avatar"

-- Max health at or above which a body reads as able to look after itself, for the FRAGILE slope.
-- Around a knight's (68): the wall is the thing that does the guarding, not the thing guarded.
AI.FRAGILE_BENCH = 70

-- How much `ally` needs someone standing in front of it, from `unit`'s side of the board. Zero for a
-- body that qualifies for nothing, which is the answer that keeps this from inventing charges.
function AI.chargeScore(combat, unit, ally)
    local Combat = require("models.combat")
    local w, char = AI.CHARGE_WEIGHTS, ally.char
    local score = 0

    if char.id == AI.AVATAR_ID then score = score + w.AVATAR end
    if char.boss then score = score + w.BOSS end

    -- What the map says about this body, in its two quite different strengths. Both read through
    -- allyNamed rather than an id compare, so a charge that has transformed is still the charge --
    -- the same reason the post lookup below matches that way.
    --
    -- Scored as two independent questions rather than the `or` chain this used to be. That chain
    -- only ever consulted the FIRST field the objective happened to set, so a map naming both a mark
    -- and an escortee silently dropped one of them -- and, worse, it flattened a loss clause and a
    -- piece of flavour into the same 50 points.
    local obj = combat.objective
    if obj then
        -- The clause that loses the battle. See AI.CHARGE_WEIGHTS.PROTECT for why it is the one
        -- thing allowed to outrank the player's own body.
        if allyNamed(combat, unit, obj.protect) == ally then score = score + w.PROTECT end
        -- ...and the softer naming: the mark, the walker. An explicit assignment worth hearing, but
        -- the battle is not staked on either of them, so neither shouts down the run.
        if allyNamed(combat, unit, obj.target) == ally
            or allyNamed(combat, unit, obj.who) == ally then
            score = score + w.OBJECTIVE
        end
    end

    -- Read the KIT, not the class name: a body is a healer because it is carrying heals, and a
    -- non-combatant because it is carrying nothing to hit with. `unarmed` is excluded on purpose --
    -- every body has fists and none of them are a reason to call it a combatant.
    --
    -- A one-shot does not make a healer. Every frontliner in the game carries a healing potion, and
    -- counting it here made a swordsman with a belt pouch rank as the body the side cannot replace --
    -- the same false positive the `defensive` engage test names, arriving by a different door. What
    -- qualifies is a REPEATABLE support ability: a kit, not a pocket.
    local supports, strikes = false, false
    for _, item in ipairs(Combat.abilityItems(char)) do
        local ab = item.activeAbility
        if ab then
            if not Combat.isSupportAbility(ab) then
                strikes = true
            elseif not ab.consumesItem then
                supports = true
            end
        end
    end
    if supports or char.archetype == "support" then score = score + w.SUPPORT end
    if not strikes then score = score + w.NONCOMBATANT end

    if score <= 0 then return 0 end

    -- ...and only now, between two bodies that both qualify, does being easy to kill separate them.
    local _, max = hp(ally)
    local bench = AI.FRAGILE_BENCH
    score = score + w.FRAGILE * math.max(0, math.min(1, (bench - max) / bench))
    return score
end

-- The body on `unit`'s side most in need of a shield, or nil when nobody qualifies. Board order
-- breaks a tie, so two guards reading the same board pick the same charge and ring it together
-- instead of splitting up.
function AI.charge(combat, unit)
    local best, bestScore
    for _, u in ipairs(combat.units) do
        if u.alive and u ~= unit and u.side == unit.side and not u.summoned then
            local score = AI.chargeScore(combat, unit, u)
            if score > 0 and (not bestScore or score > bestScore) then best, bestScore = u, score end
        end
    end
    return best
end

-- The body this unit is posted to. Three ways one is named, in this order:
--
--   1. the unit's OWN blueprint names an id -- `guards = "character_avatar"`, a standing assignment
--      that travels with the body from map to map and answers to nothing else.
--   2. the unit's blueprint asks for the ranking OUTRIGHT -- `guards = "priority"`. Every defensive
--      unit reaches the ranking eventually (see AI.post); what this buys is reaching it FIRST, ahead
--      of the ground the map is scored on. That is exactly the difference between a bodyguard and a
--      guard: told to hold a node, an ordinary defender holds the node, and Rowan stands in front of
--      you and lets the node be someone else's job. It resolves to the player wherever the player
--      stands (see AI.CHARGE_WEIGHTS).
--   3. the OBJECTIVE, for everyone else: the one it names that stands on ITS OWN side. The mirror of
--      `objectiveUnit`, which deliberately returns the far-side one -- an escorted charge is a thing
--      to cut down if you are the enemy and a thing to ring if you are its escort, and the two
--      readings are the same lookup with the side test flipped.
--
-- The blueprint outranks the map because the two assignments are different KINDS of fact: what the
-- objective names is what this battle is about, and what a bodyguard guards is what that unit is. A
-- sworn shield standing on a control node has not stopped being a bodyguard -- the node is what the
-- rest of the party is for. (The ranking still READS the objective, at OBJECTIVE weight, so a map
-- that does name a charge is heard -- it just doesn't get to shout down the avatar.) Nil here is not
-- "no post": AI.post falls on to the ground the objective names, and then to the ranking.
AI.GUARD_PRIORITY = "priority"

function AI.postedUnit(combat, unit)
    local sworn = unit.char and unit.char.guards
    if sworn == AI.GUARD_PRIORITY then return AI.charge(combat, unit) end
    local named = allyNamed(combat, unit, sworn)
    if named then return named end

    local obj = combat.objective
    if not obj then return nil end
    return allyNamed(combat, unit, obj.target or obj.protect or obj.who)
end

local function bodyPost(body)
    return { tiles = { { x = body.x, y = body.y } }, radius = AI.POST_RADIUS,
             what = body.char.name or "the charge" }
end

-- Where `unit` is posted, or nil when there is genuinely nobody and nothing to stand in front of.
--
-- Read in the order of how explicit the assignment is, because a more explicit one being overruled
-- by a vaguer one is always a bug:
--
--   1. a NAMED body -- the unit's own `guards`, or the one the objective names on our side.
--   2. the objective's GROUND -- the node, the hold tiles. This outranks the ranking below: what the
--      map is scored on is not a guess, and a defender that rings its healer while the other side
--      banks the node has lost the battle it was winning.
--   3. the charge RANKING -- whoever the side cannot afford to lose (AI.charge). The fallback for
--      every map that names neither, which is most of them: a killAll used to leave a `defensive`
--      unit with no post at all, standing wherever it spawned until something walked into reach. It
--      still ends up with no post when nobody on its side qualifies -- a squad of pure hitters is
--      exactly the "quiet corner" case, and it plays as it always did.
--
-- A BODY outranks GROUND: a guard follows what it guards, and a `defend` objective resolves to its
-- protectee's tile anyway, so reading the body first is also what keeps a walking charge's picket
-- walking with it instead of standing on the square it left.
function AI.post(combat, unit)
    local body = AI.postedUnit(combat, unit)
    if body then return bodyPost(body) end
    -- ...with one piece of ground that is nobody's post but its owner's. A `defend` objective's ground
    -- IS the protectee's own tiles (Combat.objectiveGround), so on an escort map the far side reads
    -- "hold the objective" as "go and stand on the caravan" -- the very beeline AI.spared exists to
    -- stop, arriving through the movement layer instead of the targeting one. A node or a hold region
    -- is ground either side can occupy; a body is not. Falls through to the charge ranking below, so a
    -- defensive attacker on an escort map guards its own the way it would on a killAll.
    local ground = require("models.combat").objectiveGround(combat)
    local theirCharge = combat.objective and combat.objective.type == "defend"
        and AI.protectee(combat, unit) ~= nil
    if #ground > 0 and not theirCharge then
        -- Radius 0, not a ring: this ground is held by STANDING on it. A control node only banks its
        -- tick for the side actually occupying it and a `hold` counts the same way, so a defender
        -- who parks one tile short of the post has not taken the post, however defensive it looks.
        return { tiles = ground, radius = 0, what = "the objective" }
    end
    local charge = AI.charge(combat, unit)
    if charge then return bodyPost(charge) end
    return nil
end

-- Is (x, y) close enough to `post` to count as manning it?
function AI.atPost(x, y, post)
    if not post then return true end
    for _, t in ipairs(post.tiles) do
        if manhattan(x, y, t.x, t.y) <= post.radius then return true end
    end
    return false
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
        -- A HARMLESS ability (the Assayer's Eye) never enters an AI plan. Its payload is knowledge
        -- for the side reading the screen, so an enemy that cast one would spend a whole turn buying
        -- itself nothing -- and every layer below takes it for a strike it can afford, which is worse:
        -- the `defensive` posture would count it as hostile reach and break its hold to go and look at
        -- somebody. Dropped here, at the one seam every candidate is enumerated from, so engage,
        -- candidates and firingSolution are all answered at once.
        if not Combat.itemBlockReason(unit, item)
            and not Combat.isHarmlessAbility(item.activeAbility) then
            out[#out + 1] = item
        end
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
            local considered = ab and Combat.isSupportAbility(ab) == wantSupport
            if considered and ab.target == "self" then
                -- A SELF-targeted ability has exactly one legal mark -- the caster -- aimed at the tile
                -- it would be STANDING on, not the one it stands on now. Enumerated apart from the scan
                -- below because that scan asks "which body is within range of this stand tile", and for
                -- a self-cast walked to from four tiles away the answer is a body that hasn't moved
                -- there yet: every tile but the current one measures its own distance to the caster's
                -- old cell and fails. Worse for a HOSTILE self-cast (`support = false` -- Clear Out, the
                -- Bomblet's Self-Destruct), which the scan only ever offers FOES, and no foe is ever at
                -- range 0 of itself: without this the ability sits in the kit and enters no plan at all.
                --
                -- The one cost is that a self-cast is priced once per reachable tile rather than once
                -- (Combat.previewAbility is memoised by aim cell, and here the aim cell IS the stand
                -- tile). That is the price of letting a unit walk somewhere worth detonating, and it
                -- falls only on the handful of units carrying one.
                out[#out + 1] = {
                    x = tile.x, y = tile.y, steps = tile.steps or 0,
                    item = item, target = unit, tx = tile.x, ty = tile.y,
                    moved = tile.x ~= unit.x or tile.y ~= unit.y,
                }
            elseif considered then
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
                        -- Aim at the target's cell nearest this stand tile, not its anchor, so a wide
                        -- mark is struck from beside its closest edge -- and so Combat.useItem's range
                        -- re-check (measured to this same cell) agrees the shot is legal.
                        local tcx, tcy = Combat.nearestCell(tile.x, tile.y, t)
                        local d = manhattan(tile.x, tile.y, tcx, tcy)
                        if d <= range and d >= minRange
                            and (not ab.requiresSight
                                 or Combat.hasLineOfSight(combat, tile.x, tile.y, tcx, tcy)) then
                            out[#out + 1] = {
                                x = tile.x, y = tile.y, steps = tile.steps or 0,
                                item = item, target = t, tx = tcx, ty = tcy,
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
    local Item = require("models.item")
    -- A PURCHASABLE ability (Aurea's Gilded Wound) does nothing until it is paid for, so the scorer must
    -- price the blow the caster INTENDS to buy: pour up to the ability's own ceiling, bounded by the coffer
    -- on hand. Carried onto the candidate so the chosen action pours the same gold into the live cast, and
    -- folded into the memo key so a differently-funded preview is not read off a stale one.
    local spend
    if Item.isPurchasable(cand.item.activeAbility) then
        local rate, cap = Item.purchaseRate(cand.item.activeAbility)
        spend = math.min(cap, math.floor(Combat.purseAvailable(combat, unit) / rate)) * rate
    end
    cand.spend = spend
    local memo = cand.item.id or tostring(cand.item)
    local k = memo .. "@" .. cand.tx .. "," .. cand.ty .. "$" .. tostring(spend or 0)
    local preview = previews[k]
    if preview == nil then
        preview = Combat.previewAbility(combat, unit, cand.item, cand.tx, cand.ty, nil, nil, spend) or false
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

    -- Ground bias: the zones under this tile, plus any powder keg near enough to reach it. One term,
    -- because they are one judgement -- "do I want to be standing here when my turn ends" -- and a
    -- planner that weighed fire but strolled into a barrel's blast would read as the same mistake.
    score = score + (Hazard.tileBias(combat, cand.x, cand.y, unit.side)
        + Prop.tileBias(combat, cand.x, cand.y)) * w.HAZARD
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
    if src then
        risk = risk + #src * w.EXPOSURE

        -- STANDOFF: how close the nearest threat actually is, and the term that keeps a kiter kiting
        -- when there is nowhere safe left to stand.
        --
        -- EXPOSURE alone is a COUNT of enemies who could reach the tile, which makes it a cliff rather
        -- than a slope: a tile is threatened or it isn't. That reads correctly right up until an enemy
        -- is fast enough to reach everywhere -- and then every candidate carries the identical
        -- exposure, the term stops discriminating entirely, and an archer who could shoot from four
        -- tiles walks into arm's reach and punches instead, because at that point nothing in the score
        -- was still arguing for distance. Raising base movement to 4 made that common enough to see.
        --
        -- So: a foe in your face is worth the full weight, one four tiles off a quarter of it. The
        -- reciprocal is self-limiting (it can never exceed STANDOFF) and it is a slope, so it still
        -- separates two tiles that are both doomed -- which is the entire situation this exists for.
        --
        -- Zero for everyone but the `skirmish` posture. A wall does not want distance and a berserker
        -- resents it; only a kiter is buying range, and it should only be buying it from inside a zone
        -- it has already failed to escape. An untouched tile never reaches this branch at all.
        if w.STANDOFF > 0 then
            local closest
            for _, s in ipairs(src) do
                local d = manhattan(cand.x, cand.y, s.x, s.y)
                if not closest or d < closest then closest = d end
            end
            risk = risk + w.STANDOFF / math.max(1, closest or 1)
        end
    end

    return -risk
end

-- ---------------------------------------------------------------------------
-- Movement fallbacks
-- ---------------------------------------------------------------------------

-- The tile to walk to when no rule produced an action, per the posture's `move` mode. Returns a
-- plan descriptor or nil. Never returns a move that fails to improve the unit's situation, so a
-- unit with nothing to do stands still instead of pacing.
-- Ranking a tile the goal has NO road from: behind every tile that has one, and among themselves by
-- the straight line -- so a unit sealed off entirely still presses as close as the geometry allows
-- instead of freezing, which is what the approach did before it could read roads at all.
local SEALED = 1e6

local function roadCost(field, x, y, goal)
    local Combat = require("models.combat")
    return field[x .. "," .. y] or (SEALED + Combat.cellGap(x, y, goal))
end

-- The blow an approach takes when the WAY ITSELF is the problem: tear down the wall, or break the
-- prop, standing between this unit and whatever it is trying to reach.
--
-- What a blocker is WORTH is measured rather than guessed. Field the road twice -- once honestly, once
-- as though that one object were already gone (Combat.travelField's `ignore`) -- and the difference is
-- the walking this unit saves by breaking it. An object that changes nothing was never the obstruction
-- (some other wall was, or the terrain is), and no swing is taken at it. That is what puts a sealed-in
-- unit's axe into the one panel that opens its road rather than whichever one it happens to face.
--
-- Then the trade, which is the whole judgement in one line: BREAKING BUYS TILES AND COSTS TURNS, and a
-- turn spent swinging is a turn not spent walking. So the road saved has to beat what those same turns
-- would have covered on foot -- `gain > turnsToBreak * this unit's stride`. Three consequences fall out
-- of that one comparison, and none of them needs its own rule:
--
--   * A barrel beside an open road saves nothing and is left alone. A planner that broke whatever it
--     could reach would turn every furnished board into a demolition derby.
--   * A barrier with a walkable detour is smashed only when the detour is genuinely worse than the
--     axework -- which is exactly the case a player builds a wall to create.
--   * Anything that seals the road entirely scores in the thousands (see SEALED) and is always worth
--     breaking, because no number of turns walking gets there at all.
--
-- Returns a plan { move?, item, tx, ty, strike = true }, or nil.
function AI.clearing(ctx, goal, here)
    local Combat = require("models.combat")
    local combat, unit = ctx.combat, ctx.unit

    -- Everything standing that bars a body, walls before props -- the order Combat.objectAt reads the
    -- two layers in, so a tie between one of each is broken the same way every run.
    local blockers = {}
    for _, w in ipairs(combat.walls or {}) do
        if w.alive and w.blocksMove then blockers[#blockers + 1] = w end
    end
    for _, p in ipairs(combat.props or {}) do
        if p.alive and p.blocksMove then blockers[#blockers + 1] = p end
    end
    if #blockers == 0 then return nil end

    -- Can this unit actually hit that thing this turn, and with what? The same reach test AI.candidates
    -- makes of a body, asked of a tile: every stand tile it could be on (ctx.tiles, so a blow may follow
    -- a walk) against every item it can afford. Ranked by the damage the blow lands -- Combat.strikeWall
    -- and strikeProp both price it as computeTrapDamage, the weapon's attack stat -- then by the shortest
    -- walk, so the axe comes out rather than the fists and the unit does not stroll to swing.
    local function firingSolution(obj)
        local best
        for _, tile in ipairs(ctx.tiles or {}) do
            for _, item in ipairs(ctx.items or {}) do
                local ab = item.activeAbility
                if ab and not Combat.isSupportAbility(ab) then
                    local range = Combat.abilityRange(combat, unit, ab, tile.x, tile.y)
                        + Combat.adjacencyRangeBonus(unit.char, item)
                    local d = manhattan(tile.x, tile.y, obj.x, obj.y)
                    if d <= range and d >= Combat.abilityMinRange(ab)
                        and (not ab.requiresSight
                             or Combat.hasLineOfSight(combat, tile.x, tile.y, obj.x, obj.y)) then
                        local dmg = Combat.computeTrapDamage(unit, item)
                        local steps = tile.steps or 0
                        if not best or dmg > best.dmg or (dmg == best.dmg and steps < best.steps) then
                            best = { tile = tile, item = item, dmg = dmg, steps = steps }
                        end
                    end
                end
            end
        end
        return best
    end

    -- What a turn of walking is worth to THIS body, which is what the turns spent breaking are priced
    -- against. Floored at 1 so a rooted or crippled unit -- for whom walking buys nothing at all --
    -- still gets to break its way out rather than dividing by zero and standing there.
    local stride = math.max(1, Combat.flatStat(unit, "movement") or 1)

    local pick
    for _, obj in ipairs(blockers) do
        -- Reach is asked FIRST: it is a handful of comparisons, where pricing the road is a whole
        -- Dijkstra, and on most boards nothing breakable is in reach at all.
        local shot = firingSolution(obj)
        if shot then
            local without = Combat.travelField(combat, unit, goal, obj)
            local gain = here - roadCost(without, unit.x, unit.y, goal)
            -- Turns of axework: what it still has standing, over what one blow takes off it. The blow
            -- this unit would actually throw, so a heavy hitter breaks through where a fists-only
            -- straggler correctly decides it is not worth its afternoon.
            local turns = math.ceil(math.max(1, obj.health or 1) / shot.dmg)
            if gain > turns * stride
                and (not pick or gain > pick.gain
                     or (gain == pick.gain and shot.steps < pick.shot.steps)) then
                pick = { obj = obj, shot = shot, gain = gain }
            end
        end
    end
    if not pick then return nil end

    local tile, name = pick.shot.tile, pick.obj.name or "an obstacle"
    return {
        move = (tile.x ~= unit.x or tile.y ~= unit.y) and { x = tile.x, y = tile.y } or nil,
        item = pick.shot.item, tx = pick.obj.x, ty = pick.obj.y,
        -- The one field that tells the battle state this action is aimed at a THING, not a body.
        strike = true,
        reason = pick.gain >= SEALED
            and ("clearing the way: " .. name .. " is the only way through")
            or string.format("clearing the way: %s (saves %d)", name, pick.gain),
    }
end

local function fallbackMove(ctx, mode)
    local Combat = require("models.combat")
    local unit, combat = ctx.unit, ctx.combat
    if mode == "hold" then return nil end

    local goal
    if mode == "defend" then
        -- Man the post, then stop. Already at it -- nil: holding IS the move, and a defender that
        -- kept closing would walk off the ground it just took. With no post to man (killAll names
        -- nothing to defend) this is an ordinary approach, which is what the posture used to be.
        if not ctx.post then
            goal = nearest(ctx, foes(ctx))
        elseif AI.atPost(unit.x, unit.y, ctx.post) then
            return nil
        else
            goal = AI.nearestTile(unit, ctx.post.tiles)
        end
    elseif mode == "objective" then
        goal = AI.objectiveUnit(combat, unit) or nearest(ctx, foes(ctx))
    elseif mode == "advance" then
        -- Toward the exit, not toward the fight. An escorted column is trying to LEAVE, and every
        -- turn it spends walking is a turn the party has to keep the road ahead of it clear. Falls
        -- back to approach on an objective that names no ground, so the posture is never inert.
        goal = AI.objectiveTile(combat, unit) or nearest(ctx, foes(ctx))
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

    -- How far the goal is FROM A TILE, by the road rather than by the crow's line. A unit whose goal
    -- sits behind a wall has to walk AWAY from it to round the corner, and every one of those tiles is
    -- farther in a straight line than the one it already stands on -- so a straight-line ranking says
    -- "nothing gets me closer", the unit holds, and it holds again next turn. That is the bandit who
    -- marches up to the masonry and stares at it for the rest of the battle.
    --
    -- A goal with no road at all (walled in, or across water a non-flier can't cross) falls back to the
    -- straight line, ranked behind every tile that HAS one -- see SEALED.
    --
    -- cellGap treats `goal` as its nearest footprint cell when it is a unit, and as a plain point when
    -- it is an objective tile (no w/h) -- so closing on a wide foe aims at its near edge either way.
    local field = Combat.travelField(combat, unit, goal)
    local function gapTo(x, y) return roadCost(field, x, y, goal) end
    local here = gapTo(unit.x, unit.y)

    -- A kiter with nothing in range still has to close -- standing off from a foe it cannot shoot is
    -- not skirmishing, it is abstaining. Kiting is expressed in the EXPOSURE weight when it HAS a
    -- shot; the walk itself is an ordinary approach.
    local best
    -- Board order, not key order: distance, hazard bias and steps can all tie at once, and then the
    -- scan's first-wins is the whole decision. See Combat.reachableList.
    for _, node in ipairs(Combat.reachableList(combat, unit)) do
        if not (mode == "leash" and manhattan(node.x, node.y, anchorX, anchorY) > leash) then
            local d = gapTo(node.x, node.y)
            local bias = Hazard.tileBias(combat, node.x, node.y, unit.side)
                + Prop.tileBias(combat, node.x, node.y)
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
        for _, node in ipairs(Combat.reachableList(combat, unit)) do
            local d = manhattan(node.x, node.y, anchorX, anchorY)
            if not home or d < home.d then home = { x = node.x, y = node.y, d = d } end
        end
        if home and home.d < manhattan(unit.x, unit.y, anchorX, anchorY) then
            return { move = { x = home.x, y = home.y }, reason = "leash: returning to post" }
        end
    end

    -- Is something in the way worth breaking instead? Asked BEFORE the walk is returned rather than
    -- only when the walk fails, because the two are alternatives rather than a fallback: a barrier that
    -- adds a thirty-tile detour is worth three turns of axework even though the detour is perfectly
    -- walkable. AI.clearing has already priced that trade and only answers when breaking wins outright.
    local clearing = AI.clearing(ctx, goal, here)
    if clearing then return clearing end

    if best and best.d < here then
        -- Name the goal. A body names itself; a tile has no name of its own, so a post lends it the
        -- one it was described by -- "defend: closing on the objective" says what the walk is FOR,
        -- which is the only thing the log reader wants from a move with no blow attached to it.
        local name = (goal.char and goal.char.name)
            or (mode == "defend" and ctx.post and ctx.post.what)
            or "target"
        return { move = { x = best.x, y = best.y }, reason = mode .. ": closing on " .. name }
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
            if t == tt then
                -- Strike the taunter's nearest cell (its only one, for a 1×1 body), so the range
                -- re-check in Combat.useItem lands on the same tile this plan aimed at.
                local cx, cy = Combat.nearestCell(unit.x, unit.y, tt)
                return { item = weapon, tx = cx, ty = cy, reason = "taunted" }
            end
        end
        local minRange = Combat.abilityMinRange(ab)
        local best
        for _, node in ipairs(Combat.reachableList(combat, unit)) do
            local range = Combat.abilityRange(combat, unit, ab, node.x, node.y)
                + Combat.adjacencyRangeBonus(unit.char, weapon)
            local cx, cy = Combat.nearestCell(node.x, node.y, tt)
            local d = manhattan(node.x, node.y, cx, cy)
            if d <= range and d >= minRange
                and (not (ab and ab.requiresSight) or Combat.hasLineOfSight(combat, node.x, node.y, cx, cy))
                and (not best or node.steps < best.steps) then
                best = { x = node.x, y = node.y, tx = cx, ty = cy, steps = node.steps }
            end
        end
        if best then
            return { move = { x = best.x, y = best.y }, item = weapon, tx = best.tx, ty = best.ty,
                     reason = "taunted" }
        end
    end

    -- Out of reach even after moving: shamble toward the taunter.
    local dest
    for _, node in ipairs(Combat.reachableList(combat, unit)) do
        local d = Combat.cellGap(node.x, node.y, tt)
        if not dest or d < dest.dist or (d == dest.dist and node.steps < dest.steps) then
            dest = { x = node.x, y = node.y, dist = d, steps = node.steps }
        end
    end
    if dest and dest.dist < Combat.cellGap(unit.x, unit.y, tt) then
        return { move = { x = dest.x, y = dest.y }, reason = "taunted" }
    end
    return { wait = true, reason = "taunted, out of reach" }
end

-- ---------------------------------------------------------------------------
-- The rule list
-- ---------------------------------------------------------------------------

-- Where a unit's rules come from, in the order a tie is broken:
--
--   1. PLAYER   char.aiRules      -- the character's own list, once the player has taken it over in
--                                    the Loadout screen's Tactics tab
--   2. ITEM     ability.ai        -- rides on the item, so handing an NPC a weapon hands it the
--                                    tactics for that weapon too. This is the whole point of the
--                                    feature: content authors give a bandit a bomb and it starts
--                                    lobbing it at clusters, with nothing else to write.
--   3. CHARACTER char.ai          -- the character's own list as the BLUEPRINT authored it, for a body
--                                    that has never been edited (every enemy, and a companion until
--                                    the player opens its Tactics tab and changes something)
--   4. POSTURE  archetype defaults -- the floor everyone stands on
--
-- PLAYER and CHARACTER are the SAME channel -- a character's own rules -- reached two different ways,
-- and only ever ONE of them contributes. `char.ai` is the blueprint's list, re-derived from the file
-- on every load; `char.aiRules` is the player's copy of that list, seeded from `char.ai` the first
-- time the Tactics tab edits it (ui/tactics_editor.lua) and saved to the save file thereafter. So an
-- overlay REPLACES the blueprint's rules rather than stacking above them: it already contains
-- whatever the blueprint authored, and collecting both would double every rule the player never
-- touched. The two ranks differ only so a body that IS still on its blueprint list sorts below its
-- item rules, where a player who has taken ownership sorts above them.
--
-- TWO REGIMES, one comparator. The three sources the player never sees are ordered by an authored
-- `priority` band, because they are written by authors who cannot see each other's lists and so have
-- no shared position to be ordered by. The player's own list IS a shared position -- it is the list on
-- screen, which they can drag -- so it uses no band at all: every player rule takes AI.PLAYER_PRIORITY,
-- which is below every authored band, so the visible list leads outright and orders itself by position.
-- The seam reads as one sentence: YOUR LIST, THEN EVERYTHING THE GAME BROUGHT.
--
-- That is also why the Tactics tab has no priority field and why dragging a row there means something.
-- ui/tactics_editor.lua drops the band when it seeds the player's overlay from a blueprint, sorting the
-- inherited rules into the order they were actually running in first, so nothing changes underfoot.
--
-- Priority, rank and declaration ordinal together make the sort TOTAL, which is not a nicety:
-- table.sort is not stable in Lua 5.1, so any pair of entries that compared equal could come back in
-- either order, and two runs of the same battle must not decide differently. The ordinal counts across
-- the WHOLE merge rather than within one list precisely so that two items contributing one rule each
-- cannot tie. See `collect`.
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
--
-- THIS IS AN AUTHORING CONCEPT AND NOT A PLAYER-FACING ONE. It exists because the item, blueprint and
-- posture lists are written by three authors who cannot see each other's rules, so there is no shared
-- position for them to be ordered by. The player's own list HAS a shared position -- it is the list on
-- screen -- so it does not use this at all, and the Tactics tab shows no priority field. See the sort
-- in AI.rulesFor, and `PLAYER_PRIORITY` for how the two regimes meet.
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

-- The player's own rules sit ABOVE every authored band -- their list is authoritative, and what is on
-- screen leads. Giving them all one constant is what lets a single comparator serve both regimes: they
-- tie with each other on priority and on rank, so their ordinal -- their POSITION in the list the
-- player dragged -- is the only thing left to separate them, which is exactly the intent.
AI.PLAYER_PRIORITY = 0

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

-- An item's rules are written from the item's own point of view, so a rule that names no `item` is
-- understood to mean "this one". Resolved here rather than at the use site so an authored block can
-- stay as short as `ai = { { when = ..., act = "cast" } }`.
local function collect(out, rules, source, item)
    if not rules then return end
    -- Accept a lone rule table as well as a list of them, so the common one-rule case doesn't have
    -- to be wrapped in braces it gains nothing from.
    if rules.act or rules.when or rules.whenFn then rules = { rules } end
    for _, rule in ipairs(rules) do
        -- `enabled == false` switches a rule off without deleting it -- the player toggles rows in the
        -- Tactics tab to see what a list does without them, which is most of how anyone debugs one.
        -- Only an explicit false counts: a rule that never mentions `enabled` is on, so no authored
        -- data file has to say so.
        if rule.enabled ~= false then
            -- `order` counts across the WHOLE collection, not within this one list. It used to be the
            -- index within the list being collected, which was fine only because priority separated
            -- everything else: two items contributing one rule each both scored order 1 and rank 2,
            -- and were told apart purely by their authored priorities. With priority gone that pair
            -- would compare EQUAL, and table.sort is not stable in Lua 5.1 -- the same battle could
            -- order those two rules differently between runs. A running ordinal keeps the comparator
            -- total, and gives the tie the only meaningful answer available: the order the items come
            -- back in, which is inventory (row-major grid) order, which is the player's own layout.
            local n = #out + 1
            out[n] = {
                rule = rule, ref = rule.item or item,
                -- The player's list is ordered by position, so its rules take one constant band and
                -- let the ordinal do the work. Everything else is ordered by what its author declared.
                priority = (source == "player") and AI.PLAYER_PRIORITY or AI.priorityOf(rule),
                rank = AI.SOURCE_RANK[source] or 9,
                order = n,
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

    -- A character's own rules come from exactly one channel: the player's overlay if it exists (which
    -- was seeded from the blueprint, so it already holds the inherited rules), otherwise the
    -- blueprint's own list. See the source-order note above for why this is a replace, not a stack.
    if char.aiRules then
        collect(out, char.aiRules, "player")
    else
        collect(out, char.ai, "character")
    end
    for _, item in ipairs(Combat.abilityItems(char)) do
        local ab = item.activeAbility
        collect(out, ab and ab.ai, "item", item)
    end
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
    -- What this unit is standing there FOR, for a posture that stands there for something. Read once
    -- and carried on the ctx, because the engage test, the stand-tile leash and the movement fallback
    -- all have to agree about where the post is or the unit oscillates between taking it and leaving.
    local post = posture.defends and AI.post(combat, unit) or nil
    -- Who this unit will not walk past somebody to reach: the escorted charge, while the party still
    -- has a body between it and here. Nil in a versus match and on every map that protects nobody.
    -- See AI.spared for why it is read here, once, rather than per candidate.
    local spared = AI.spared(combat, unit)
    local ctx = { combat = combat, unit = unit, items = items, posture = posture, post = post,
                  spared = spared }

    -- Stand tiles: always where I am, plus everywhere I could walk to unless the posture is rooted.
    --
    -- A defender's are LEASHED to its post, and the leash is what makes the posture mean anything: a
    -- unit holding a control node that is free to enumerate every reachable tile will happily walk
    -- four squares off it to land a hit, bank nothing that tick, and hand the node to whoever stayed.
    -- The current tile is always in the list, so a defender still marching to a post it cannot reach
    -- this turn can strike whatever has already come to it.
    local tiles = { { x = unit.x, y = unit.y, steps = 0 } }
    if not posture.rooted then
        for _, node in ipairs(Combat.reachableList(combat, unit)) do
            if AI.atPost(node.x, node.y, post) then
                tiles[#tiles + 1] = { x = node.x, y = node.y, steps = node.steps }
            end
        end
    end
    -- Carried so the movement fallback's clearing pass (AI.clearing) swings at a blocker from the same
    -- set of tiles an ordinary blow may be thrown from -- including one walked to first.
    ctx.tiles = tiles

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

                -- Score everything, then throw out whatever accomplishes NOTHING before ranking the
                -- rest. The gate at the bottom asks the same question of the winner, and asking it
                -- only there is not enough: an idle candidate does nothing, and doing nothing is cheap
                -- -- no steps, no exposure, no resource spent -- so it reliably outscores a real action
                -- whose blow is worth less than the walk it costs. Left in the pool it wins the sort,
                -- fails the gate, and the rule takes NO action at all, which is precisely the outcome
                -- the gate's own comment says it does not want. (A Bomblet walking three tiles to burst
                -- on an armoured knight is exactly that shape, and it is a real action -- it is the
                -- only one that unit has.)
                -- ...and throw out the escorted charge along with them, unless this rule is one that
                -- named the objective outright. Dropped BEFORE scoring rather than penalised after it,
                -- because "come through me first" is a hard statement and a bias would be re-argued by
                -- the first soft body the scorer met. A rule left with nothing else to hit takes no
                -- action and the turn falls through to the approach below -- which walks at the nearest
                -- foe, which is the body doing the screening.
                local spare = (not namesObjective(rule)) and ctx.spared or nil
                local scored = {}
                for _, c in ipairs(pool) do
                    c.score = AI.scoreCandidate(combat, unit, c, w, previews)
                    c.score = c.score + prefBonus(ctx, rule, c, w)
                    if c.outcome > 0 and c.target ~= spare then scored[#scored + 1] = c end
                end
                pool = scored

                if #pool > 0 then
                    -- Ties are broken toward standing still, then by board position, so that an
                    -- otherwise even choice is made the same way every run. A comparator that left
                    -- ties genuinely unordered would make this module's tests flap.
                    --
                    -- The item is part of that ordering and not an afterthought: two candidates can
                    -- agree on tile, target and score and still be different weapons ("hit him from
                    -- here" with either of two swords that happen to price the same). Leaving those
                    -- level would hand the choice to table.sort's treatment of equal elements, and
                    -- the unit would draw a different blade depending on what order the pool was
                    -- built in -- unnoticeable in one process, and a disagreement between two.
                    local function better(a, b)
                        if a.score ~= b.score then return a.score > b.score end
                        if a.steps ~= b.steps then return a.steps < b.steps end
                        if a.x ~= b.x then return a.x < b.x end
                        if a.y ~= b.y then return a.y < b.y end
                        if a.tx ~= b.tx then return a.tx < b.tx end
                        if a.ty ~= b.ty then return a.ty < b.ty end
                        local ai = (a.item and a.item.id) or ""
                        local bi = (b.item and b.item.id) or ""
                        return ai < bi
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
                            -- The mark itself, not just the cell it stands on: a preview (models/intent.lua)
                            -- has to compare "who would this unit hit" against the party's own units, and a
                            -- bare tile can't answer that -- a wide body is aimed at its nearest cell, not
                            -- its anchor, so tx,ty need not be any unit's position. Carried straight off the
                            -- winning candidate, which already resolved it.
                            target = pick.target,
                            -- How deep to hold a chargeable wind-up, when the rule named a depth.
                            -- Carried straight through from the rule rather than scored: how long to
                            -- commit is an authoring decision about THIS foe on THIS rule ("snap at
                            -- anything that can still walk, hold the edge on something rooted"), not
                            -- something the tile scorer has any way to weigh. nil leaves it to
                            -- Combat.useItem, which opens at the ability's floor.
                            windup = rule.windup,
                            -- How much gold to pour into a PURCHASABLE blow (Aurea's Gilded Wound):
                            -- computed by the scorer from her coffer, not authored, so a richer Aurea
                            -- simply hits harder. nil for every ordinary action.
                            spend = pick.spend,
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
    --
    -- An unmanned post moves a unit that has NOT engaged, and that exception is the whole of "a
    -- defender defends something": taking up a station is not joining a fight, so gating it behind
    -- the activation rule left a unit waiting to be attacked on ground it had been posted to hold and
    -- never reached. Once it is at the post, engage governs again and it holds until provoked.
    local marching = post ~= nil and not AI.atPost(unit.x, unit.y, post)
    if (engaged or marching) and not posture.rooted then
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
