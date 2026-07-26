-- The MOTIF vocabulary: the one reading of a def's tags that every visual family shares.
--
-- A tile field (ui/field_fx.lua), an impact burst (ui/burst_fx.lua) and a sprite mode
-- (shaders/sprite.lua) all have to answer the same question -- "what element is this thing?" -- and
-- they must answer it the SAME way, or a Fireball's telegraph, the bolt that crosses the board, the
-- blast that lands and the fire left burning on the ground stop looking like one event. That
-- agreement is the whole reason this file exists. It is the vocabulary; each family owns its own
-- pictures for it.
--
--   local motif = Motif.of(item.tags)        -- "fire", "pierce", "holy", ... or nil
--
-- ---------------------------------------------------------------------------
-- WHY TAG ORDER IS THE RULE
--
-- `of` reads the tags in the order the def LISTS them and takes the first it recognises. That is not
-- a shortcut -- it is how the data is already authored. A weapon's tag list runs
--
--     { "dagger", "pierce", "physical", "poison", "melee" }
--      family      shape     routing     element   reach
--
-- so the shape leads the element, and the Apothecary's Lancet bursts as a STAB that happens to leave
-- poison behind rather than as a puff of gas -- which is exactly what it is. A spell's ability tags
-- lead with the element instead ({ "fire", "arcane" }), so a Fireball blooms. Neither had to author a
-- word about how it looks: the impact BURSTS (ui/burst_fx.lua's MOTIF_PATTERN) resolve their shape off
-- this table. (Tile FIELDS no longer read it -- the board draws a zone by what it means to the player,
-- not by its element; see ui/field_fx.lua.)
--
-- The archetype tags (dagger, mace, wand -- Item.ARCHETYPES) are deliberately NOT motifs. A family
-- says which shelf sells the thing, not what it looks like when it lands; the shape tag beside it
-- already says that. The handful of natural weapons that carry no shape tag at all (a blight
-- spitter, a set of burning fists) resolve on their element instead, which is the better answer for
-- them anyway.
--
-- Plain data at require-time, no love.graphics -- this is required by the headless suite through
-- ui/field_fx.lua (see CLAUDE.md).
-- ---------------------------------------------------------------------------

local Motif = {}

-- The vocabulary, grouped by what kind of thing it names. Order is only presentation here: a motif is
-- looked up by name, never by index (unlike a shader's pattern list, where the index IS the contract).
Motif.ORDER = {
    -- How a body was struck. Every shipped weapon that is a weapon carries one of these three.
    "slash", "pierce", "impact",
    -- What it was struck WITH, when that is a thing in the world.
    "fire", "ice", "water", "lightning", "wind", "earth", "poison", "acid", "dark", "light", "holy",
    "arcane",
    -- And the four that name an idea rather than a substance: a binding, a colour raised, the will it
    -- raises, a thing built. These have no burst of their own worth the name but they do have ground.
    "control", "banner", "morale", "structure",
}

Motif.SET = {}
for _, name in ipairs(Motif.ORDER) do Motif.SET[name] = true end

-- Tag -> motif. Mostly the identity -- the tags data/ already uses ARE the vocabulary, which is the
-- point -- plus the few aliases where two authored tags mean one picture.
Motif.TAGS = {}
for _, name in ipairs(Motif.ORDER) do Motif.TAGS[name] = name end

-- A bite is a cut made with teeth. The wolves and the risen carry it instead of "slash", and there is
-- no reason for them to have their own burst.
Motif.TAGS.bite = "slash"

-- Deliberately absent: "physical", "magical", "melee", "ranged". Those are ROUTING tags -- which
-- defense a blow is priced against, how far it reaches -- and a picture drawn off them would say
-- nothing a player could use. They sit in the middle of nearly every weapon's tag list, so leaving
-- them out is also what lets the ordered scan below reach the element behind them.

-- The first motif `tags` resolves to, or nil. `explicit` (a def's own `fx.motif`) wins outright, which
-- is how something takes a picture its tags do not imply.
function Motif.of(tags, explicit)
    if explicit and Motif.SET[explicit] then return explicit end
    for _, t in ipairs(tags or {}) do
        local m = Motif.TAGS[t]
        if m then return m end
    end
    return nil
end

-- Build a `tag -> X` table from a `motif -> X` one, for a family that resolves off tags directly.
-- A motif the family has no picture for is simply left out, so a family is never forced to invent one
-- (ui/field_fx.lua has no field for `slash`, and should not pretend to).
function Motif.tagTable(byMotif)
    local out = {}
    for tag, motif in pairs(Motif.TAGS) do
        local v = byMotif[motif]
        if v ~= nil then out[tag] = v end
    end
    return out
end

return Motif
