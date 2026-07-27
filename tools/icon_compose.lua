-- Icon COMPOSER (prototype of the permanent system in docs/art-assets.md,
-- "The permanent icon system — compose, don't commission").
--
--     & "E:\LOVE\lovec.exe" . icon-compose        # render the demo spread (one per family + type)
--     & "E:\LOVE\lovec.exe" . icon-compose all     # ... every item blueprint (preview only)
--     & "E:\LOVE\lovec.exe" . icon-compose assets  # graduate: write every item's OWN sprite path in assets/
--
-- Where icon-build draws ONE game-icons glyph per asset, this draws the icon as a pure function of
-- the tags the blueprint already declares -- exactly the way shaders/field.lua draws a hazard from
-- its fire/ice tag. Three data channels, none of them a commission:
--
--   1. BASE    a weapon REUSES its family silhouette (Item.archetype -> FAMILY_BASE) -- 15 shapes
--              cover every weapon and shield. Every OTHER item draws its own UNIQUE glyph from the
--              per-item map (tools/icons/map.lua), falling back to the ability cost-pool shape or the
--              generic TYPE_BASE only when the map names nothing.
--   2. TINT    the base is recoloured by the item's element/strike tag (ELEMENT_TINT).
--   3. PIPS    `repRank` tier diamonds along the bottom, in the item's CLASS colour (the vendor shelf).
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
local ICON_ROOT = "vendor/game-icons"
local OUT_ROOT = "vendor/compose-preview"
local RENDER_SIZE = 256 -- larger than icon-build's 128: a composed icon has a frame and badge to keep crisp
local BG_PATH = '<path d="M0 0h512v512H0z"/>'

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
local TYPE_BASE = {
    ability = "lorc/magic-swirl",
    armor = "lorc/breastplate",
    utility = "lorc/round-bottom-flask",
    material = "lorc/gems",
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
}
local STEEL = "#dce1e6"

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

-- The item's element tint: first tag that names a colour, else steel.
local function tintFor(def)
    for _, tag in ipairs(def.tags or {}) do
        if ELEMENT_TINT[tag] then return ELEMENT_TINT[tag] end
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

-- The base silhouette slug. Weapons (and shields, a weapon family) REUSE the shared family shape --
-- an axe should read as an axe. Every other item takes its own unique mapped glyph; only when the map
-- has nothing does it fall back to an ability's cost-pool shape, then the generic type base.
local function baseFor(def)
    local family = Item.archetype(def)
    if family and FAMILY_BASE[family] then return FAMILY_BASE[family] end

    local mapped = mappedBase(def)
    if mapped then return mapped end

    if def.type == "ability" then
        local pool = costPool(def)
        if pool and ABILITY_BASE[pool] then return ABILITY_BASE[pool] end
    end
    return TYPE_BASE[def.type] or DEFAULT_BASE
end

-- Pull the recoloured foreground out of a vendored game-icons SVG: drop the outer <svg>, drop the
-- full-canvas background rect, recolour the #fff foreground to `tint`. Returns the inner markup (a
-- run of <path>s) ready to drop into a <g>, or nil + why. Same surgery as icon-build's transform,
-- minus the re-wrap -- the caller nests it instead of shipping it whole.
local function foreground(slug, tint)
    local raw = love.filesystem.read(ICON_ROOT .. "/" .. slug .. ".svg")
    if not raw then return nil, "no such icon: " .. slug end
    local inner = raw:match("<svg[^>]*>(.*)</svg>")
    if not inner then return nil, "unexpected SVG layout: " .. slug end
    inner = inner:gsub(BG_PATH:gsub("%p", "%%%0"), "", 1)
    -- Recolour explicit #fff fills; the enclosing <g fill> below catches any path that inherited.
    inner = inner:gsub('fill="#fff"', string.format('fill="%s"', tint))
    return inner
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

return M
