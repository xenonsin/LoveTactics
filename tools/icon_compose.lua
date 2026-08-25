-- Icon COMPOSER (prototype of the permanent system in docs/art-assets.md,
-- "The permanent icon system — compose, don't commission").
--
--     & "E:\LOVE\lovec.exe" . icon-compose        # render the demo spread (one per family + type)
--     & "E:\LOVE\lovec.exe" . icon-compose all     # ... every item blueprint (preview only)
--     & "E:\LOVE\lovec.exe" . icon-compose assets  # graduate: write every item's OWN sprite path in assets/
--
-- Where icon-build draws ONE game-icons glyph per asset, this draws the icon as a pure function of
-- what the blueprint already declares -- exactly the way shaders/field.lua draws a hazard from
-- its fire/ice tag. Three data channels, none of them a commission:
--
--   1. BASE    a weapon REUSES its family silhouette (Item.archetype -> FAMILY_BASE) -- 15 shapes
--              cover every weapon and shield. Every other item takes its own mapped glyph ONLY IF that
--              glyph is in BASE_VOCABULARY; failing that it draws what the ability DOES (VERB_BASE, off
--              Combat.abilityOutput) or when the charm FIRES (FIELD_BASE / HOOK_BASE), then the ability
--              cost-pool shape, then the generic TYPE_BASE.
--   2. TINT    the base is recoloured by the item's element/strike tag (ELEMENT_TINT) -- or, when it
--              names none, by the element of a status it applies, which is what makes the ten wards one
--              drawing in ten colours.
--   3. PIPS    `repRank` tier diamonds along the bottom, in the item's CLASS colour (the vendor shelf).
--
-- THE VOCABULARY IS THE POINT. Before it, the map's per-asset guesses were the base channel for every
-- non-weapon, so 749 item icons drew 262 silhouettes, 164 of them for exactly one item, and every new
-- ability added another. Gated, they draw 62. See BASE_VOCABULARY below and docs/commission-item-icons.md.
--
-- (An earlier revision framed the art in a class-colour border and stamped a type-colour disc in the
-- corner; both were dropped -- the frame fought the action slot's own border and the disc read busy.)
--
-- The 15 base slugs are canonical game-icons picks (reuse, not commission -- the decision recorded in
-- the doc). Preview runs (`icon-compose` / `icon-compose all`) land under vendor/compose-preview/ --
-- gitignored, and deliberately NOT assets/, so a prototype run can never overwrite the shipped set.
-- `icon-compose assets` is the graduation: it writes each item's own sprite path in assets/items/,
-- making this the fourth pipeline verb and the source of the shipped icon set.

local Registry = require("models.registry")
local Item = require("models.item")
local Source = require("tools.icon_source")

-- The per-item glyph map (tools/icons/map.lua, mostly hand-corrected) -- the source of a UNIQUE
-- silhouette per item. Weapons and armour are content to reuse a shared family/type shape, but every
-- other item (an ability, a charm, a flask, a material) draws its own mapped glyph, so two spells no
-- longer land on the same swirl. Optional: absent map just means everything falls back to the family/
-- type bases below.
local IconMap = nil
do
    local ok, m = pcall(require, "tools.icons.map")
    if ok and type(m) == "table" then IconMap = m end
end

local M = {}

local RESVG = "vendor/bin/resvg.exe"
local OUT_ROOT = "vendor/compose-preview"
local RENDER_SIZE = 256 -- larger than icon-build's 128: a composed icon has a frame and badge to keep crisp

-- 1. BASE -- one canonical game-icons silhouette per weapon family. These are the ~15 shapes the whole
-- item catalogue reduces to; verified present in the vendored set.
local FAMILY_BASE = {
    sword = "lorc/broadsword",
    greatsword = "delapouite/two-handed-sword",
    axe = "lorc/battle-axe",
    mace = "lorc/spiked-mace",
    hammer = "delapouite/thor-hammer",
    dagger = "lorc/broad-dagger",
    spear = "lorc/spear-hook",
    bow = "delapouite/bow-arrow",
    longbow = "lorc/high-shot",
    staff = "lorc/wizard-staff",
    wand = "lorc/crystal-wand",
    shield = "delapouite/cross-shield",
    censer = "lorc/incense",
    unarmed = "lorc/fist",
    natural = "delapouite/claws",
}

-- ... and a fallback base for the typeless items (an ability, a charm, a flask own no weapon family).
-- `consumable` was missing here for as long as every consumable had a map entry to hide behind: the
-- moment one does not, a potion composes as a handful of gems. It is a type like any other.
local TYPE_BASE = {
    ability = "lorc/magic-swirl",
    armor = "lorc/breastplate",
    utility = "lorc/round-bottom-flask",
    material = "lorc/gems",
    consumable = "caro-asercion/round-potion",
}
local DEFAULT_BASE = "lorc/gems"

-- An ability has no weapon family, so its silhouette is drawn from the pool it SPENDS instead: a mana
-- spell and a stamina technique read as different things at a glance -- the same physical/magical
-- split the school aura draws, but stated in the base so it survives even when there's no school tag.
-- (No ability costs health today; the blood-drop is here so one would compose rather than fall back.)
local ABILITY_BASE = {
    mana = "lorc/magic-swirl",   -- a spell woven from mana
    stamina = "lorc/muscle-up",  -- a martial technique paid in exertion
    health = "lorc/drop",        -- blood magic, paid in health
}

-- 1b. THE VERB -- what an ability DOES, read off the same dry run the tooltip reads (Combat.abilityOutput).
--
-- An ability owns no weapon family, which is why every one of them used to take its own mapped glyph and
-- why 88 silhouettes in this catalogue were drawn for exactly one item. The picture belongs to the ACT:
-- a ward is a ward whether it wards fire or slash, and the tint channel below already says which.
--
-- Read through the dry run rather than off `activeAbility`'s fields, because the fields cannot see a
-- status, a summon or a laid hazard -- those live inside the effect closure. Asking the same function the
-- tooltip asks also means the icon can never claim something the tooltip denies.
local VERB_BASE = {
    summon = "lorc/spark-spirit",       -- calls a body onto the board (or reshapes one)
    hazard = "lorc/fire-zone",          -- lays a patch of ground
    trap = "lorc/mantrap",              -- arms a tile and waits
    wall = "delapouite/barrier",        -- puts something solid in the way
    heal = "delapouite/healing",        -- gives health back
    resource = "lorc/energise",         -- drains or restores a pool
    area = "sbed/blast",                -- a blow that lands on a footprint
    strike = "lorc/deadly-strike",      -- a blow that lands on a body
    curse = "lorc/cursed-star",         -- inflicts a debuff and nothing else
    ward = "sbed/shield",               -- grants a buff and nothing else
    move = "lorc/sprint",               -- pushes, pulls, swaps or steps
}

-- 1c. THE PASSIVE CHANNEL -- a charm that takes no turn is named by WHEN it fires.
--
-- A utility with an `activeAbility` is an ability and takes the verb above. What is left is the passive
-- half of the shelf -- 221 charms, most of which carry nothing but a `traits` list -- and the property a
-- player actually reads off one is the moment it speaks up. A trait's hook says exactly that, and it is
-- already authored (data/traits/*.lua), so nothing new is written onto a blueprint.
local HOOK_BASE = {
    onDamaged = "delapouite/shield-impact",   -- answers a blow
    onCast = "lorc/tied-scroll",              -- rides the bearer's own working
    onAnyCast = "lorc/tied-scroll",           -- ... or anybody's
    onCombatStart = "delapouite/knight-banner", -- speaks once, before anything happens
    onDeath = "delapouite/heart-stake",       -- pays out when the bearer falls
    onAnyDeath = "delapouite/heart-stake",    -- ... or when anyone does
    onStatusApplied = "sbed/poison",          -- watches for an affliction
    onAllyStrike = "lorc/crossed-swords",     -- follows a friend's swing
    onSummonLost = "lorc/spark-spirit",       -- mourns a called body
}
-- The order the hooks are asked in, most specific first. A trait that fires on two hooks takes the first
-- of these it carries -- pairs() over the table above would pick a different one on a different run.
local HOOK_ORDER = {
    "onSummonLost", "onAllyStrike", "onStatusApplied", "onDeath", "onAnyDeath",
    "onCombatStart", "onCast", "onAnyCast", "onDamaged",
}

-- ... and the fields a charm can carry INSTEAD of a trait. Checked in this order, before the hooks,
-- because a field is the more specific statement: a charm with `trail` is a boot whatever else it does.
local FIELD_BASE = {
    { "unarmedBonus", "lorc/fist" },        -- a fist charm
    { "trail", "lorc/boots" },              -- something worn on the feet, leaving a wake
    { "incense", "lorc/incense" },          -- a censer's burn
    { "aura", "lorc/aura" },                -- a standing field around the bearer
    { "statusImmunity", "sbed/shield" },    -- refuses an affliction outright
    { "resist", "delapouite/shield-impact" }, -- takes the blow softer
    { "charge", "lorc/energise" },          -- banks something and spends it
}

-- THE VOCABULARY -- the whole set of silhouettes this game is allowed to draw.
--
-- Everything above is structural: a family, a type, a verb, a hook, a field. What follows is the rest of
-- the vocabulary -- the mapped glyphs that earn their own drawing, and the handful of exceptions.
--
-- WHY A GATE AT ALL. tools/icons/map.lua names a glyph for every asset, most of them auto-guessed, and
-- baseFor used to take whatever it found. That made the commission an emergent property of 749 blueprints
-- rather than a decision: 262 silhouettes, 164 of them drawn for exactly one item, and every new ability
-- silently adding another. Gated, an unapproved guess cannot reach the renderer -- it falls through to the
-- verb, the hook or the type -- so the drawing set is a list you can read, and it stops growing on its own.
--
-- THE RULE. A mapped glyph is kept when FOUR OR MORE items share it. Below that the shape is not naming a
-- category, it is naming an item -- which is the tooltip's job (docs/art-assets.md, "Known limitation:
-- icon reuse"). Adding an entry here is adding a drawing to the commission; that is the point of it being
-- one list. Regenerate the counts with `. art-source slugs` before touching it.
local KEPT = {
    "delapouite/abdominal-armor",  -- the mail/cuirass shape: most of the armour shelf
    "lorc/robe",                   -- cloth armour
    "lucasms/cloak",               -- a mantle, worn over
    "delapouite/pirate-coat",      -- a coat
    "lorc/armor-vest",             -- a padded vest
    "darkzaitzev/smoke-bomb",      -- the thrown flask family
    "delapouite/centaur-heart",    -- a carried heart/core
    "delapouite/notebook",         -- ledgers, codices, written charms
    "lorc/prayer",                 -- an invocation
    "cathelineau/holy-oak",        -- a blessing that grows
    "lorc/double-shot",            -- a bow trick
    "lorc/shouting",               -- a shout
    "lorc/charm",                  -- a hung charm
    "lorc/hourglass",              -- something that spends time
    "lorc/mirror-mirror",          -- a reflection
    "lorc/rune-stone",             -- a cut sigil
    "lorc/stone-sphere",           -- a thrown stone
    "sbed/duel",                   -- a single combat
}

-- The exceptions: a silhouette below the line that is kept anyway because a BOUND relic wears it
-- (models/item.lua's `bound` -- a signature that can never leave its holder). A relic is the one item a
-- player studies rather than scans, so it is allowed its own picture.
--
-- This list is CAPPED at 24 and the cap is pinned in tests/art_pipeline_spec.lua. An uncapped exception
-- list is just the tail again, arriving one reasonable-sounding decision at a time.
local BESPOKE_CAP = 24
local BESPOKE = {
    "caro-asercion/french-horn",   -- utility_wolfsong_horn
    "delapouite/health-potion",    -- utility_aqua_vitae
    "lorc/crown",                  -- armor_hollow_crown
    "lorc/crystal-ball",           -- utility_overflowing_focus
    "lorc/jeweled-chalice",        -- utility_reliquary_kept_trust
}

-- The vocabulary as a set: everything structural, plus the two lists above. Built from the tables
-- themselves so a new verb or hook can never be a slug the gate then refuses.
local BASE_VOCABULARY = {}
do
    local function admit(slug) if slug then BASE_VOCABULARY[slug] = true end end
    for _, slug in pairs(FAMILY_BASE) do admit(slug) end
    for _, slug in pairs(TYPE_BASE) do admit(slug) end
    for _, slug in pairs(ABILITY_BASE) do admit(slug) end
    for _, slug in pairs(VERB_BASE) do admit(slug) end
    for _, slug in pairs(HOOK_BASE) do admit(slug) end
    for _, row in ipairs(FIELD_BASE) do admit(row[2]) end
    for _, slug in ipairs(KEPT) do admit(slug) end
    for _, slug in ipairs(BESPOKE) do admit(slug) end
    admit(DEFAULT_BASE)
end

-- 2. TINT -- element/strike -> foreground colour. Scanned against the item's tags in this table's
-- favour: an element wins over the physical/melee mechanics tags, which name no colour and are absent
-- here. A physical strike (slash/pierce/blunt) or no element at all lands on steel.
local ELEMENT_TINT = {
    fire = "#ef7d4a", burn = "#ef7d4a",
    ice = "#7fc6ec", frost = "#7fc6ec",
    lightning = "#f3d24a", shock = "#f3d24a",
    holy = "#f2e6a8", radiant = "#f2e6a8", light = "#f2e6a8",
    shadow = "#a279c9", dark = "#a279c9",
    poison = "#8fbf5a", nature = "#8fbf5a",
    arcane = "#b98fe0",
    -- water and acid are two of the eight in Combat.ELEMENT_TAGS and were missing here, so everything
    -- that deals either composed in steel. Pitched off ui/burst_fx.lua's MOTIF_COLOR, so the icon and
    -- the bloom the hit throws are the same colour.
    water = "#73a8eb",
    acid = "#bceb3d",
}
local STEEL = "#dce1e6"

-- The three PHYSICAL strike types, used only on the status path below. An item that deals slash damage
-- stays steel -- that is the physical/magical tell the whole shelf is read by -- but an ability whose
-- only element is the one named by the status it applies (Resistant: Slash, Immune: Pierce) has no
-- colour at all otherwise, and four identical steel shields on the shelf name nothing. Also pitched off
-- MOTIF_COLOR, so a pierce ward matches what a pierce hit looks like.
local STRIKE_TINT = {
    slash = "#f2f2f2",
    pierce = "#fff2d9",
    impact = "#d1b88c",
}

-- SCHOOL -- physical vs magical, the damage school the item's tags already declare (see
-- models/combat.lua's magical/defense switch). With no backing plate, magic reads as a soft aura in
-- the element tint blooming behind the silhouette (added in compose); a physical strike, and anything
-- schoolless (armor, a flask, a charm), is the bare silhouette with no halo.

-- 3. PIPS -- class (vendor shelf) -> tier-diamond colour.
local CLASS_COLOR = {
    fighter = "#c0562f",
    rogue = "#6f9a52",
    priest = "#d8c15f",
    mage = "#6f82d4",
    ranger = "#4f9a86",
    cleric = "#d8c15f",
}
local CLASS_DEFAULT = "#9aa0a8"

local function projectPath(rel)
    return love.filesystem.getSource() .. "/" .. rel
end

-- THE DRY RUN -- what an ability does, asked of models/combat through the tooltip's own function.
--
-- Required lazily and memoized by id: combat is the largest module in the project and an item that owns
-- no ability never needs it. `Combat.abilityOutput` wants an INSTANTIATED item (its curves resolve
-- against a level), so the blueprint is looked back up to its id -- the registry hands out one table per
-- blueprint, so identity is a safe key.
local Combat, idOfDef, outputCache
local function outputFor(def)
    if not (def and def.activeAbility) then return nil end
    if not Combat then
        Combat = require("models.combat")
        outputCache = {}
        idOfDef = {}
        for id, d in pairs(Item.defs or {}) do idOfDef[d] = id end
    end
    local id = idOfDef[def]
    if not id then return nil end
    local cached = outputCache[id]
    if cached ~= nil then return cached or nil end
    local ok, out = pcall(function()
        return Combat.abilityOutput(nil, Item.instantiate(id))
    end)
    -- A dry run that raises is not a reason to lose the icon: fall through to the channels below.
    outputCache[id] = (ok and out) or false
    return outputCache[id] or nil
end

-- The element an APPLIED STATUS names, or nil. A ward carries no element tag of its own -- "Resistant:
-- Fire" is tagged `protective`, and the fire lives in the status it applies (`vulnerable = { fire = -4 }`
-- on data/status/status_resistant_fire.lua). Read it there and the ten wards compose in ten colours off
-- one silhouette, matching the badge colour the player already reads on the unit.
--
-- The element is looked up rather than the status's own `color` copied, so the icon set keeps the eight
-- tints of ELEMENT_TINT instead of drifting into 107 status colours.
local STATUS_ELEMENT_TABLES = { "vulnerable", "immune", "resist" }
-- Longest first: a plain scan for "light" would eat every `lightning` status.
local STATUS_ELEMENT_WORDS = {
    "lightning", "radiant", "shadow", "arcane", "poison", "nature", "pierce", "impact",
    "frost", "shock", "water", "slash", "acid", "holy", "burn", "fire", "dark", "ice", "light",
}
local function statusTint(entry)
    local function tintOf(word) return ELEMENT_TINT[word] or STRIKE_TINT[word] end
    local sdef = entry and entry.def
    if sdef then
        for _, key in ipairs(STATUS_ELEMENT_TABLES) do
            local t = sdef[key]
            if type(t) == "table" then
                for _, word in ipairs(STATUS_ELEMENT_WORDS) do
                    if t[word] ~= nil and tintOf(word) then return tintOf(word) end
                end
            end
        end
    end
    local id = entry and entry.id
    if type(id) == "string" then
        for _, word in ipairs(STATUS_ELEMENT_WORDS) do
            if id:find(word, 1, true) and tintOf(word) then return tintOf(word) end
        end
    end
    return nil
end

-- The item's element tint: first tag that names a colour; else the first element named by a status the
-- ability applies; else steel.
local function tintFor(def)
    for _, tag in ipairs(def.tags or {}) do
        if ELEMENT_TINT[tag] then return ELEMENT_TINT[tag] end
    end
    local out = outputFor(def)
    for _, entry in ipairs(out and out.statuses or {}) do
        local tint = statusTint(entry)
        if tint then return tint end
    end
    return STEEL
end

-- The item's damage school -- "magical", "physical", or nil for a schoolless item. Read across the
-- item's own tags AND its ability's, the same widening Combat.auraApplies uses, so an ability that
-- declares `magical` on the ability rather than on the item still reads as magic. Magical wins a tie.
local function schoolFor(def)
    local ab = def.activeAbility
    local function has(tag)
        for _, t in ipairs(def.tags or {}) do if t == tag then return true end end
        if ab and ab.tags then for _, t in ipairs(ab.tags) do if t == tag then return true end end end
        return false
    end
    if has("magical") then return "magical" end
    if has("physical") then return "physical" end
    return nil
end

-- The pool an ability primarily spends (the priciest cost entry; ties keep the authored order), or
-- nil for a free ability. Drives the ability silhouette, so a spell and a martial technique diverge.
local function costPool(def)
    local ab = def.activeAbility
    if not ab then return nil end
    local best
    for _, c in ipairs(Item.costs(ab)) do
        if not best or (c.amount or 0) > (best.amount or 0) then best = c end
    end
    return best and best.stat
end

-- The item's own mapped glyph from tools/icons/map.lua, or nil if unmapped (or the map named no icon
-- yet). Keyed by the sprite path the game loads by -- the same key icon-build renders under.
local function mappedBase(def)
    if not IconMap or type(def.sprite) ~= "string" then return nil end
    local entry = IconMap[def.sprite:gsub("^assets/", "")]
    return entry and entry.icon or nil
end

-- The VERB an ability performs, in the priority the picture should take it: what it PUTS on the board
-- beats what it does to a body, and a blow beats the state it leaves behind. Nil for anything the dry run
-- reports nothing about (a reveal, a stance, a pure repositioning of the caster) -- those fall through to
-- the cost pool, which still separates a spell from a technique.
local function verbFor(def)
    local out = outputFor(def)
    if not out then return nil end
    local buff, debuff = false, false
    for _, entry in ipairs(out.statuses or {}) do
        if entry.def and entry.def.debuff then debuff = true else buff = true end
    end
    if out.summon or out.transform then return "summon" end
    if out.hazard then return "hazard" end
    if out.trap then return "trap" end
    if out.wall or out.prop then return "wall" end
    if (out.heal or 0) > 0 then return "heal" end
    if out.drain or out.restore then return "resource" end
    if (out.damage or 0) > 0 then return out.multi and "area" or "strike" end
    if debuff then return "curse" end
    if buff then return "ward" end
    if out.knockback or out.pull or out.swap then return "move" end
    return nil
end

-- A passive charm's slug: the field it carries, else the hook its first trait fires on. Nil when it
-- carries neither, which lands it on the type base with the rest of the shelf.
local Trait
local function passiveFor(def)
    -- Armour is exempt: a coat should read as a coat whatever it is warded against, and it already has a
    -- shelf of shapes above (the mail, the robe, the cloak) plus its own type base under it.
    if def.type == "armor" then return nil end
    for _, row in ipairs(FIELD_BASE) do
        if def[row[1]] ~= nil then return row[2] end
    end
    local traits = def.traits
    if type(traits) ~= "table" then return nil end
    Trait = Trait or require("models.trait")
    for _, id in ipairs(traits) do
        local tdef = Trait.defs[id]
        if tdef then
            -- HOOK_ORDER, not pairs(HOOK_BASE): a trait may fire on two hooks, and an unordered scan
            -- would give it a different picture on different runs.
            for _, hook in ipairs(HOOK_ORDER) do
                if tdef[hook] ~= nil then return HOOK_BASE[hook] end
            end
        end
    end
    return nil
end

-- The base silhouette slug, resolved through the vocabulary gate (see BASE_VOCABULARY above).
--
--   1. a weapon's FAMILY -- an axe reads as an axe
--   2. its own MAPPED glyph, if that glyph is in the vocabulary
--   3. what an ability DOES (the dry run), or when a charm FIRES (its field or trait hook)
--   4. the pool an ability spends
--   5. the type base
--
-- Step 2 is the whole change: an unapproved guess no longer reaches the renderer, so a shape drawn for
-- one item cannot enter the commission by being guessed at.
local function baseFor(def)
    local family = Item.archetype(def)
    if family and FAMILY_BASE[family] then return FAMILY_BASE[family] end

    local mapped = mappedBase(def)
    if mapped and BASE_VOCABULARY[mapped] then return mapped end

    if def.activeAbility then
        local verb = verbFor(def)
        if verb and VERB_BASE[verb] then return VERB_BASE[verb] end
    else
        local passive = passiveFor(def)
        if passive then return passive end
    end

    if def.type == "ability" then
        local pool = costPool(def)
        if pool and ABILITY_BASE[pool] then return ABILITY_BASE[pool] end
    end
    return TYPE_BASE[def.type] or DEFAULT_BASE
end

-- The recoloured foreground for one base slug, ready to nest in a <g>. The surgery and -- more to the
-- point -- WHICH SET answers the slug both live in tools/icon_source.lua: a commissioned glyph under
-- art/bases/ wins over the vendored game-icons one, so the composer never names a source.
local function foreground(slug, tint)
    local inner, err = Source.foreground(slug, tint)
    if not inner then return nil, err end
    return inner -- drop the root name: which set answered is the audit's business, not the composer's
end

-- Compose the four layers into one 512x512 SVG. Everything here is a function of `def`.
local function compose(def)
    local tint = tintFor(def)
    local classColor = CLASS_COLOR[def.class] or CLASS_DEFAULT
    local tier = tonumber(def.repRank) or 0

    local inner, err = foreground(baseFor(def), tint)
    if not inner then return nil, err end

    local school = schoolFor(def)

    -- No backing plate: the icon is a bare silhouette on a transparent canvas, so it sits inside the
    -- action slot's own frame rather than fighting it with a second one.
    local parts = { '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">' }

    -- Magic reads as lit: a soft radial aura in the element tint blooms behind the silhouette, so a
    -- fire spell glows orange and an ice one blue, while a physical swing is the bare silhouette. This
    -- is the at-a-glance physical/magical tell -- with no plate to carry it, an elementless spell
    -- glows in steel (still a halo, where a physical strike has none).
    if school == "magical" then
        parts[#parts + 1] = string.format(
            '<defs><radialGradient id="glow" cx="50%%" cy="46%%" r="52%%">'
            .. '<stop offset="0%%" stop-color="%s" stop-opacity="0.5"/>'
            .. '<stop offset="100%%" stop-color="%s" stop-opacity="0"/>'
            .. '</radialGradient></defs>'
            .. '<rect x="24" y="24" width="464" height="464" rx="72" fill="url(#glow)"/>',
            tint, tint)
    end

    -- Layer 1 base: the family/type silhouette, tinted, scaled to ~62% and nudged up to clear the pips.
    parts[#parts + 1] = string.format(
        '<g transform="translate(96 82) scale(0.625)" fill="%s">%s</g>', tint, inner)

    -- Tier pips: `repRank` diamonds along the bottom, in the class colour. (The class border and the
    -- type disc that used to sit over the art were removed: the border fought the action slot's own
    -- frame, and the corner disc read as visual noise. Class still speaks through the pips; type
    -- lives in the silhouette and the slot's badges.)
    if tier > 0 then
        local cy, half, gap = 452, 13, 40
        local start = 256 - (tier - 1) * gap / 2
        for i = 0, tier - 1 do
            local cx = start + i * gap
            parts[#parts + 1] = string.format(
                '<polygon points="%d,%d %d,%d %d,%d %d,%d" fill="%s" stroke="#12151a" stroke-width="4"/>',
                cx, cy - half, cx + half, cy, cx, cy + half, cx - half, cy, classColor)
        end
    end

    parts[#parts + 1] = "</svg>"
    return table.concat(parts)
end

local function ensureDir(rel)
    local built
    for part in rel:gmatch("[^/]+") do
        built = built and (built .. "/" .. part) or part
        if not love.filesystem.getInfo(built) then
            os.execute(string.format('mkdir "%s" 2>nul', projectPath(built):gsub("/", "\\")))
        end
    end
end

local function writeFile(rel, text)
    local file, err = io.open(projectPath(rel), "w")
    if not file then return nil, tostring(err) end
    file:write(text)
    file:close()
    return true
end

-- Rasterize a staged SVG to PNG via resvg (the cmd.exe quoting dance is icon-build's).
local function rasterize(svgRel, pngRel)
    local cmd = string.format('"%s" "%s" "%s" --width %d --height %d',
        projectPath(RESVG):gsub("/", "\\"),
        projectPath(svgRel):gsub("/", "\\"),
        projectPath(pngRel):gsub("/", "\\"),
        RENDER_SIZE, RENDER_SIZE)
    local ok = os.execute('""' .. cmd:sub(2) .. '"')
    return ok == 0 or ok == true
end

-- The demo spread: one item per weapon family, then the first of each non-weapon type. Guarantees
-- every base slug and every type badge appears, and every id is real (drawn from the registry, not
-- hand-listed). Deterministic: ids sorted, first match wins.
local function demoSelection(defs)
    local ids = {}
    for id in pairs(defs) do ids[#ids + 1] = id end
    table.sort(ids)

    local picked, seenFamily, seenType = {}, {}, {}
    for _, id in ipairs(ids) do
        local def = defs[id]
        local family = Item.archetype(def)
        if family and not seenFamily[family] then
            seenFamily[family] = true
            picked[#picked + 1] = id
        elseif not family and def.type and not seenType[def.type] then
            seenType[def.type] = true
            picked[#picked + 1] = id
        end
    end
    return picked
end

-- The output path for one item. Preview mode names by blueprint id under OUT_ROOT; `assets` mode
-- writes to the blueprint's OWN sprite path so the game -- which loads by that path, not by id --
-- actually picks the composed icon up. The id and the sprite basename disagree for ~half the
-- catalogue, so naming by id in assets/ would leave those items on their old glyph.
local function outPathFor(id, def, toAssets)
    if not toAssets then return OUT_ROOT .. "/" .. id .. ".png" end
    local sp = def.sprite
    if type(sp) ~= "string" then return nil, "no sprite field" end
    -- Graduation writes ONLY into assets/items/. A sprite pointing elsewhere (e.g. weapon_talons
    -- borrows assets/chars/hawk.png) is left alone rather than composed over shared character art.
    if not sp:match("^assets/items/[^/]+%.png$") then return nil, "sprite outside assets/items: " .. sp end
    return sp
end

function M.run(args)
    if not love.filesystem.getInfo(RESVG) then
        print("resvg not found at " .. RESVG)
        print("run:  powershell -ExecutionPolicy Bypass -File tools\\icons\\fetch.ps1")
        return
    end

    local all, toAssets = false, false
    for _, a in ipairs(args or {}) do
        if a == "all" then all = true end
        if a == "assets" then all, toAssets = true, true end -- graduation implies the full catalogue
    end

    local defs = Registry.load("data/items", "data.items")

    local ids
    if all then
        ids = {}
        for id in pairs(defs) do ids[#ids + 1] = id end
        table.sort(ids)
    else
        ids = demoSelection(defs)
    end

    ensureDir(OUT_ROOT)
    ensureDir(OUT_ROOT .. "/staging")

    local rendered, skipped, failures = 0, {}, {}
    for _, id in ipairs(ids) do
        local def = defs[id]
        local pngRel, skipWhy = outPathFor(id, def, toAssets)
        if not pngRel then
            skipped[#skipped + 1] = id .. " -- " .. skipWhy
        else
            local svg, err = compose(def)
            if not svg then
                failures[#failures + 1] = id .. " -- " .. tostring(err)
            else
                local stageRel = OUT_ROOT .. "/staging/" .. id .. ".svg"
                local wrote, werr = writeFile(stageRel, svg)
                if not wrote then
                    failures[#failures + 1] = id .. " -- cannot stage: " .. tostring(werr)
                elseif rasterize(stageRel, pngRel) then
                    rendered = rendered + 1
                else
                    failures[#failures + 1] = id .. " -- resvg failed"
                end
            end
        end
    end

    local dest = toAssets and "assets/items/ (each item's own sprite path)" or (OUT_ROOT .. "/")
    print("")
    print(string.format("  composed %d icon(s) into %s", rendered, dest))
    print(string.format("  skipped  %d", #skipped))
    print(string.format("  failed   %d", #failures))
    print("")
    for _, s in ipairs(skipped) do print("  skip: " .. s) end
    for _, f in ipairs(failures) do print("  fail: " .. f) end
    if not all then
        print("")
        print("  (demo spread -- `. icon-compose all` for the full preview, `. icon-compose assets` to graduate)")
    end
end

-- The base-slug resolution is exposed so the source audit (tools/art_source.lua) can ask "which
-- silhouette does this item actually draw?" through the SAME function the renderer uses. Asking any
-- other way is how a report starts disagreeing with the pipeline it reports on.
M.baseFor = baseFor
M.tintFor = tintFor
M.verbFor = verbFor
M.FAMILY_BASE = FAMILY_BASE
M.TYPE_BASE = TYPE_BASE
M.ABILITY_BASE = ABILITY_BASE
M.VERB_BASE = VERB_BASE
M.HOOK_BASE = HOOK_BASE
M.FIELD_BASE = FIELD_BASE
M.DEFAULT_BASE = DEFAULT_BASE

-- The vocabulary and its exception list are exported for the spec that guards them
-- (tests/art_pipeline_spec.lua): every slug the composer resolves is a member, the list carries no idle
-- entry, and the bespoke list stays under its cap.
M.BASE_VOCABULARY = BASE_VOCABULARY
M.BESPOKE = BESPOKE
M.BESPOKE_CAP = BESPOKE_CAP

return M
