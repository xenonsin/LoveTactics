-- Conversation logic + the runtime overlay controller. Blueprints live in
-- data/conversations/<id>.lua: a visual-novel scene with an optional `title`, a persistent
-- `cast` (the characters on screen, drawn left-to-right), and a `script` -- the ordered list
-- of dialogue nodes. See docs (data format) and ui/dialogue.lua for the renderer.
--
-- A scene is written for the WHOLE story and pared down to fit the save it plays in: a cast entry
-- or a block of the script may carry a `when` condition, and `Conversation.resolve` drops what
-- does not apply before the widget ever sees it (an unrecruited priest is not on stage and his
-- lines are gone). Gating is per BLOCK, not per line -- a banter between the priest and the
-- knight has to leave together, or the knight is answering nobody. See `resolve` below.
--
-- The overlay is GLOBAL, not a per-state panel: `Conversation.play(id, onDone)` sets
-- `Conversation.active`, and main.lua routes update/draw/input to it BEFORE the current state
-- while it is set -- so whatever is running (the hub, the overworld, a battle mid-turn) is
-- frozen until the scene ends, then resumes exactly in place (we never switch states). This is
-- what lets a conversation fire from anywhere, including the middle of combat.
--
-- Kept require-safe (no love.graphics at load): the widget is required lazily inside `play`.

local Registry = require("models.registry")
local Character = require("models.character")
local Vendor = require("models.vendor")
local Locale = require("models.locale")

local Conversation = {}

Conversation.defs = Registry.load("data/conversations", "data.conversations")

-- The overlay currently playing (a ui/dialogue.lua instance), or nil. main.lua reads this.
Conversation.active = nil

-- Resolve a speaker id to its display identity: { name, portrait }. Looks the id up as a
-- character then a vendor blueprint; `override` (a cast entry or a node) may supply its own
-- `name`/`portrait` for a speaker that isn't an entity (a narrator) or to relabel one. The name is
-- localized under the stable-id key "name.<id>" (Locale.get), falling back to the blueprint's English
-- name, then the id. The portrait is returned as a PATH string (or nil); the widget loads it through
-- models/sprite.lua (tolerant of missing art), so this stays free of love.graphics and headless-safe.
function Conversation.speaker(id, override)
    override = override or {}
    local def = Character.defs[id] or Vendor.defs[id]
    local base = override.name or (def and def.name)
    return {
        name = base and Locale.get(Locale.key.name(id), base) or id,
        portrait = override.portrait or (def and (def.portrait or def.sprite)) or nil,
    }
end

-- ---------------------------------------------------------------------------
-- Conditions
-- ---------------------------------------------------------------------------
-- A `when` is DATA, not a predicate function -- unlike an encounter's `condition(ctx)`
-- (models/encounter.lua). It has to be, for two reasons:
--   * tools/extract_strings.lua rewrites conversation files in place to stamp localization tags,
--     and a closure cannot be serialized back out -- a function `when` would be silently erased
--     the next time anyone ran extraction.
--   * data can be INSPECTED. tests/conversation_spec.lua reads a block's condition and proves it
--     requires the speaker it gates (see `guarantees`), which no closure could ever offer.
--
-- The grammar, evaluated against a context from `Conversation.context`:
--   { has = "priest" }        the character is on the roster (recruited)
--   { notHas = "priest" }     ... and its negation
--   { done = "vault_heist" }  the quest is completed
--   { notDone = "..." }
--   { prestige = 3 }          player prestige is AT LEAST 3
--   { all = { c1, c2 } }      every sub-condition holds
--   { any = { c1, c2 } }      at least one holds
-- Several keys in one table AND together: { has = "priest", done = "vault_heist" }.
local PREDICATES = {}
PREDICATES.has = function(ctx, id) return ctx.roster[id] == true end
PREDICATES.notHas = function(ctx, id) return ctx.roster[id] ~= true end
PREDICATES.done = function(ctx, id) return ctx.quests[id] == true end
PREDICATES.notDone = function(ctx, id) return ctx.quests[id] ~= true end
PREDICATES.prestige = function(ctx, n) return (ctx.prestige or 1) >= n end
PREDICATES.all = function(ctx, list)
    for _, sub in ipairs(list) do
        if not Conversation.test(sub, ctx) then return false end
    end
    return true
end
PREDICATES.any = function(ctx, list)
    for _, sub in ipairs(list) do
        if Conversation.test(sub, ctx) then return true end
    end
    return false
end

-- The set of condition keys, exposed so a spec can reject a typo'd blueprint.
Conversation.PREDICATES = PREDICATES

-- Does `when` hold in `ctx`? A nil condition is unconditional (always true), so an ungated
-- scene needs no ceremony. An unknown key is an authoring error and raises rather than
-- quietly passing -- a mistyped `{ hass = "priest" }` must never read as "always show".
function Conversation.test(when, ctx)
    if when == nil then return true end
    assert(type(when) == "table", "a `when` condition must be a table, got " .. type(when))
    for key, value in pairs(when) do
        local predicate = PREDICATES[key]
        assert(predicate, "unknown conversation condition '" .. tostring(key) .. "'")
        if not predicate(ctx, value) then return false end
    end
    return true
end

-- The evaluation context for `test`, read off a player (models/player.lua). Roster membership is
-- flattened to an id set so `has` is a lookup rather than a scan.
function Conversation.context(player)
    local roster, quests = {}, {}
    if player then
        for _, char in ipairs(player.roster or {}) do
            if char.id then roster[char.id] = true end
        end
        for questId, done in pairs(player.completedQuests or {}) do
            quests[questId] = done == true
        end
    end
    return {
        roster = roster,
        quests = quests,
        prestige = (player and player.prestige) or 1,
    }
end

-- Can `when` ever hold WITHOUT character `id` on the roster? `guarantees` returns true when it
-- cannot -- i.e. the condition provably implies the character is present. This is what lets the
-- spec prove a gated speaker's lines are guarded: a block that says { has = "priest" } may safely
-- contain priest lines; one that says { done = "arena_debut" } may not.
-- Conservative by construction: it only ever returns true when it is certain, so a condition
-- shape it cannot reason about reads as "no guarantee" and the spec asks the author to be explicit.
function Conversation.guarantees(when, id)
    if type(when) ~= "table" then return false end
    if when.has == id then return true end
    -- An `all` holds only if every member does, so ONE member guaranteeing `id` is enough.
    for _, sub in ipairs(when.all or {}) do
        if Conversation.guarantees(sub, id) then return true end
    end
    -- An `any` holds if any member does, so it guarantees `id` only when EVERY branch does.
    if when.any and #when.any > 0 then
        for _, sub in ipairs(when.any) do
            if not Conversation.guarantees(sub, id) then return false end
        end
        return true
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Resolution: a blueprint + a context -> the scene actually played
-- ---------------------------------------------------------------------------

-- Walk the authored script (which may nest conditional blocks) into a flat, ordered list of
-- { node, kept } records. A BLOCK is a script entry with its own `script` and a `when`; it holds
-- lines that stand or fall together. Nesting is allowed, and a block inside a dropped block is
-- dropped regardless of its own condition (`keep` is carried down) -- an inner condition can
-- narrow its parent, never escape it. A plain node may also carry `when` to gate itself alone.
local function flatten(entries, ctx, keep, out)
    for _, entry in ipairs(entries) do
        local entryKept = keep and Conversation.test(entry.when, ctx)
        if entry.script then
            flatten(entry.script, ctx, entryKept, out)
        else
            out[#out + 1] = { node = entry, kept = entryKept }
        end
    end
end

local function shallowCopy(t)
    local copy = {}
    for k, v in pairs(t) do copy[k] = v end
    return copy
end

-- `def` pared down to what applies in `ctx`: cast entries and script blocks whose `when` fails are
-- removed. Returns a NEW def ({ title, cast, script }) -- blueprints stay immutable, so nodes are
-- copied before any rewrite. The returned script is flat and `when`-free; the widget renders it
-- without knowing conditions exist.
--
-- Dropping lines would strand any `goto` aimed at them, silently ending the scene (nextIndex reads
-- an unknown label as "stop"). So a jump to a dropped node is re-pointed to the next line that
-- SURVIVED -- the branch rejoins the scene where it would have anyway -- or to "end" when the
-- dropped node was the last thing standing. A surviving target with no `id` of its own is given a
-- synthetic one to be jumped to.
function Conversation.resolve(def, ctx)
    ctx = ctx or Conversation.context(nil)

    local cast = {}
    for _, raw in ipairs(def.cast or {}) do
        local entry = type(raw) == "table" and raw or { id = raw }
        if Conversation.test(entry.when, ctx) then
            cast[#cast + 1] = raw
        end
    end

    local flat = {}
    flatten(def.script or {}, ctx, true, flat)

    local script, indexOfNode = {}, {}
    for _, record in ipairs(flat) do
        if record.kept then
            local node = shallowCopy(record.node)
            node.when = nil
            script[#script + 1] = node
            indexOfNode[record] = #script
        end
    end

    -- Where each dropped id should jump instead: the next surviving node, walking the authored
    -- order backwards so a run of consecutive dropped nodes all resolve to the same landing spot.
    local redirect, survivor, survivorIndex = {}, nil, nil
    for i = #flat, 1, -1 do
        local record = flat[i]
        if record.kept then
            survivorIndex = indexOfNode[record]
            survivor = script[survivorIndex]
        elseif record.node.id then
            if survivor then
                if not survivor.id then
                    survivor.id = "__resolved_" .. tostring(survivorIndex)
                end
                redirect[record.node.id] = survivor.id
            else
                redirect[record.node.id] = "end"
            end
        end
    end

    for _, node in ipairs(script) do
        if node.goto and redirect[node.goto] then node.goto = redirect[node.goto] end
        if node.choices then
            local choices = {}
            for i, choice in ipairs(node.choices) do
                local copy = shallowCopy(choice)
                if copy.goto and redirect[copy.goto] then copy.goto = redirect[copy.goto] end
                choices[i] = copy
            end
            node.choices = choices
        end
    end

    return { title = def.title, cast = cast, script = script }
end

-- Index (1-based) of the script node carrying `id`, or nil if none does.
local function indexOfId(script, id)
    for i, node in ipairs(script) do
        if node.id == id then return i end
    end
    return nil
end

-- The next node index to play after the current one, or nil when the scene ends.
--   * gotoLabel == "end"  -> nil (an explicit stop)
--   * gotoLabel set       -> the node whose `id` matches it (nil if there is no such node)
--   * gotoLabel nil       -> the next node in order (nil past the last one)
-- The one graph-walk rule, shared by a node's own `goto` and a choice's `goto`, kept here so a
-- spec can exercise branching without a window.
function Conversation.nextIndex(script, current, gotoLabel)
    if gotoLabel == "end" then return nil end
    if gotoLabel then return indexOfId(script, gotoLabel) end
    local n = current + 1
    if n <= #script then return n end
    return nil
end

function Conversation.isActive()
    return Conversation.active ~= nil
end

-- Start a conversation by id, opening the overlay. `onDone` fires once the scene concludes
-- (played to the end, or skipped). Requires the widget lazily so this module stays load-safe.
--
-- The scene is resolved against `ctx` first (defaulting to the active player), so the cast and
-- script handed to the widget already reflect who has been recruited and what has been done.
-- Pass an explicit ctx (from `Conversation.context`) to preview a scene for another save state.
function Conversation.play(id, onDone, ctx)
    local def = Conversation.defs[id]
    assert(def, "unknown conversation id: " .. tostring(id))
    local Player = require("models.player")
    local resolved = Conversation.resolve(def, ctx or Conversation.context(Player.active))
    local Dialogue = require("ui.dialogue")
    Conversation.active = Dialogue.new(resolved, function()
        Conversation.active = nil
        if onDone then onDone() end
    end, id) -- the id scopes keyed line lookups: "conversation.<id>.<key>"
    return Conversation.active
end

return Conversation
