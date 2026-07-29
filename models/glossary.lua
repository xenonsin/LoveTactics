-- Glossary: the definitions behind the proper nouns an item tooltip drops.
--
-- An item tooltip names things without explaining them -- "Applies: Rimebitten", a `frenzy` arc, a
-- `careful` blast -- and a player who has not met that word yet has nowhere to look it up mid-battle.
-- This module answers the lookup: given an item, it returns every STATUS the thing can put on a body
-- and every KEYWORD its ability declares, each with the name and description from its own data file.
-- ui/glossary_panel.lua draws the result beside the tooltip; ui/item_tooltip.lua wires the two together.
--
--   Glossary.forItem(item, actor, out) -> { { kind, id, name, description, color }, ... }
--
-- `actor` (optional) is the unit the ability is priced against, and `out` an already-computed
-- Combat.abilityOutput for the pair -- the tooltip has one in hand and passes it so the dry run is not
-- paid for twice per frame. Entries are deduplicated by id and ordered statuses-then-keywords, since a
-- status is the thing a player actually needs read back to them.
--
-- Pure logic (no love.graphics), so it loads under the headless tests.

local Status = require("models.status")
local Trait = require("models.trait")
local Trap = require("models.trap")
local Hazard = require("models.hazard")
local Keyword = require("models.keyword")
local Settings = require("models.settings")

local Glossary = {}

-- Keyword entries share one cool tint; a status uses its own badge colour instead. Saturated rather
-- than pale on purpose: in the compact form the name runs straight into its description on one line, so
-- the tint is the ONLY thing marking where the term ends and the prose begins.
local KEYWORD_COLOR = { 0.55, 0.76, 1.00 }

-- Collector: appends `{ kind, id, ... }` once per id, so a weapon that lays a Burn hazard AND carries
-- a Burn on its hit still explains Burn exactly once.
local function collector()
    local out, seen = {}, {}
    return out, function(kind, id, def)
        if not id or not def or seen[id] then return end
        seen[id] = true
        out[#out + 1] = {
            kind = kind,
            id = id,
            name = def.name or id,
            description = def.description,
            color = (kind == "status" and def.color) or KEYWORD_COLOR,
        }
    end
end

-- Every status id this item can put on a body, in the order the tooltip mentions them.
local function statusIds(item, out)
    local ids = {}
    local function add(id) if id then ids[#ids + 1] = id end end

    if out then
        for _, st in ipairs(out.statuses or {}) do add(st.id) end
        -- A trap or a hazard the ability leaves behind afflicts whoever walks into it later. The victim
        -- never sees the item that placed it, so this tooltip is the only place the word gets defined.
        if out.trap then
            local tp = Trap.preview(out.trap, out.trapAmount)
            for _, st in ipairs(tp and tp.statuses or {}) do add(st.id) end
        end
        if out.hazard then
            local hp = Hazard.preview(out.hazard, out.hazardAmount)
            for _, st in ipairs(hp and hp.statuses or {}) do add(st.id) end
        end
    end

    -- A censer/banner carries its cloud with it (item.incense): ground laid around the bearer every
    -- time they move, afflicting whoever stands in it. The item names that status in its own
    -- description ("Grants Bloodsong", "Inflicts Mired") but nothing here CASTS, so the dry run above
    -- never sees it -- the same reason a laid hazard is previewed rather than run. Read its statuses off
    -- the hazard preview exactly as the ability's `out.hazard` is read.
    if item.incense and item.incense.hazard then
        local hp = Hazard.preview(item.incense.hazard, item.incense.amount)
        for _, st in ipairs(hp and hp.statuses or {}) do add(st.id) end
    end

    -- An immunity item NAMES the statuses it refuses ("Immune to Root and Mired") without ever putting
    -- one on a body. The glossary's contract is to define whatever the tooltip drops (ui/item_tooltip
    -- header), and a player reading a ward against Mired needs to know what Mired is as much as one on
    -- the receiving end of it -- so the word is defined here too.
    for _, id in ipairs(item.statusImmunity or {}) do add(id) end

    local ab = item.activeAbility
    -- The stance a channel puts the caster in the moment it commits -- landed on the caster, not the
    -- target, and so never surfaced by the dry run above.
    if ab then add(ab.channelStatus) end

    -- A charm/coating's aura lands its status on whatever the NEIGHBOUR's hit damages, so the word
    -- belongs to this item even though nothing here casts.
    if item.aura and item.aura.status then add(item.aura.status.id) end

    -- The wait swap: bracing grants Defending, and a named staff/shield may hang another status on the
    -- stance itself. Perform's airs are nothing BUT statuses -- one per song in the cycle.
    local wb = item.waitBehavior
    if wb then
        if wb.kind == "defend" then add("status_defending") end
        add(wb.status)
        add(wb.coversStatus)
        for _, song in ipairs(wb.songs or {}) do add(song.status) end
    end

    -- A reflex this item grants (traits attach to a carrier from the grid, never from a blueprint's own
    -- list): a counter that declares what it `applies` is applying it on this item's behalf.
    for _, traitId in ipairs(item.traits or {}) do
        local def = Trait.defs[traitId]
        if def and def.counter then add(def.counter.applies) end
    end

    return ids
end

-- The statuses and keywords `item` brings into play, ready to render. Never nil: an item that names
-- neither returns an empty list, and a caller can treat that as "draw nothing".
--
-- KEYWORDS ARE OPT-IN. They ride behind the `tooltip_keywords` preference (models/settings.lua),
-- which ships OFF: a keyword is a rule about how casting works, and a player who has learnt the rules
-- does not want Line of Sight explained on every bow for the rest of the campaign. Statuses are not
-- gated with them -- what a weapon inflicts is a fact about that weapon, changes item to item, and is
-- the thing the glossary exists to answer. `opts.keywords` overrides the preference outright, which
-- is how the tests read the whole list without touching the player's file.
function Glossary.forItem(item, actor, out, opts)
    local entries, add = collector()
    if not item then return entries end

    -- The dry run, when the caller had none to hand. Combat is required LAZILY (at call time) purely
    -- to keep this module cheap to require from a data-side test; nothing in combat.lua requires back.
    if out == nil and item.activeAbility then
        out = require("models.combat").abilityOutput(actor, item)
    end

    for _, id in ipairs(statusIds(item, out)) do
        add("status", id, Status.defs[id])
    end

    local wantKeywords = opts and opts.keywords
    if wantKeywords == nil then wantKeywords = Settings.get("tooltip_keywords") end
    if wantKeywords then
        for _, id in ipairs(Keyword.forItem(item)) do
            add("keyword", id, Keyword.defs[id])
        end
        -- Knockback is not a declarative field -- it rides inside effect closures (fx.damage's
        -- `knockback` opt, fx.knockback) -- so Keyword.forItem cannot see it. The dry run does: it
        -- records the distance in `out.knockback`, exactly as it records statuses and hazards. Surface
        -- the keyword off that, so a "Knockback N" description has its term defined beside the tooltip.
        if out and out.knockback and out.knockback > 0 then
            add("keyword", "keyword_knockback", Keyword.defs["keyword_knockback"])
        end
    end
    return entries
end

return Glossary
