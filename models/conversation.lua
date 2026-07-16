-- Conversation logic + the runtime overlay controller. Blueprints live in
-- data/conversations/<id>.lua: a visual-novel scene with an optional `title`, a persistent
-- `cast` (the characters on screen, drawn left-to-right), and a `script` -- the ordered list
-- of dialogue nodes. See docs (data format) and ui/dialogue.lua for the renderer.
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
function Conversation.play(id, onDone)
    local def = Conversation.defs[id]
    assert(def, "unknown conversation id: " .. tostring(id))
    local Dialogue = require("ui.dialogue")
    Conversation.active = Dialogue.new(def, function()
        Conversation.active = nil
        if onDone then onDone() end
    end, id) -- the id scopes keyed line lookups: "conversation.<id>.<key>"
    return Conversation.active
end

return Conversation
